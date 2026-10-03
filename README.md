# Zomato ELT: S3, Snowflake, dbt, Airflow and an LLM layer

A batch data pipeline for a food-delivery dataset (10M orders, 23M order items,
300K reviews). I built it to learn the AWS + Snowflake + dbt + Airflow stack by
doing, and I wrote down what broke along the way, because that is where most of
the learning was.

It follows the architecture of
[this DataVidhya tutorial](https://youtu.be/kYwaNMQ3XT8). The code is my own: I
wrote it against my own accounts and checked it against the real data.
The AWS Glue and Athena parts, and the LLM step, go beyond the tutorial.

## Architecture (as built)

```
Zomato CSVs
   |
   v
Amazon S3  (raw/ landing zone)
   |   Snowflake Storage Integration: Snowflake assumes an IAM role via STS.
   |   No AWS keys are stored anywhere.
   v
Snowflake RAW        Bronze. COPY INTO, untouched.
   |   dbt
   v
Snowflake STAGING    Silver. One cleaned, typed view per source table.
   |   dbt
   v
Snowflake MARTS      Gold. Dimensions, incremental facts (MERGE), SCD2 snapshot, business marts.
   |
   v
Snowflake AI         LLM sentiment and topic per review comment, joined to every review.

Airflow runs the dbt build as a DAG: dbt_debug, then dbt_build.
```

## What is verified and what is not

| Part | Status |
|---|---|
| S3 and IAM storage integration, RAW load | Ran for real |
| dbt: 17 models, 1 snapshot, 28 tests. The core build passed 40/40 on a 10M + 23M row load | Ran for real, twice |
| Airflow 3.1 DAG (`dbt_debug` then `dbt_build`) | Ran for real, success |
| LLM enrichment of review comments, and the dbt model that joins it | Ran for real |
| `ai/ask.py` (plain-English question to SQL) | Written and unit-tested only. Never run against a live Snowflake, because my trial ended first |
| AWS Glue and Athena | Planned, not built yet |
| RAG chat | Dropped on purpose. The reviews are only 294 distinct one-line comments, so there is nothing to retrieve that a GROUP BY does not already answer |

Real numbers and outputs are in [`docs/RUN_LOG.md`](docs/RUN_LOG.md).

## Design decisions

- **Storage integration, not access keys.** Snowflake gets short-lived
  credentials by assuming an IAM role, so no long-lived secret sits inside
  Snowflake. Details and two debugging lessons: [`aws/iam/README.md`](aws/iam/README.md).
- **Key-pair auth for the dbt service user.** No password is stored or typed.
- **Staging as views, marts as tables.** Staging is cheap and always fresh, so a
  view costs nothing to store. Marts are queried repeatedly and involve joins,
  so they are materialized once.
- **Incremental MERGE for the two big facts.** A full rebuild would re-write
  33M rows every run. The first load and a re-run both pass.
- **dbt snapshot for SCD2.** A declarative version of the hash-compare change
  tracking I had hand-written in PySpark for another project.
- **`TRY_TO_NUMBER` / `TRY_TO_DECIMAL` in staging.** The source is genuinely
  messy (ratings like `--`, costs like `₹ 200`). These return NULL instead of
  failing the whole load.
- **LLM scores distinct comments, not rows.** 300,000 reviews contain only 294
  distinct comments. The script scores those 294 once and dbt joins the answers
  back, instead of making 300,000 LLM calls. The LLM must answer in JSON from a
  fixed list of values, so its output becomes clean columns.
- **Text-to-SQL is guarded.** `ask.py` describes only chosen tables to the
  model, and runs the generated query only if it is a single SELECT.

## What broke, and what I learned

1. **Docker could not build Airflow in AWS CloudShell.** CloudShell's Docker
   uses the `vfs` storage driver, which copies every image layer in full, so
   the Airflow image filled the disk. I ran Airflow in a Python venv instead.
   See [`airflow/README.md`](airflow/README.md).
2. **Airflow 2.9 has no tested dependency set for Python 3.13.** The constraints
   file returned 404. I moved to Airflow 3.1, which has one, and updated the DAG
   (`schedule` instead of `schedule_interval`, a new `BashOperator` import path).
3. **An incremental model passed on its first run and failed on its second.**
   `fct_order_items` used `ref('fct_orders')` inside `{% if is_incremental() %}`.
   dbt reads dependencies at parse time, when that block is skipped, so it never
   saw the dependency. Airflow's second run exposed it. The fix is a
   `-- depends_on:` hint. The lesson: run an incremental pipeline twice before
   trusting it.
4. **Snowflake Cortex AI functions are blocked on trial accounts.** I used an
   external LLM API instead. Model names also change: the model I first picked
   returned 404 "no longer available to new users".
5. **CloudShell only keeps your home directory between sessions.** A dbt install
   outside it was gone the next day. Tools now live in venvs under `~`.

## Repository layout

```
snowflake/        Setup SQL, run in order in Snowsight
aws/iam/          IAM policy and trust policy, with the handshake explained
zomato/           dbt project
  models/staging/   Silver views
  models/marts/     Gold: dimensions, incremental facts, marts
  models/marts_ai/  AI layer: LLM lookup joined to all reviews
  snapshots/        SCD2 history of restaurants
airflow/dags/     The DAG that ran
ai/               enrich_reviews.py (LLM step) and ask.py (text-to-SQL)
docs/             Run log with real outputs
```

## Reproducing it

You need an AWS account, a Snowflake account, and a Gemini API key (free tier).

1. Upload the CSVs to S3. Run `snowflake/01` to `03` in Snowsight, following
   `aws/iam/README.md` for the AWS side.
2. Create a key pair, register the public key on the Snowflake user, and copy
   `zomato/profiles.yml.example` to `~/.dbt/profiles.yml`.
3. `cd zomato && dbt debug && dbt build`
4. Set `SNOWFLAKE_ACCOUNT` and `GEMINI_API_KEY` in your shell, then run
   `python ai/enrich_reviews.py`, then `dbt build --select tag:ai`.
5. For Airflow, follow `airflow/README.md`.

## Known issues

- dbt prints a deprecation warning: generic test arguments should be nested
  under `arguments:`. Tests still pass.
- Each review gets one topic. A comment such as "Arrived earlier than expected.
  Authentic taste." covers two topics but is labelled with the first one.
- Numbers in the run log come from a Snowflake trial that has now ended, so the
  warehouse is no longer available to re-run against.

---

Racshan Chandrakumar, Data Engineer.
[LinkedIn](https://linkedin.com/in/racshan-chandrakumar)
