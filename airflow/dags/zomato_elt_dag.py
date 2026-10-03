"""
Zomato ELT pipeline DAG (Airflow 3.x).

Replaces a human typing `dbt debug` and then `dbt build`. Order matters:
dbt_debug (a ~2 second connection check) must pass before dbt_build runs,
so a connection problem fails fast instead of after a long build.

dbt lives in its own virtualenv (~/dbt-venv) and is called by full path, so
Airflow and dbt never share (and never conflict over) Python dependencies.
"""
import os
from datetime import datetime

from airflow import DAG
from airflow.providers.standard.operators.bash import BashOperator

HOME = os.path.expanduser("~")
DBT_BIN = f"{HOME}/dbt-venv/bin/dbt"
DBT_PROJECT_DIR = f"{HOME}/zomato-elt/zomato"
DBT_PROFILES_DIR = f"{HOME}/.dbt"

with DAG(
    dag_id="zomato_elt_pipeline",
    description="Verify Snowflake connection, then build staging -> marts -> snapshot",
    start_date=datetime(2026, 9, 1),
    schedule="@daily",  # midnight UTC = 05:30 Colombo; left paused after the demo
    catchup=False,
    tags=["zomato", "elt", "dbt", "snowflake"],
) as dag:

    dbt_debug = BashOperator(
        task_id="dbt_debug",
        bash_command=f"{DBT_BIN} debug --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR}",
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"{DBT_BIN} build --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR}",
    )

    dbt_debug >> dbt_build
