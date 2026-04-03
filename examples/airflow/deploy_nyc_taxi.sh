#!/bin/bash
#
# Déploiement du pipeline NYC Taxi (Airflow + Spark Operator)
# Usage: ./examples/airflow/deploy_nyc_taxi.sh
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="default"

echo "======================================================================="
echo "NYC Taxi Pipeline - Déploiement"
echo "======================================================================="

# --- Prérequis ---
echo ""
echo "1. Vérification des prérequis"
echo "-----------------------------------------------------------------------"

for check in \
  "kubectl:command -v kubectl" \
  "Cluster:kubectl cluster-info" \
  "Spark Operator:kubectl get crd sparkapplications.sparkoperator.k8s.io" \
  "ServiceAccount spark:kubectl get sa spark -n $NAMESPACE" \
  "Secret S3:kubectl get secret creds-examples-s3 -n $NAMESPACE"; do
    label="${check%%:*}"
    cmd="${check#*:}"
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓ $label${NC}"
    else
        echo -e "${RED}✗ $label${NC}"
        exit 1
    fi
done

# --- ConfigMap ---
echo ""
echo "2. Déploiement du ConfigMap Spark ETL"
echo "-----------------------------------------------------------------------"

if kubectl apply -f examples/airflow/manifests/nyc-taxi-etl-configmap.yaml; then
    echo -e "${GREEN}✓ ConfigMap déployé${NC}"
else
    echo -e "${RED}✗ Échec déploiement ConfigMap${NC}"
    exit 1
fi

# --- DAG ---
echo ""
echo "3. Déploiement du DAG Airflow"
echo "-----------------------------------------------------------------------"

SCHEDULER_POD=$(kubectl get pod -n $NAMESPACE -l component=scheduler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$SCHEDULER_POD" ]; then
    echo -e "${YELLOW}⚠ Airflow scheduler non trouvé dans namespace $NAMESPACE${NC}"
    echo "  Copiez manuellement le DAG:"
    echo "  kubectl cp examples/airflow/dags/nyc_taxi_pipeline.py $NAMESPACE/<scheduler-pod>:/opt/airflow/dags/"
else
    if kubectl cp examples/airflow/dags/nyc_taxi_pipeline.py \
        "$NAMESPACE/$SCHEDULER_POD:/opt/airflow/dags/" 2>/dev/null; then
        echo -e "${GREEN}✓ DAG copié dans $SCHEDULER_POD${NC}"
    else
        echo -e "${YELLOW}⚠ Échec copie du DAG${NC}"
    fi
fi

# --- Done ---
echo ""
echo "======================================================================="
echo -e "${GREEN}Déploiement terminé${NC}"
echo "======================================================================="
echo ""
echo "Prochaines étapes:"
echo "  1. Ouvrir Airflow UI : https://airflow.okdp.sandbox"
echo "  2. Trigger le DAG 'nyc_taxi_spark_pipeline'"
echo "  3. Surveiller : kubectl get sparkapplication -n $NAMESPACE -w"
echo ""
