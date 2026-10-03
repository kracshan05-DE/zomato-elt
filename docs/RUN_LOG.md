# Run log

Real results from the runs. The Snowflake trial has ended, so these cannot be
re-run. Timings are from AWS CloudShell against a Snowflake trial warehouse
(`ZOMATO_WH`).

## 1. First `dbt build`

`dbt build` in `zomato/`: **PASS=40, WARN=0, ERROR=0, SKIP=0**, in 19.15 seconds.

| Model | Type | Rows |
|---|---|---|
| stg_* (7 models) | view | n/a |
| dim_date | table | 1,500 |
| dim_food | table | 1,179,936 |
| dim_restaurants | table | 148,541 |
| dim_customer | table | 100,000 |
| fct_orders | incremental (merge) | 10,000,000 |
| fct_order_items | incremental (merge) | 22,998,179 |
| restaurants_snapshot | snapshot (SCD2) | 148,541 |
| mart_daily_city_revenue | table | 651,685 |
| mart_delivery_sla | table | 821 |
| mart_restaurant_performance | table | 148,541 |

23 data tests passed: unique and not_null on every primary key, accepted values
on `order_status`, and the `fct_orders.customer_id` to `dim_customer`
relationship.

## 2. First two Airflow runs failed

`dbt_debug` passed (`Connection test: OK`, `All checks passed!`). `dbt_build`
then ran 37 of 40 steps and stopped:

```
Compilation Error in model fct_order_items
  dbt was unable to infer all dependencies for the model "fct_order_items".
  This typically happens when ref() is placed within a conditional block.
  To fix this, add the following hint to the top of the model:
  -- depends_on: {{ ref('fct_orders') }}
Done. PASS=37 WARN=0 ERROR=1 SKIP=2 NO-OP=0 REUSED=0 TOTAL=40
```

Cause: `ref('fct_orders')` sits inside `{% if is_incremental() %}`. dbt reads
dependencies at parse time, when `is_incremental()` is false, so it missed the
dependency. The first-ever run is not incremental, so it passed. The second run
is incremental, so it failed. The 2 skipped steps were the tests on that model.

## 3. After adding the `depends_on` hint

- Direct `dbt build`: **PASS=40, ERROR=0**, 13.30 seconds. This was a second run,
  so it exercised the incremental path.
- Airflow `manual__...16:50:17` run: **success**, about 22 seconds. Both tasks
  ran in order. The two earlier runs stay in the history as `failed`.

## 4. LLM enrichment

`ai/enrich_reviews.py` with `gemini-3.5-flash-lite`:

- 300,000 reviews, **294 distinct comments**, scored in 10 batches of up to 30
- Sentiment: positive 145, negative 145, neutral 4
- Topic: food_quality 85, delivery_speed 58, packaging 52, price_value 42,
  delivery_partner 27, overall_experience 18, other 12
- Wrote 294 rows to `ZOMATO.AI.COMMENT_ENRICHMENT`, with no dropped comments

`dbt build --select tag:ai`: `fct_review_enriched` built with **300,000 rows**,
and all 5 tests passed (`not_null` on sentiment and topic prove that every review
matched a scored comment).

## 5. Things that failed before they worked

| What | Cause |
|---|---|
| Docker build of Airflow: `no space left on device` | CloudShell Docker uses the `vfs` driver, which copies every layer in full |
| Airflow 2.9.3 constraints file returned 404 | No tested dependency set for Python 3.13. Airflow 3.1.0 has one |
| `dbt` command missing the next day | The install was outside the home directory, which CloudShell resets |
| `SENTIMENT is not available for trial accounts` | Snowflake Cortex AI functions are blocked on trial accounts |
| Gemini 404 `no longer available to new users` | The model I first chose was retired. The error named its replacement |
