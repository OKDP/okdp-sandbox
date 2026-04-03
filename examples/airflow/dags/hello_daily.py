"""Minimal daily smoke-test DAG."""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator


default_args = {
    "owner": "airflow",
    "start_date": datetime(2026, 1, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}


def log_hello() -> str:
    message = "Hello from Airflow daily smoke-test"
    print(message)
    return message


with DAG(
    dag_id="hello_daily",
    default_args=default_args,
    description="Simple DAG that validates scheduler/task execution every day",
    schedule="0 0 * * *",
    catchup=False,
    tags=["example", "smoke", "daily"],
) as dag:
    hello_task = PythonOperator(
        task_id="log_hello",
        python_callable=log_hello,
    )

