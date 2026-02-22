#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"
DAGS_DIR="${DAGS_DIR:-examples/airflow/dags}"
TRIGGER="${TRIGGER:-false}"

HELLO_DAG_FILE="${DAGS_DIR}/hello_daily.py"
ETL_DAG_FILE="${DAGS_DIR}/orders_etl_daily.py"
ETL_JOB_DIR="${DAGS_DIR}/spark_jobs"
ETL_JOB_FILE="${ETL_JOB_DIR}/orders_etl_job.py"
AIRFLOWIGNORE_FILE="${DAGS_DIR}/.airflowignore"

if [[ ! -f "${HELLO_DAG_FILE}" || ! -f "${ETL_DAG_FILE}" || ! -f "${ETL_JOB_FILE}" || ! -f "${AIRFLOWIGNORE_FILE}" ]]; then
  echo "Missing DAG files in ${DAGS_DIR}"
  exit 1
fi

SCHEDULER_POD="$(kubectl -n "${NAMESPACE}" get pods -l component=scheduler,release=airflow-main -o jsonpath='{.items[0].metadata.name}')"
WEBSERVER_POD="$(kubectl -n "${NAMESPACE}" get pods -l component=webserver,release=airflow-main -o jsonpath='{.items[0].metadata.name}')"

echo "Copy DAGs to scheduler pod: ${SCHEDULER_POD}"
kubectl -n "${NAMESPACE}" cp "${HELLO_DAG_FILE}" "${SCHEDULER_POD}:/opt/airflow/dags/hello_daily.py" -c scheduler
kubectl -n "${NAMESPACE}" cp "${ETL_DAG_FILE}" "${SCHEDULER_POD}:/opt/airflow/dags/orders_etl_daily.py" -c scheduler
kubectl -n "${NAMESPACE}" cp "${AIRFLOWIGNORE_FILE}" "${SCHEDULER_POD}:/opt/airflow/dags/.airflowignore" -c scheduler
kubectl -n "${NAMESPACE}" exec "${SCHEDULER_POD}" -c scheduler -- mkdir -p /opt/airflow/dags/spark_jobs
kubectl -n "${NAMESPACE}" cp "${ETL_JOB_FILE}" "${SCHEDULER_POD}:/opt/airflow/dags/spark_jobs/orders_etl_job.py" -c scheduler
kubectl -n "${NAMESPACE}" exec "${SCHEDULER_POD}" -c scheduler -- sh -lc 'rm -f /opt/airflow/dags/hello_world.py /opt/airflow/dags/spark_pi_example.py'

echo "Copy DAGs to webserver pod: ${WEBSERVER_POD}"
kubectl -n "${NAMESPACE}" cp "${HELLO_DAG_FILE}" "${WEBSERVER_POD}:/opt/airflow/dags/hello_daily.py" -c webserver
kubectl -n "${NAMESPACE}" cp "${ETL_DAG_FILE}" "${WEBSERVER_POD}:/opt/airflow/dags/orders_etl_daily.py" -c webserver
kubectl -n "${NAMESPACE}" cp "${AIRFLOWIGNORE_FILE}" "${WEBSERVER_POD}:/opt/airflow/dags/.airflowignore" -c webserver
kubectl -n "${NAMESPACE}" exec "${WEBSERVER_POD}" -c webserver -- mkdir -p /opt/airflow/dags/spark_jobs
kubectl -n "${NAMESPACE}" cp "${ETL_JOB_FILE}" "${WEBSERVER_POD}:/opt/airflow/dags/spark_jobs/orders_etl_job.py" -c webserver
kubectl -n "${NAMESPACE}" exec "${WEBSERVER_POD}" -c webserver -- sh -lc 'rm -f /opt/airflow/dags/hello_world.py /opt/airflow/dags/spark_pi_example.py'

echo "Reserialize DAGs"
kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags reserialize

echo "Unpause DAGs"
kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags unpause hello_daily
kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags unpause orders_etl_daily

if [[ "${TRIGGER}" == "true" ]]; then
  echo "Trigger DAG runs"
  kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger hello_daily
  kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger orders_etl_daily
fi

echo "Done. Check Airflow UI: https://airflow-default.okdp.sandbox/home"
