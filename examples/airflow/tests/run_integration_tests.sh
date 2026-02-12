#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"
RELEASE="${2:-airflow-main}"
EXEC_DATE="${3:-2026-01-01}"
DAGS_SRC_DIR="${4:-examples/airflow/dags}"

find_webserver_pod() {
  kubectl get pods -n "${NAMESPACE}" --no-headers \
    | awk '/airflow-main-webserver/ && $2 ~ /^1\/1$/ && $3 == "Running" {print $1; exit}'
}

POD="$(find_webserver_pod)"
if [[ -z "${POD}" ]]; then
  echo "Airflow webserver pod introuvable dans namespace ${NAMESPACE}"
  exit 1
fi

echo "Using pod: ${POD}"
echo "Syncing DAGs from ${DAGS_SRC_DIR}..."
kubectl cp "${DAGS_SRC_DIR}/." "${NAMESPACE}/${POD}:/opt/airflow/dags" -c webserver
sleep 8

echo "Listing DAGs..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- airflow dags list | grep -E "hello_world|spark_pi_example"

echo "Testing hello_world..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- airflow tasks test hello_world hello "${EXEC_DATE}"

echo "Testing spark_pi_example..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- airflow dags test spark_pi_example "${EXEC_DATE}"

echo "All integration DAG tests passed."
