"""Submit and monitor a Spark Pi SparkApplication from Airflow."""

from __future__ import annotations

import time
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException


SPARK_IMAGE = "quay.io/okdp/spark-py:spark-3.5.6-python-3.11-scala-2.12-java-17"
SPARK_MAIN_APP = "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.6.jar"
SPARK_MAIN_CLASS = "org.apache.spark.examples.SparkPi"
NAMESPACE = "default"


default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),
    "retries": 0,
    "retry_delay": timedelta(minutes=2),
}


def submit_and_wait_spark_pi(app_name: str, timeout_seconds: int = 900) -> str:
    config.load_incluster_config()
    api = client.CustomObjectsApi()

    body = {
        "apiVersion": "sparkoperator.k8s.io/v1beta2",
        "kind": "SparkApplication",
        "metadata": {"name": app_name, "namespace": NAMESPACE},
        "spec": {
            "type": "Scala",
            "mode": "cluster",
            "image": SPARK_IMAGE,
            "imagePullPolicy": "IfNotPresent",
            "mainClass": SPARK_MAIN_CLASS,
            "mainApplicationFile": SPARK_MAIN_APP,
            "sparkVersion": "3.5.6",
            "restartPolicy": {"type": "Never"},
            "timeToLiveSeconds": 600,
            "driver": {
                "cores": 1,
                "memory": "512m",
                "serviceAccount": "spark",
                "labels": {"version": "3.5.6"},
            },
            "executor": {
                "cores": 1,
                "instances": 1,
                "memory": "512m",
                "labels": {"version": "3.5.6"},
            },
        },
    }

    try:
        api.delete_namespaced_custom_object(
            group="sparkoperator.k8s.io",
            version="v1beta2",
            namespace=NAMESPACE,
            plural="sparkapplications",
            name=app_name,
        )
        time.sleep(3)
    except ApiException as exc:
        if exc.status != 404:
            raise

    api.create_namespaced_custom_object(
        group="sparkoperator.k8s.io",
        version="v1beta2",
        namespace=NAMESPACE,
        plural="sparkapplications",
        body=body,
    )

    deadline = time.time() + timeout_seconds
    last_state = "PENDING"
    while time.time() < deadline:
        app = api.get_namespaced_custom_object(
            group="sparkoperator.k8s.io",
            version="v1beta2",
            namespace=NAMESPACE,
            plural="sparkapplications",
            name=app_name,
        )
        last_state = (
            app.get("status", {})
            .get("applicationState", {})
            .get("state", "PENDING")
        )
        if last_state == "COMPLETED":
            return f"SparkApplication {app_name} completed successfully"
        if last_state in {"FAILED", "SUBMISSION_FAILED", "UNKNOWN"}:
            raise RuntimeError(f"SparkApplication {app_name} failed with state={last_state}")
        time.sleep(10)

    raise TimeoutError(
        f"SparkApplication {app_name} did not complete within {timeout_seconds}s (last_state={last_state})"
    )


with DAG(
    dag_id="spark_pi_midnight",
    default_args=default_args,
    description="Run Spark Pi via SparkApplication once a day at midnight UTC",
    schedule="0 0 * * *",
    catchup=False,
    tags=["spark", "example", "okdp"],
) as dag:
    run_spark_pi = PythonOperator(
        task_id="submit_and_wait_spark_pi",
        python_callable=submit_and_wait_spark_pi,
        op_kwargs={"app_name": "spark-pi-{{ ts_nodash | lower }}"},
    )
