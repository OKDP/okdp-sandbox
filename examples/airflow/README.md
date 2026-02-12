# Airflow DAG Testing

Ce dossier contient les DAGs d'exemple et une base de tests propre.

## DAGs

- `hello_world.py`: DAG minimal de validation.
- `spark_pi_example.py`: soumet une `SparkApplication` via Spark Operator.

## Tests unitaires (structure DAG)

Depuis la racine du repo:

```bash
pytest -q examples/airflow/tests/test_dags.py
```

Ces tests valident:
- chargement des DAGs sans erreur d'import,
- IDs des tâches,
- paramètres principaux (schedule, tags),
- configuration de la tâche Spark.

## Tests d'intégration (dans Airflow du cluster)

Script prêt à l'emploi:

```bash
./examples/airflow/tests/run_integration_tests.sh [namespace] [release] [exec_date] [dags_src_dir]
```

Exemple:

```bash
./examples/airflow/tests/run_integration_tests.sh default airflow-main 2026-01-01
```

Le script exécute:
- copie les DAGs locaux vers `/opt/airflow/dags` dans le webserver,
- `airflow tasks test hello_world hello ...`
- `airflow dags test spark_pi_example ...`

## Étape suivante recommandée

Quand ces deux DAGs sont validés, créer un DAG ETL (extract -> transform -> load) avec:
- capteur/source de données,
- tâche Spark de transformation,
- validation qualité des données,
- publication vers table cible.
