#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"
RELEASE="${2:-airflow-main}"
EXEC_DATE="${3:-2026-01-01}"
DAGS_SRC_DIR="${4:-examples/airflow/dags}"

find_scheduler_pod() {
  kubectl get pods -n "${NAMESPACE}" --no-headers \
    | awk '/airflow-main-scheduler/ && $2 ~ /^1\/1$/ && $3 == "Running" {print $1; exit}'
}

find_webserver_pod() {
  kubectl get pods -n "${NAMESPACE}" --no-headers \
    | awk '/airflow-main-webserver/ && $2 ~ /^1\/1$/ && $3 == "Running" {print $1; exit}'
}

SCHEDULER_POD="$(find_scheduler_pod)"
WEBSERVER_POD="$(find_webserver_pod)"

if [[ -z "${SCHEDULER_POD}" || -z "${WEBSERVER_POD}" ]]; then
  echo "Pods Airflow introuvables dans namespace ${NAMESPACE}"
  exit 1
fi

echo "Using scheduler pod: ${SCHEDULER_POD}"
echo "Using webserver pod: ${WEBSERVER_POD}"
echo "Syncing DAGs from ${DAGS_SRC_DIR}..."
kubectl cp "${DAGS_SRC_DIR}/." "${NAMESPACE}/${SCHEDULER_POD}:/opt/airflow/dags" -c scheduler
kubectl cp "${DAGS_SRC_DIR}/." "${NAMESPACE}/${WEBSERVER_POD}:/opt/airflow/dags" -c webserver
sleep 8

echo "Reserializing DAGs..."
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -c scheduler -- airflow dags reserialize

echo "Listing DAGs..."
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -c scheduler -- airflow dags list | grep -E "hello_daily|orders_etl_daily"

echo "Testing hello_daily..."
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -c scheduler -- airflow tasks test hello_daily log_hello "${EXEC_DATE}"

echo "Testing orders_etl_daily..."
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -c scheduler -- airflow dags test orders_etl_daily "${EXEC_DATE}"

echo "All integration DAG tests passed."
