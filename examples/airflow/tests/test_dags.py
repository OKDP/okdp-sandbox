from pathlib import Path

import pytest


airflow = pytest.importorskip("airflow")
from airflow.models import DagBag
from airflow.operators.python import PythonOperator


DAGS_DIR = Path(__file__).resolve().parents[1] / "dags"


@pytest.fixture(scope="module")
def dag_bag() -> DagBag:
    bag = DagBag(dag_folder=str(DAGS_DIR), include_examples=False)
    assert not bag.import_errors, f"DAG import errors: {bag.import_errors}"
    return bag


def test_hello_world_dag_loaded(dag_bag: DagBag) -> None:
    dag = dag_bag.get_dag("hello_world_midnight")
    assert dag is not None
    assert "example" in dag.tags
    assert "okdp" in dag.tags

    task_ids = {task.task_id for task in dag.tasks}
    assert task_ids == {"hello_world_task"}
    hello_task = dag.get_task("hello_world_task")
    assert isinstance(hello_task, PythonOperator)


def test_spark_pi_dag_loaded(dag_bag: DagBag) -> None:
    dag = dag_bag.get_dag("spark_pi_midnight")
    assert dag is not None
    assert "example" in dag.tags
    assert "spark" in dag.tags

    task = dag.get_task("submit_and_wait_spark_pi")
    assert isinstance(task, PythonOperator)
    assert task.op_kwargs["app_name"] == "spark-pi-{{ ts_nodash | lower }}"
