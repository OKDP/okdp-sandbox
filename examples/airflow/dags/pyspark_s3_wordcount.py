"""
Airflow DAG to run PySpark S3 word count example.

This DAG demonstrates:
- PySpark job reading from and writing to S3
- Integration with MinIO/S3 storage
- SparkApplication with S3 configuration
"""

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# PySpark S3 SparkApplication manifest
pyspark_s3_application = """
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: pyspark-s3-wordcount-{{ ts_nodash | lower }}
  namespace: airflow
spec:
  type: Python
  mode: cluster
  image: "quay.io/okdp/pyspark-s3a:3.5.0"
  imagePullPolicy: IfNotPresent
  mainApplicationFile: "local:///opt/spark/examples/pyspark_s3_wordcount.py"
  sparkVersion: "3.5.0"
  restartPolicy:
    type: Never
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "1g"
    labels:
      version: "3.5.0"
      app: "pyspark-s3"
      submitted-by: "airflow"
    serviceAccount: spark
    env:
      - name: AWS_ACCESS_KEY_ID
        value: "minioadmin"
      - name: AWS_SECRET_ACCESS_KEY
        value: "minioadmin"
      - name: AWS_ENDPOINT
        value: "http://minio.minio.svc.cluster.local:9000"
  executor:
    cores: 1
    instances: 2
    memory: "1g"
    labels:
      version: "3.5.0"
      app: "pyspark-s3"
      submitted-by: "airflow"
    env:
      - name: AWS_ACCESS_KEY_ID
        value: "minioadmin"
      - name: AWS_SECRET_ACCESS_KEY
        value: "minioadmin"
      - name: AWS_ENDPOINT
        value: "http://minio.minio.svc.cluster.local:9000"
  sparkConf:
    "spark.hadoop.fs.s3a.endpoint": "http://minio.minio.svc.cluster.local:9000"
    "spark.hadoop.fs.s3a.access.key": "minioadmin"
    "spark.hadoop.fs.s3a.secret.key": "minioadmin"
    "spark.hadoop.fs.s3a.path.style.access": "true"
    "spark.hadoop.fs.s3a.connection.ssl.enabled": "false"
    "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem"
"""


def check_pyspark_result(**context):
    """Check PySpark S3 job result."""
    task_instance = context['task_instance']
    spark_status = task_instance.xcom_pull(task_ids='pyspark_s3_task')
    logger.info(f"PySpark S3 job status: {spark_status}")
    
    if spark_status and 'applicationState' in spark_status:
        state = spark_status['applicationState']['state']
        logger.info(f"Application state: {state}")
        
        if state == 'COMPLETED':
            logger.info("✅ PySpark S3 word count completed successfully!")
            return True
        elif state == 'FAILED':
            logger.error("❌ PySpark S3 job failed!")
            raise Exception(f"PySpark job failed with state: {state}")
        else:
            logger.warning(f"⚠️ PySpark job in unexpected state: {state}")
            return False
    
    return False


# Define DAG
with DAG(
    'pyspark_s3_wordcount',
    default_args=default_args,
    description='Run PySpark S3 word count using Spark Operator',
    schedule_interval='@weekly',
    catchup=False,
    tags=['spark', 'pyspark', 's3', 'okdp'],
) as dag:
    
    # Task 1: Submit PySpark S3 job
    pyspark_task = SparkKubernetesOperator(
        task_id='pyspark_s3_task',
        namespace='airflow',
        application_file=pyspark_s3_application,
        do_xcom_push=True,
        kubernetes_conn_id='kubernetes_default',
    )
    
    # Task 2: Check result
    check_result = PythonOperator(
        task_id='check_result',
        python_callable=check_pyspark_result,
        provide_context=True,
    )
    
    # Task dependencies
    pyspark_task >> check_result
