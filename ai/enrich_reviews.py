"""
Enrich review comments with sentiment + topic using an LLM (Google Gemini).

Flow:
  1. Read the DISTINCT review comments from Snowflake (ZOMATO.STAGING.STG_REVIEWS).
     The dataset has 300,000 reviews but only ~294 distinct comment texts, so we
     score each distinct text once, not each row.
  2. Send them to the LLM in batches. The LLM must answer in strict JSON with a
     fixed list of allowed values, so the output loads straight into columns.
  3. Write the results to ZOMATO.AI.COMMENT_ENRICHMENT (a small lookup table).
     A dbt model then joins this lookup back to all 300,000 reviews.

Usage:
  export GEMINI_API_KEY=...            # never put the key in a file
  python enrich_reviews.py --limit 10 --dry-run   # cheap test, writes nothing
  python enrich_reviews.py                        # full run, writes to Snowflake
"""

import argparse
import enum
import json
import os
import time
from collections import Counter

import snowflake.connector
from cryptography.hazmat.primitives import serialization
from google import genai
from google.genai import types
from pydantic import BaseModel

MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite")
BATCH_SIZE = 30

SNOWFLAKE_ARGS = dict(
    account=os.environ["SNOWFLAKE_ACCOUNT"],  # e.g. orgname-accountname
    user=os.environ.get("SNOWFLAKE_USER", "dbt_svc_user"),
    role=os.environ.get("SNOWFLAKE_ROLE", "DBT_ROLE"),
    warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "ZOMATO_WH"),
    database=os.environ.get("SNOWFLAKE_DATABASE", "ZOMATO"),
)
KEY_PATH = os.path.expanduser(
    os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH", "~/.ssh/rsa_key.pem")
)


# --- The allowed answers. Constraining the LLM to these is what makes its
# --- output usable as clean columns instead of free-form text.
class Sentiment(str, enum.Enum):
    positive = "positive"
    neutral = "neutral"
    negative = "negative"


class Topic(str, enum.Enum):
    food_quality = "food_quality"
    delivery_speed = "delivery_speed"
    delivery_partner = "delivery_partner"
    packaging = "packaging"
    price_value = "price_value"
    overall_experience = "overall_experience"
    other = "other"


class Result(BaseModel):
    id: int
    sentiment: Sentiment
    topic: Topic


PROMPT = """You classify customer reviews for a food-delivery app.
For EACH numbered review, return its id, its sentiment (positive, neutral or
negative) and its topic.

The topic is the MAIN subject of the review:
- food_quality: taste, freshness, temperature, portion, oiliness
- delivery_speed: how fast or late the delivery was
- delivery_partner: the rider's behaviour
- packaging: packaging, spills, bags
- price_value: price or value for money
- overall_experience: a general comment not about one specific aspect
- other: none of the above
If a review mentions several aspects, choose the main one (the first if unclear).
Return exactly one result per review, using the same ids.

Reviews:
{items}
"""


def snowflake_connection():
    """Key-pair auth, same idea as dbt: the private key never leaves this machine."""
    with open(KEY_PATH, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)
    der = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return snowflake.connector.connect(private_key=der, **SNOWFLAKE_ARGS)


def classify_batch(client, comments):
    """Send one batch to the LLM. Returns {index_in_batch: Result}. Retries a few times."""
    items = "\n".join(f"{i}. {c}" for i, c in enumerate(comments))
    config = types.GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=list[Result],
        temperature=0,  # classification should be repeatable, not creative
    )
    for attempt in range(1, 4):
        try:
            resp = client.models.generate_content(
                model=MODEL, contents=PROMPT.format(items=items), config=config
            )
            results = [Result.model_validate(d) for d in json.loads(resp.text)]
            return {r.id: r for r in results}
        except Exception as e:  # rate limit, network blip, malformed JSON
            print(f"  attempt {attempt} failed: {type(e).__name__}: {e}")
            time.sleep(5 * attempt)
    raise RuntimeError("LLM batch failed after 3 attempts")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None, help="only score N comments")
    parser.add_argument("--dry-run", action="store_true", help="print results, write nothing")
    args = parser.parse_args()

    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    conn = snowflake_connection()
    cur = conn.cursor()

    cur.execute(
        "select distinct comment from ZOMATO.STAGING.STG_REVIEWS "
        "where comment is not null order by comment"
    )
    comments = [row[0] for row in cur.fetchall()]
    if args.limit:
        comments = comments[: args.limit]
    print(f"{len(comments)} distinct comments to score with {MODEL}")

    rows = []
    for start in range(0, len(comments), BATCH_SIZE):
        batch = comments[start : start + BATCH_SIZE]
        print(f"batch {start // BATCH_SIZE + 1}: {len(batch)} comments")
        results = classify_batch(client, batch)
        for i, comment in enumerate(batch):
            r = results.get(i)
            if r is None:
                print(f"  WARNING: no result for: {comment!r}")
                continue
            rows.append((comment, r.sentiment.value, r.topic.value, MODEL))
        time.sleep(2)  # stay well under free-tier rate limits

    print("\nsentiment:", dict(Counter(r[1] for r in rows)))
    print("topic:    ", dict(Counter(r[2] for r in rows)))
    print("\nsample:")
    for comment, sentiment, topic, _ in rows[:8]:
        print(f"  [{sentiment:8}|{topic:18}] {comment}")

    if args.dry_run:
        print("\n--dry-run: nothing written to Snowflake.")
        return

    cur.execute(
        "create or replace table ZOMATO.AI.COMMENT_ENRICHMENT ("
        " comment varchar, sentiment varchar, topic varchar, model varchar,"
        " enriched_at timestamp_ntz default current_timestamp())"
    )
    cur.executemany(
        "insert into ZOMATO.AI.COMMENT_ENRICHMENT (comment, sentiment, topic, model) "
        "values (%s, %s, %s, %s)",
        rows,
    )
    print(f"\nwrote {len(rows)} rows to ZOMATO.AI.COMMENT_ENRICHMENT")
    conn.close()


if __name__ == "__main__":
    main()
