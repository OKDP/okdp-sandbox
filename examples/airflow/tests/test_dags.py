from pathlib import Path

import pytest


airflow = pytest.importorskip("airflow")
from airflow.models import DagBag
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator


DAGS_DIR = Path(__file__).resolve().parents[1] / "dags"


@pytest.fixture(scope="module")
def dag_bag() -> DagBag:
    bag = DagBag(dag_folder=str(DAGS_DIR), include_examples=False)
    assert not bag.import_errors, f"DAG import errors: {bag.import_errors}"
    return bag


def test_hello_world_dag_loaded(dag_bag: DagBag) -> None:
    dag = dag_bag.get_dag("hello_world")
    assert dag is not None
    assert dag.schedule_interval == "@daily"
    assert "okdp" in dag.tags

    task_ids = {task.task_id for task in dag.tasks}
    assert task_ids == {"hello"}


def test_spark_pi_dag_loaded(dag_bag: DagBag) -> None:
    dag = dag_bag.get_dag("spark_pi_example")
    assert dag is not None
    assert dag.schedule_interval == "@daily"
    assert "spark" in dag.tags

    task = dag.get_task("submit_spark_pi")
    assert isinstance(task, KubernetesPodOperator)
    assert task.namespace == "default"
    assert task.image == "bitnami/kubectl:latest"
    assert task.env_vars["SPARK_APP_NAME"] == "spark-pi-{{ ds_nodash }}"
    command = " ".join(task.arguments)
    assert "sparkoperator.k8s.io/v1beta2" in command
    assert "kind: SparkApplication" in command
