"""
NYC Taxi Pipeline - Airflow + Spark Operator
Utilise l'API Kubernetes Python pour soumettre un SparkApplication.
"""
import os
import re
import time
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

NAMESPACE = os.getenv("AIRFLOW_NAMESPACE", "default")
SPARK_APP_GROUP = "sparkoperator.k8s.io"
SPARK_APP_VERSION = "v1beta2"
SPARK_APP_PLURAL = "sparkapplications"
SPARK_IMAGE = "quay.io/okdp/spark-py:spark-3.5.6-python-3.11-scala-2.12-java-17"
SPARK_SERVICE_ACCOUNT = "spark"
S3_CREDENTIALS_SECRET = "creds-examples-s3"
S3_ACCESS_KEY_FIELD = "S3_ACCESS_KEY"
S3_SECRET_KEY_FIELD = "S3_SECRET_KEY"
CONFIGMAP_NAME = "nyc-taxi-etl-code"
SCRIPT_MOUNT_DIR = "/opt/spark/app"
SCRIPT_FILE_NAME = "nyc_taxi_etl.py"

# Input/Output S3
S3_INPUT = "s3a://okdp/examples/data/raw/tripdata/yellow/"
S3_OUTPUT_BASE = "s3a://okdp/examples/data/processed/nyc_taxi/yellow"

default_args = {
    "owner": "data-team",
    "depends_on_past": False,
    "start_date": datetime(2024, 1, 1),
    "retries": 0,
    "retry_delay": timedelta(minutes=2),
}


def _safe_name(prefix, suffix, max_len=63):
    raw = f"{prefix}-{suffix}"
    normalized = re.sub(r"[^a-z0-9-]", "-", raw.lower()).strip("-")
    return normalized[:max_len].rstrip("-")


def _discover_s3_endpoint(core_api):
    """Discover SeaweedFS S3 endpoint in-cluster."""
    try:
        services = core_api.list_namespaced_service(namespace=NAMESPACE).items
        for svc in services:
            name = (svc.metadata.name or "").strip()
            if re.match(r"^seaweedfs-[a-z0-9-]+-s3$", name):
                return f"http://{name}.{NAMESPACE}.svc.cluster.local:8333"
    except ApiException:
        pass
    return f"https://seaweedfs-seaweedfs-{NAMESPACE}.okdp.sandbox"


def _delete_if_exists(custom_api, app_name):
    try:
        custom_api.delete_namespaced_custom_object(
            group=SPARK_APP_GROUP,
            version=SPARK_APP_VERSION,
            namespace=NAMESPACE,
            plural=SPARK_APP_PLURAL,
            name=app_name,
        )
        time.sleep(2)
    except ApiException as exc:
        if exc.status != 404:
            raise


def submit_and_wait_nyc_taxi_etl(run_suffix, timeout_seconds=1200):
    """Submit SparkApplication and wait for completion."""
    config.load_incluster_config()
    core_api = client.CoreV1Api()
    custom_api = client.CustomObjectsApi()

    app_name = _safe_name("nyc-taxi-etl", run_suffix)
    s3_endpoint = _discover_s3_endpoint(core_api)
    ssl_enabled = str(s3_endpoint.lower().startswith("https://")).lower()
    output_uri = f"{S3_OUTPUT_BASE}/run_id={run_suffix}"

    _delete_if_exists(custom_api, app_name)

    body = {
        "apiVersion": f"{SPARK_APP_GROUP}/{SPARK_APP_VERSION}",
        "kind": "SparkApplication",
        "metadata": {"name": app_name, "namespace": NAMESPACE},
        "spec": {
            "type": "Python",
            "mode": "cluster",
            "image": SPARK_IMAGE,
            "imagePullPolicy": "IfNotPresent",
            "mainApplicationFile": f"local://{SCRIPT_MOUNT_DIR}/{SCRIPT_FILE_NAME}",
            "arguments": [
                "--input", S3_INPUT,
                "--output", output_uri,
                "--date", run_suffix,
            ],
            "sparkVersion": "3.5.6",
            "restartPolicy": {"type": "Never"},
            "timeToLiveSeconds": 3600,
            "sparkConf": {
                "spark.hadoop.fs.s3a.endpoint": s3_endpoint,
                "spark.hadoop.fs.s3a.path.style.access": "true",
                "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
                "spark.hadoop.fs.s3a.connection.ssl.enabled": ssl_enabled,
                # Fix for SeaweedFS: write to local then upload via script
                "spark.hadoop.fs.s3a.fast.upload": "true",
                "spark.hadoop.fs.s3a.fast.upload.buffer": "bytebuffer",
            },
            "volumes": [
                {"name": "etl-script", "configMap": {"name": CONFIGMAP_NAME}},
            ],
            "driver": {
                "cores": 1,
                "memory": "1g",
                "serviceAccount": SPARK_SERVICE_ACCOUNT,
                "labels": {"workload": "nyc-taxi-etl"},
                "volumeMounts": [{"name": "etl-script", "mountPath": SCRIPT_MOUNT_DIR}],
                "envSecretKeyRefs": {
                    "AWS_ACCESS_KEY_ID": {"name": S3_CREDENTIALS_SECRET, "key": S3_ACCESS_KEY_FIELD},
                    "AWS_SECRET_ACCESS_KEY": {"name": S3_CREDENTIALS_SECRET, "key": S3_SECRET_KEY_FIELD},
                },
                "env": [{"name": "S3_ENDPOINT", "value": s3_endpoint}],
            },
            "executor": {
                "instances": 1,
                "cores": 1,
                "memory": "1g",
                "labels": {"workload": "nyc-taxi-etl"},
                "envSecretKeyRefs": {
                    "AWS_ACCESS_KEY_ID": {"name": S3_CREDENTIALS_SECRET, "key": S3_ACCESS_KEY_FIELD},
                    "AWS_SECRET_ACCESS_KEY": {"name": S3_CREDENTIALS_SECRET, "key": S3_SECRET_KEY_FIELD},
                },
                "env": [{"name": "S3_ENDPOINT", "value": s3_endpoint}],
            },
        },
    }

    custom_api.create_namespaced_custom_object(
        group=SPARK_APP_GROUP,
        version=SPARK_APP_VERSION,
        namespace=NAMESPACE,
        plural=SPARK_APP_PLURAL,
        body=body,
    )

    deadline = time.time() + timeout_seconds
    last_state = "SUBMITTED"
    while time.time() < deadline:
        app = custom_api.get_namespaced_custom_object(
            group=SPARK_APP_GROUP,
            version=SPARK_APP_VERSION,
            namespace=NAMESPACE,
            plural=SPARK_APP_PLURAL,
            name=app_name,
        )
        last_state = (
            app.get("status", {})
            .get("applicationState", {})
            .get("state", "SUBMITTED")
        )
        if last_state == "COMPLETED":
            return f"Spark ETL terminé: {app_name}"
        if last_state in {"FAILED", "SUBMISSION_FAILED", "UNKNOWN"}:
            raise RuntimeError(f"Spark ETL échoué: {app_name} state={last_state}")
        time.sleep(10)

    raise TimeoutError(f"Spark ETL timeout après {timeout_seconds}s: {app_name} state={last_state}")


with DAG(
    dag_id="nyc_taxi_spark_pipeline",
    default_args=default_args,
    description="NYC Taxi Spark ETL pipeline",
    schedule=None,
    catchup=False,
    tags=["nyc-taxi", "spark", "etl"],
) as dag:
    run_etl = PythonOperator(
        task_id="submit_and_wait_nyc_taxi_etl",
        python_callable=submit_and_wait_nyc_taxi_etl,
        op_kwargs={"run_suffix": "{{ ts_nodash | lower }}"},
    )
