# Airflow DAGs (OKDP Sandbox)

Ce dossier contient 2 DAGs de test pour Airflow:

- `hello_daily.py`: DAG Python minimal (smoke test), exécution quotidienne à minuit UTC.
- `orders_etl_daily.py`: DAG Spark ETL via Spark Operator (soumet un `SparkApplication`).

Le code ETL Spark est dans:

- `spark_jobs/orders_etl_job.py`

## Prerequis

- Airflow accessible sur `https://airflow-default.okdp.sandbox/home`
- Spark Operator installé
- ServiceAccount `spark` présent dans le namespace `default`

## Déploiement rapide des DAGs

Depuis la racine du repo:

```bash
bash examples/airflow/deploy-dags.sh
```

Le script:

1. copie les DAGs dans `/opt/airflow/dags` (scheduler + webserver),
2. copie le script ETL Spark dans `/opt/airflow/dags/spark_jobs`,
3. lance `airflow dags reserialize`,
4. unpause les DAGs.

Pour déployer + déclencher immédiatement les 2 DAGs:

```bash
TRIGGER=true bash examples/airflow/deploy-dags.sh
```

## Modes de provisioning des DAGs

Le package Airflow supporte trois modes (`parameters.dagsSource` dans `clusters/sandbox/releases/addons/airflow.yaml`):

- `local` (par défaut): copie manuelle avec `deploy-dags.sh`
- `git`: sync automatique via `dags.gitSync`
- `s3`: sync automatique via sidecar S3 sur scheduler + webserver

Exemple mode Git:

```yaml
parameters:
  dagsSource: git
  dagGitRepo: https://github.com/your-org/your-dags-repo.git
  dagGitBranch: main
  dagGitSubPath: dags
  dagSyncIntervalSeconds: 60
```

Exemple mode S3:

```yaml
parameters:
  dagsSource: s3
  dagS3Bucket: airflow-dags
  dagS3Prefix: dags
  dagSyncIntervalSeconds: 60
```

Le fichier `examples/airflow/dags/.airflowignore` est fourni comme équivalent de `.gitignore` pour ignorer les artefacts locaux/non-DAG.
Le dossier `spark_jobs/` y est ignoré côté parsing Airflow (ce n'est pas un DAG).

## Vérifier l'état

```bash
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags list
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags list-runs -d hello_daily
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags list-runs -d orders_etl_daily
kubectl -n default get sparkapplications.sparkoperator.k8s.io
```

## Déclenchement manuel (si besoin)

```bash
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger hello_daily
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger orders_etl_daily
```

## Configuration S3 portable (important)

Le DAG `orders_etl_daily` n'utilise plus un service SeaweedFS hardcodé de type `seaweedfs-xxxx`.

Résolution S3:

1. `AIRFLOW_ETL_S3_ENDPOINT` (si défini),
2. auto-détection d'un service Kubernetes `seaweedfs-*-s3` dans le namespace,
3. fallback URL ingress `https://seaweedfs-seaweedfs-<namespace>.<suffix>`.

Variables optionnelles:

- `AIRFLOW_ETL_S3_BUCKET` (défaut: `airflow-logs`)
- `AIRFLOW_ETL_S3_INPUT_PREFIX` (défaut: `orders/raw`)
- `AIRFLOW_ETL_S3_OUTPUT_PREFIX` (défaut: `orders/curated`)
- `AIRFLOW_INGRESS_SUFFIX` (défaut: `okdp.sandbox`)

## Notes

- Les DAGs sont planifiés à `00:00` UTC (`schedule: "0 0 * * *"`).
- Le DAG ETL Spark crée un nom d'application unique par run Airflow.
- Le job Spark lit `orders` en entrée (S3), applique un nettoyage/agrégation simple, puis écrit en zone `curated`.
