"""Simple DAG scheduled every day at midnight (UTC)."""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator


default_args = {
    "owner": "airflow",
    "start_date": datetime(2026, 1, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}


def print_hello() -> str:
    message = "Hello World from Airflow on OKDP"
    print(message)
    return message


with DAG(
    dag_id="hello_world_midnight",
    default_args=default_args,
    description="Hello World DAG that runs daily at 00:00 UTC",
    schedule="0 0 * * *",
    catchup=False,
    tags=["example", "python", "okdp"],
) as dag:
    hello_task = PythonOperator(
        task_id="hello_world_task",
        python_callable=print_hello,
    )
