# Zomato ELT — AWS S3 → Snowflake → dbt → Airflow → AI

An end-to-end batch pipeline built while preparing for a Senior Data
Engineer role using AWS + Snowflake, mirroring the stack I'll be working
with day one. Built in a 4-day sprint against a Snowflake trial deadline.

**Inspired by / followed alongside** [this tutorial](https://youtu.be/kYwaNMQ3XT8)
by DataVidhya — the core S3 → Snowflake → dbt → Airflow → AI architecture
follows that walkthrough. What's here is my own implementation against my
own data and accounts, with real column names/values from my own dataset
(not copy-pasted), my own IAM debugging notes, and my own extensions
(noted below) to close the gap against my actual target stack.

## Status

🚧 Work in progress — building against a hard Snowflake trial deadline.
See commit history for what's real vs. scaffolded.

## Architecture

```
Zomato dataset (CSV)
   │
   ▼
Amazon S3  (raw/ landing zone)
   │  Storage Integration — IAM role assumed via STS, no stored keys
   ▼
Snowflake RAW   (Bronze — COPY INTO, untouched)
   │  dbt
   ▼
Snowflake STAGING (Silver — cleaned, typed, one view per source)
   │  dbt (dims, incremental facts via MERGE, SCD2 snapshot)
   ▼
Snowflake MARTS (Gold — dimensional model + business marts)
   │
   ▼
Snowflake AI    (LLM-enriched reviews: sentiment, topic)
   │
   ▼
Apache Airflow  — orchestrates the whole thing as one daily DAG
```

## Why these choices (not just what)

- **Storage integration over access keys** — Snowflake assumes an IAM role
  via STS; no long-lived credential is ever embedded in Snowflake. See
  [`aws/iam/README.md`](aws/iam/README.md) for the exact trust-policy setup
  and two real debugging lessons from getting this working.
- **RSA key-pair auth for the dbt service user** — no password stored or
  typed anywhere in the pipeline; matches how a real production dbt/Airflow
  connection to Snowflake should authenticate.
- **Incremental + merge for the two large fact tables** (10M orders,
  ~23M order items) — a full rebuild on every run would re-scan and
  re-write everything; incremental models only touch what's actually new.
- **dbt snapshot for SCD2** — the declarative equivalent of the
  hand-coded four-DataFrame CDC pattern (insert/update/reactive/delete via
  hash comparison) I built on Microsoft Fabric/PySpark in my day job; same
  underlying idea, different tool.
- **`TRY_TO_NUMBER` / `TRY_TO_DECIMAL` everywhere in staging** — the
  source data is genuinely messy (ratings like `'--'`, costs like
  `'₹ 200'`); these functions return `NULL` on a bad parse instead of
  failing the whole load, matching a real production tolerance for dirty
  source data.

## What extends beyond the tutorial

The tutorial's stack (S3 → Snowflake → dbt → Airflow) doesn't include two
services my actual target role uses: **AWS Glue** and **Athena**. This
project adds:
- an AWS Glue PySpark job doing a real Bronze→Silver style transform
  directly on S3 (independent of the Snowflake/dbt path)
- an Athena layer for ad-hoc SQL directly against S3 data via the Glue
  Data Catalog

(See `glue/` and `athena/` — added after the core Snowflake/dbt/Airflow
pipeline was working.)

## Repository structure

```
├── snowflake/           # Snowflake setup SQL, run in order in Snowsight
├── aws/iam/             # IAM policy + trust policy JSON, with a README
│                         #   explaining the storage-integration handshake
├── zomato/              # dbt project
│   ├── models/staging/  #   Silver views — one per source table
│   ├── models/marts/    #   Gold — dims, incremental facts, business marts
│   ├── snapshots/       #   SCD2 history on the restaurant dimension
│   └── macros/          #   schema-name override
├── airflow/              # Airflow DAG orchestrating the pipeline
├── ai/                   # LLM enrichment, RAG chat, text-to-SQL
└── docs/                 # architecture notes, screenshots
```

## Running it

```bash
# 1. Snowflake objects — run snowflake/01 -> 05 in Snowsight, in order.
#    See aws/iam/README.md for the AWS-side steps that pair with 02/03.

# 2. dbt (run from Codespaces or any environment with real network egress
#    to snowflakecomputing.com)
cd zomato
cp profiles.yml.example ~/.dbt/profiles.yml   # fill in your own values
dbt debug
dbt build

# 3. Airflow
cd ../airflow
cp example.env .env    # fill in SNOWFLAKE_* and OPENAI_API_KEY
docker compose build && docker compose up -d
# http://localhost:8080

# 4. AI layer
export OPENAI_API_KEY=sk-...
python ai/enrich_reviews.py
```

---

Racshan Chandrakumar — Data Engineer, transitioning into a Senior Data
Engineer role at Dialog Axiata PLC.
[LinkedIn](https://linkedin.com/in/racshan-chandrakumar)
