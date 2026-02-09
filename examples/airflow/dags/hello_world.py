"""
Simple Hello World Airflow DAG to verify installation.
"""

from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'airflow',
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

def print_hello():
    print("Hello from Airflow on OKDP!")
    return "Hello World"

with DAG(
    'hello_world',
    default_args=default_args,
    description='Simple Hello World DAG',
    schedule_interval='@daily',
    catchup=False,
    tags=['example', 'okdp'],
) as dag:
    
    hello_task = PythonOperator(
        task_id='hello',
        python_callable=print_hello,
    )
