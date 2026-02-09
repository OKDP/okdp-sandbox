"""
Airflow DAG to run Spark Pi example using SparkApplication CRD.
"""

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'spark_pi_example',
    default_args=default_args,
    description='Run Spark Pi calculation using Spark Operator',
    schedule_interval='@daily',
    catchup=False,
    tags=['spark', 'example', 'okdp'],
) as dag:
    
    spark_task = KubernetesPodOperator(
        task_id='spark_pi_task',
        namespace='airflow',
        image='bitnami/kubectl:latest',
        cmds=['kubectl'],
        arguments=[
            'apply', '-f', '-'
        ],
        name='spark-pi-submitter',
        is_delete_operator_pod=True,
        in_cluster=True,
        get_logs=True,
    )
