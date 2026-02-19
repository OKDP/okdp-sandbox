# Airflow DAGs (OKDP Sandbox)

Ce dossier contient 2 DAGs de test pour Airflow:

- `hello_world.py`: DAG Python classique, exécution quotidienne à minuit UTC.
- `spark_pi_example.py`: DAG Spark qui crée une ressource `SparkApplication` et attend la fin (`COMPLETED`).

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
2. lance `airflow dags reserialize`,
3. unpause les DAGs.

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

## Vérifier l'état

```bash
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags list
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags list-runs -d hello_world_midnight
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags list-runs -d spark_pi_midnight
kubectl -n default get sparkapplications.sparkoperator.k8s.io
```

## Déclenchement manuel (si besoin)

```bash
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger hello_world_midnight
kubectl -n default exec deploy/airflow-main-scheduler -c scheduler -- airflow dags trigger spark_pi_midnight
```

## Notes

- Les DAGs sont planifiés à `00:00` UTC (`schedule: "0 0 * * *"`).
- Le DAG Spark crée un nom d'application unique par run Airflow.
