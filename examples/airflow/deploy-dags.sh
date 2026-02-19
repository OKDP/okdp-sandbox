#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"
DAGS_DIR="${DAGS_DIR:-examples/airflow/dags}"
TRIGGER="${TRIGGER:-false}"

HELLO_DAG_FILE="${DAGS_DIR}/hello_world.py"
SPARK_DAG_FILE="${DAGS_DIR}/spark_pi_example.py"

if [[ ! -f "${HELLO_DAG_FILE}" || ! -f "${SPARK_DAG_FILE}" ]]; then
  echo "Missing DAG files in ${DAGS_DIR}"
  exit 1
fi

SCHEDULER_POD="$(kubectl -n "${NAMESPACE}" get pods -l component=scheduler,release=airflow-main -o jsonpath='{.items[0].metadata.name}')"
WEBSERVER_POD="$(kubectl -n "${NAMESPACE}" get pods -l component=webserver,release=airflow-main -o jsonpath='{.items[0].metadata.name}')"

echo "Copy DAGs to scheduler pod: ${SCHEDULER_POD}"
kubectl -n "${NAMESPACE}" cp "${HELLO_DAG_FILE}" "${SCHEDULER_POD}:/opt/airflow/dags/hello_world.py" -c scheduler
kubectl -n "${NAMESPACE}" cp "${SPARK_DAG_FILE}" "${SCHEDULER_POD}:/opt/airflow/dags/spark_pi_example.py" -c scheduler

echo "Copy DAGs to webserver pod: ${WEBSERVER_POD}"
kubectl -n "${NAMESPACE}" cp "${HELLO_DAG_FILE}" "${WEBSERVER_POD}:/opt/airflow/dags/hello_world.py" -c webserver
kubectl -n "${NAMESPACE}" cp "${SPARK_DAG_FILE}" "${WEBSERVER_POD}:/opt/airflow/dags/spark_pi_example.py" -c webserver

echo "Reserialize DAGs"
kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags reserialize

echo "Unpause DAGs"
kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags unpause hello_world_midnight
kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags unpause spark_pi_midnight

if [[ "${TRIGGER}" == "true" ]]; then
  echo "Trigger DAG runs"
  kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger hello_world_midnight
  kubectl -n "${NAMESPACE}" exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger spark_pi_midnight
fi

echo "Done. Check Airflow UI: https://airflow-default.okdp.sandbox/home"
