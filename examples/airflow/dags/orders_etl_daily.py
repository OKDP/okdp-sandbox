"""Submit and monitor a daily Spark ETL job through Spark Operator."""

from __future__ import annotations

import base64
import os
import re
import time
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.python import PythonOperator
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException


NAMESPACE = os.getenv("AIRFLOW_NAMESPACE", "default")
SPARK_APP_GROUP = "sparkoperator.k8s.io"
SPARK_APP_VERSION = "v1beta2"
SPARK_APP_PLURAL = "sparkapplications"
SPARK_IMAGE = "quay.io/okdp/spark-py:spark-3.5.6-python-3.11-scala-2.12-java-17"
SCRIPT_FILE_NAME = "orders_etl_job.py"
SCRIPT_FILE_PATH = Path(__file__).parent / "spark_jobs" / SCRIPT_FILE_NAME
SCRIPT_MOUNT_DIR = "/opt/spark/app"
SCRIPT_MOUNT_PATH = f"{SCRIPT_MOUNT_DIR}/{SCRIPT_FILE_NAME}"
SPARK_SERVICE_ACCOUNT = "spark"
S3_CREDENTIALS_SECRET = "creds-airflow-s3"
S3_ACCESS_KEY_FIELD = "accessKey"
S3_SECRET_KEY_FIELD = "secretKey"
DEFAULT_INGRESS_SUFFIX = "okdp.sandbox"
DEFAULT_S3_BUCKET = "airflow-logs"
DEFAULT_S3_INPUT_PREFIX = "orders/raw"
DEFAULT_S3_OUTPUT_PREFIX = "orders/curated"
S3_ENDPOINT_ENV_VAR = "AIRFLOW_ETL_S3_ENDPOINT"
S3_BUCKET_ENV_VAR = "AIRFLOW_ETL_S3_BUCKET"
S3_INPUT_PREFIX_ENV_VAR = "AIRFLOW_ETL_S3_INPUT_PREFIX"
S3_OUTPUT_PREFIX_ENV_VAR = "AIRFLOW_ETL_S3_OUTPUT_PREFIX"
INGRESS_SUFFIX_ENV_VAR = "AIRFLOW_INGRESS_SUFFIX"
S3_VERIFY_SSL_ENV_VAR = "AIRFLOW_ETL_S3_VERIFY_SSL"
S3_REGION_ENV_VAR = "AIRFLOW_ETL_S3_REGION"


default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),
    "retries": 0,
    "retry_delay": timedelta(minutes=2),
}


def _safe_k8s_name(prefix: str, suffix: str, max_len: int = 63) -> str:
    raw = f"{prefix}-{suffix}"
    normalized = re.sub(r"[^a-z0-9-]", "-", raw.lower()).strip("-")
    if len(normalized) <= max_len:
        return normalized
    return normalized[:max_len].rstrip("-")


def _load_spark_script() -> str:
    if not SCRIPT_FILE_PATH.is_file():
        raise FileNotFoundError(f"Spark ETL script not found: {SCRIPT_FILE_PATH}")
    return SCRIPT_FILE_PATH.read_text(encoding="utf-8")


def _clean_prefix(value: str, default_value: str) -> str:
    normalized = (value or default_value).strip().strip("/")
    return normalized or default_value


def _discover_seaweedfs_s3_endpoint(core_api: client.CoreV1Api) -> str:
    env_endpoint = os.getenv(S3_ENDPOINT_ENV_VAR, "").strip().rstrip("/")
    if env_endpoint:
        return env_endpoint

    # Prefer in-cluster SeaweedFS S3 service when available.
    try:
        services = core_api.list_namespaced_service(namespace=NAMESPACE).items
        candidates = []
        for svc in services:
            service_name = (svc.metadata.name or "").strip()
            if re.match(r"^seaweedfs-[a-z0-9-]+-s3$", service_name):
                candidates.append(service_name)
        if candidates:
            chosen = sorted(candidates)[0]
            return f"http://{chosen}.{NAMESPACE}.svc.cluster.local:8333"
    except ApiException:
        pass

    ingress_suffix = os.getenv(INGRESS_SUFFIX_ENV_VAR, DEFAULT_INGRESS_SUFFIX).strip()
    if not ingress_suffix:
        ingress_suffix = DEFAULT_INGRESS_SUFFIX
    return f"https://seaweedfs-seaweedfs-{NAMESPACE}.{ingress_suffix}"


def _resolve_s3_locations(core_api: client.CoreV1Api) -> tuple[str, str, str]:
    bucket = (
        os.getenv(S3_BUCKET_ENV_VAR, "").strip()
        or os.getenv("AIRFLOW_DAGS_S3_BUCKET", "").strip()
        or DEFAULT_S3_BUCKET
    )
    input_prefix = _clean_prefix(os.getenv(S3_INPUT_PREFIX_ENV_VAR, ""), DEFAULT_S3_INPUT_PREFIX)
    output_prefix = _clean_prefix(os.getenv(S3_OUTPUT_PREFIX_ENV_VAR, ""), DEFAULT_S3_OUTPUT_PREFIX)

    s3_endpoint = _discover_seaweedfs_s3_endpoint(core_api=core_api)
    s3_input_uri = f"s3a://{bucket}/{input_prefix}"
    s3_output_uri_base = f"s3a://{bucket}/{output_prefix}"
    return bucket, s3_endpoint, s3_input_uri, s3_output_uri_base


def _bool_env(env_name: str, default_value: bool) -> bool:
    raw_value = os.getenv(env_name)
    if raw_value is None:
        return default_value
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def _ensure_s3_bucket_exists(core_api: client.CoreV1Api, s3_endpoint: str, bucket: str) -> None:
    try:
        secret = core_api.read_namespaced_secret(name=S3_CREDENTIALS_SECRET, namespace=NAMESPACE)
    except ApiException as exc:
        raise RuntimeError(
            f"Unable to read S3 credentials secret {S3_CREDENTIALS_SECRET} in namespace {NAMESPACE}"
        ) from exc

    secret_data = secret.data or {}
    access_key_b64 = secret_data.get(S3_ACCESS_KEY_FIELD, "")
    secret_key_b64 = secret_data.get(S3_SECRET_KEY_FIELD, "")
    if not access_key_b64 or not secret_key_b64:
        raise RuntimeError(
            f"S3 credentials secret {S3_CREDENTIALS_SECRET} is missing keys "
            f"{S3_ACCESS_KEY_FIELD}/{S3_SECRET_KEY_FIELD}"
        )

    access_key = base64.b64decode(access_key_b64).decode("utf-8")
    secret_key = base64.b64decode(secret_key_b64).decode("utf-8")

    verify_ssl = _bool_env(
        S3_VERIFY_SSL_ENV_VAR,
        default_value=s3_endpoint.lower().startswith("https://"),
    )
    s3_region = os.getenv(S3_REGION_ENV_VAR, "us-east-1")

    import boto3
    from botocore.exceptions import ClientError

    s3_client = boto3.client(
        "s3",
        endpoint_url=s3_endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name=s3_region,
        verify=verify_ssl,
    )

    try:
        s3_client.head_bucket(Bucket=bucket)
        return
    except ClientError as exc:
        error_code = str(exc.response.get("Error", {}).get("Code", ""))
        if error_code not in {"404", "NoSuchBucket", "NotFound"}:
            raise RuntimeError(
                f"Unable to access bucket {bucket} on endpoint {s3_endpoint}: {exc}"
            ) from exc

    s3_client.create_bucket(Bucket=bucket)


def _upsert_config_map(core_api: client.CoreV1Api, name: str, script_content: str) -> None:
    body = client.V1ConfigMap(
        metadata=client.V1ObjectMeta(
            name=name,
            namespace=NAMESPACE,
            labels={"app": "orders-etl", "managed-by": "airflow"},
        ),
        data={SCRIPT_FILE_NAME: script_content},
    )
    try:
        core_api.patch_namespaced_config_map(name=name, namespace=NAMESPACE, body=body)
    except ApiException as exc:
        if exc.status != 404:
            raise
        core_api.create_namespaced_config_map(namespace=NAMESPACE, body=body)


def _delete_if_exists(custom_api: client.CustomObjectsApi, app_name: str) -> None:
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


def submit_and_wait_orders_etl(run_suffix: str, timeout_seconds: int = 1200) -> str:
    config.load_incluster_config()
    core_api = client.CoreV1Api()
    custom_api = client.CustomObjectsApi()

    spark_app_name = _safe_k8s_name("orders-etl", run_suffix)
    script_cm_name = _safe_k8s_name("orders-etl-script", run_suffix)
    bucket, s3_endpoint, s3_input_uri, s3_output_uri_base = _resolve_s3_locations(core_api=core_api)
    output_uri = f"{s3_output_uri_base}/run_id={run_suffix}"
    ssl_enabled = str(s3_endpoint.lower().startswith("https://")).lower()

    _ensure_s3_bucket_exists(core_api=core_api, s3_endpoint=s3_endpoint, bucket=bucket)
    script_content = _load_spark_script()
    _upsert_config_map(core_api=core_api, name=script_cm_name, script_content=script_content)
    _delete_if_exists(custom_api=custom_api, app_name=spark_app_name)

    body = {
        "apiVersion": f"{SPARK_APP_GROUP}/{SPARK_APP_VERSION}",
        "kind": "SparkApplication",
        "metadata": {"name": spark_app_name, "namespace": NAMESPACE},
        "spec": {
            "type": "Python",
            "mode": "cluster",
            "image": SPARK_IMAGE,
            "imagePullPolicy": "IfNotPresent",
            "mainApplicationFile": f"local://{SCRIPT_MOUNT_PATH}",
            "arguments": [
                "--input-uri",
                s3_input_uri,
                "--output-uri",
                output_uri,
                "--run-id",
                run_suffix,
            ],
            "sparkVersion": "3.5.6",
            "restartPolicy": {"type": "Never"},
            "timeToLiveSeconds": 600,
            "sparkConf": {
                "spark.hadoop.fs.s3a.endpoint": s3_endpoint,
                "spark.hadoop.fs.s3a.path.style.access": "true",
                "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
                "spark.hadoop.fs.s3a.connection.ssl.enabled": ssl_enabled,
            },
            "volumes": [
                {
                    "name": "etl-script",
                    "configMap": {"name": script_cm_name},
                }
            ],
            "driver": {
                "cores": 1,
                "memory": "1g",
                "serviceAccount": SPARK_SERVICE_ACCOUNT,
                "labels": {"workload": "orders-etl", "version": "3.5.6"},
                "volumeMounts": [{"name": "etl-script", "mountPath": SCRIPT_MOUNT_DIR}],
                "envSecretKeyRefs": {
                    "S3_ACCESS_KEY": {"name": S3_CREDENTIALS_SECRET, "key": S3_ACCESS_KEY_FIELD},
                    "S3_SECRET_KEY": {"name": S3_CREDENTIALS_SECRET, "key": S3_SECRET_KEY_FIELD},
                },
                "env": [{"name": "S3_ENDPOINT", "value": s3_endpoint}],
            },
            "executor": {
                "instances": 1,
                "cores": 1,
                "memory": "1g",
                "labels": {"workload": "orders-etl", "version": "3.5.6"},
                "envSecretKeyRefs": {
                    "S3_ACCESS_KEY": {"name": S3_CREDENTIALS_SECRET, "key": S3_ACCESS_KEY_FIELD},
                    "S3_SECRET_KEY": {"name": S3_CREDENTIALS_SECRET, "key": S3_SECRET_KEY_FIELD},
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
            name=spark_app_name,
        )
        last_state = (
            app.get("status", {})
            .get("applicationState", {})
            .get("state", "SUBMITTED")
        )

        if last_state == "COMPLETED":
            return f"Spark ETL finished successfully: {spark_app_name}"
        if last_state in {"FAILED", "SUBMISSION_FAILED", "UNKNOWN"}:
            raise RuntimeError(f"Spark ETL failed for {spark_app_name} with state={last_state}")
        time.sleep(10)

    raise TimeoutError(
        f"Spark ETL timeout after {timeout_seconds}s for {spark_app_name} (last_state={last_state})"
    )


with DAG(
    dag_id="orders_etl_daily",
    default_args=default_args,
    description="Daily Spark ETL workflow orchestrated by Airflow and Spark Operator",
    schedule="0 0 * * *",
    catchup=False,
    tags=["etl", "spark", "daily", "orders"],
) as dag:
    run_orders_etl = PythonOperator(
        task_id="submit_and_wait_orders_etl",
        python_callable=submit_and_wait_orders_etl,
        op_kwargs={"run_suffix": "{{ ts_nodash | lower }}"},
    )
