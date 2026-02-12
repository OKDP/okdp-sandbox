"""
Airflow DAG to run Spark Pi example using SparkApplication CRD.
"""

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
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
        task_id='submit_spark_pi',
        namespace='default',
        image='bitnami/kubectl:latest',
        cmds=['sh', '-ec'],
        arguments=[
            """
cat <<EOF | kubectl apply -f -
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: ${SPARK_APP_NAME}
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: docker.io/bitnami/spark:3.5.1
  imagePullPolicy: IfNotPresent
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: local:///opt/bitnami/spark/examples/jars/spark-examples_2.12-3.5.1.jar
  sparkVersion: 3.5.1
  restartPolicy:
    type: Never
  driver:
    cores: 1
    memory: 512m
    serviceAccount: spark
    labels:
      version: 3.5.1
  executor:
    cores: 1
    instances: 1
    memory: 512m
    labels:
      version: 3.5.1
EOF
"""
        ],
        env_vars={
            'SPARK_APP_NAME': 'spark-pi-{{ ds_nodash }}',
        },
        service_account_name='spark',
        name='spark-pi-submitter',
        is_delete_operator_pod=True,
        in_cluster=True,
        get_logs=True,
    )
