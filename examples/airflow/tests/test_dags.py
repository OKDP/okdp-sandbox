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


def test_hello_daily_dag_loaded(dag_bag: DagBag) -> None:
    dag = dag_bag.get_dag("hello_daily")
    assert dag is not None
    assert "example" in dag.tags
    assert "daily" in dag.tags

    task_ids = {task.task_id for task in dag.tasks}
    assert task_ids == {"log_hello"}
    hello_task = dag.get_task("log_hello")
    assert isinstance(hello_task, PythonOperator)


def test_orders_etl_dag_loaded(dag_bag: DagBag) -> None:
    dag = dag_bag.get_dag("orders_etl_daily")
    assert dag is not None
    assert "etl" in dag.tags
    assert "spark" in dag.tags

    task = dag.get_task("submit_and_wait_orders_etl")
    assert isinstance(task, PythonOperator)
    assert task.op_kwargs["run_suffix"] == "{{ ts_nodash | lower }}"
