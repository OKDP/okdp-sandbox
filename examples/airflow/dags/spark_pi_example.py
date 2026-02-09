"""
Airflow DAG to run Spark Pi example using SparkApplication CRD.

This DAG demonstrates integration between Airflow and Spark Operator:
- Uses SparkKubernetesOperator to submit SparkApplication
- Monitors execution status
- Retrieves logs and results
"""

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
from kubernetes import client, config
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Default arguments
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# SparkApplication manifest
spark_pi_application = """
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi-airflow-{{ ts_nodash | lower }}
  namespace: airflow
spec:
  type: Scala
  mode: cluster
  image: "apache/spark:3.5.0"
  imagePullPolicy: IfNotPresent
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar"
  sparkVersion: "3.5.0"
  restartPolicy:
    type: Never
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "512m"
    labels:
      version: "3.5.0"
      app: "spark-pi"
      submitted-by: "airflow"
    serviceAccount: spark
  executor:
    cores: 1
    instances: 2
    memory: "512m"
    labels:
      version: "3.5.0"
      app: "spark-pi"
      submitted-by: "airflow"
"""


def check_spark_result(**context):
    """Check Spark job result from XCom."""
    task_instance = context['task_instance']
    spark_status = task_instance.xcom_pull(task_ids='spark_pi_task')
    logger.info(f"Spark job status: {spark_status}")
    
    if spark_status and 'applicationState' in spark_status:
        state = spark_status['applicationState']['state']
        logger.info(f"Application state: {state}")
        
        if state == 'COMPLETED':
            logger.info("✅ Spark Pi calculation completed successfully!")
            return True
        elif state == 'FAILED':
            logger.error("❌ Spark job failed!")
            raise Exception(f"Spark job failed with state: {state}")
        else:
            logger.warning(f"⚠️ Spark job in unexpected state: {state}")
            return False
    
    logger.warning("No status information available")
    return False


# Define DAG
with DAG(
    'spark_pi_example',
    default_args=default_args,
    description='Run Spark Pi calculation using Spark Operator',
    schedule_interval='@daily',
    catchup=False,
    tags=['spark', 'example', 'okdp'],
) as dag:
    
    # Task 1: Submit Spark job
    spark_task = SparkKubernetesOperator(
        task_id='spark_pi_task',
        namespace='airflow',
        application_file=spark_pi_application,
        do_xcom_push=True,
        kubernetes_conn_id='kubernetes_default',
    )
    
    # Task 2: Check result
    check_result = PythonOperator(
        task_id='check_result',
        python_callable=check_spark_result,
        provide_context=True,
    )
    
    # Task dependencies
    spark_task >> check_result
