# Airflow

One DAG, `zomato_elt_pipeline`, in [`dags/zomato_elt_dag.py`](dags/zomato_elt_dag.py):

```
dbt_debug  ->  dbt_build
```

`dbt_debug` is a two-second connection check. If it fails, `dbt_build` never
starts, so a bad connection fails fast instead of after a long build.

The schedule is `@daily` (midnight UTC). It was only a demo, so the DAG was
triggered by hand once, shown to succeed, and then paused.

## How it was run (Airflow 3.1.0, AWS CloudShell, Python 3.13)

```bash
python3 -m venv ~/airflow-venv && source ~/airflow-venv/bin/activate
export AIRFLOW_HOME=~/airflow
AIRFLOW_VERSION=3.1.0
pip install "apache-airflow==${AIRFLOW_VERSION}" \
  --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-3.13.txt"

# dbt gets its own venv so it and Airflow never conflict over dependencies
python3 -m venv ~/dbt-venv && ~/dbt-venv/bin/pip install dbt-snowflake

cp dags/zomato_elt_dag.py ~/airflow/dags/
AIRFLOW__CORE__LOAD_EXAMPLES=false nohup airflow standalone > ~/airflow.log 2>&1 &
airflow dags unpause zomato_elt_pipeline
airflow dags trigger zomato_elt_pipeline
airflow dags list-runs zomato_elt_pipeline
airflow dags pause zomato_elt_pipeline
```

`airflow standalone` runs the scheduler, API server and a SQLite metadata
database in one process, and prints a generated admin password. That is fine for
a demo. A real deployment would split these services and use Postgres.

## Why not Docker

I first wrote a Dockerfile and docker-compose file. The image build failed with
`no space left on device`. AWS CloudShell's Docker uses the `vfs` storage
driver, which copies every layer in full instead of sharing layers
(copy-on-write, as `overlay2` does), so the Airflow image used far more disk
than its size. CloudShell does not allow changing the driver, so I used a venv.
On a machine with a normal Docker setup, containers would be the better choice.

## Things worth knowing

- A DAG is created paused. A manual trigger of a paused DAG stays `queued`
  until you unpause it.
- Unpausing can create one extra scheduled run for the interval you missed.
  Mine did, and two `dbt build` runs started at the same moment. For a real
  pipeline you would stop that with `max_active_runs=1`.
- The first two runs failed. They exposed a real bug in `fct_order_items`
  (see the main README, lesson 3). The third run succeeded.
