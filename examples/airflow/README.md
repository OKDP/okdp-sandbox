# NYC Taxi Pipeline - Airflow + Spark

Pipeline ETL utilisant Airflow pour orchestrer un job Spark sur des données NYC Taxi (11M+ lignes) stockées dans SeaweedFS S3.

## Démarrage rapide

```bash
# 1. Déployer le ConfigMap Spark ETL + le DAG
./examples/airflow/deploy_nyc_taxi.sh

# 2. Ouvrir Airflow et lancer le DAG "nyc_taxi_spark_pipeline"
open https://airflow.okdp.sandbox

# 3. Vérifier les résultats dans SeaweedFS S3
kubectl run --rm -it s3-check --image=amazon/aws-cli:latest --restart=Never \
  --command -- aws --endpoint-url http://seaweedfs-pmj3xs-s3.default.svc.cluster.local:8333 \
  --no-verify-ssl s3 ls s3://okdp/examples/data/processed/nyc_taxi/ --recursive
```

## Architecture

```
Airflow DAG (PythonOperator)
    → SparkApplication (Spark Operator)
        → Spark Driver + Executor
            → Lecture: s3a://okdp/examples/data/raw/tripdata/yellow/  (11M lignes)
            → Nettoyage + Agrégation (168 lignes: 24h × 7 jours)
            → Écriture: s3a://okdp/examples/data/processed/nyc_taxi/yellow/run_id=.../nyc_taxi_aggregated.csv
```

## Données

Données NYC Yellow Taxi déjà présentes dans SeaweedFS (package `okdp-examples`) :

```
s3://okdp/examples/data/raw/tripdata/yellow/
├── month=2025-01/yellow_tripdata_2025-01.parquet  (59 MB)
├── month=2025-02/yellow_tripdata_2025-02.parquet  (60 MB)
└── month=2025-03/yellow_tripdata_2025-03.parquet  (70 MB)
```

Aucun téléchargement requis.

## Le pipeline

1. **Lecture** — Lit les 3 mois de données Parquet depuis S3 (11M+ lignes)
2. **Nettoyage** — Filtre les courses invalides (fare ≤ 0, distance ≤ 0, etc.)
3. **Agrégation** — Regroupe par heure et jour de la semaine (168 lignes)
4. **Écriture** — Upload le CSV agrégé dans SeaweedFS via le SDK AWS Java

> **Note** : L'écriture utilise le JVM S3 SDK (pas le Hadoop FileOutputCommitter) pour contourner un bug `copyObject` de SeaweedFS.

## Commandes utiles

```bash
# Statut du SparkApplication
kubectl get sparkapplications -n default

# Logs du driver Spark
kubectl logs -n default -l spark-role=driver --tail=50

# Lister les DAG runs Airflow
kubectl exec -n default deploy/airflow-main-scheduler -c scheduler -- \
  airflow dags list-runs -d nyc_taxi_spark_pipeline -o plain
```

## Structure

```
examples/airflow/
├── README.md
├── deploy_nyc_taxi.sh              # Script de déploiement
├── dags/
│   └── nyc_taxi_pipeline.py        # DAG Airflow (PythonOperator + K8s API)
└── manifests/
    └── nyc-taxi-etl-configmap.yaml  # Code PySpark ETL
```

## License

Apache 2.0
