"""
Text-to-SQL: ask a question in plain English, get the answer from Snowflake.

How it works:
  1. We send the LLM your question plus a short description of the tables and
     columns it is allowed to use. The LLM never sees any row of data.
  2. The LLM replies with ONE SQL query.
  3. We check the query is a harmless SELECT, run it in Snowflake, and print the
     SQL (so you can verify it) and the result.

The LLM writes the query; Snowflake does the counting. That is why the numbers
are real and not invented by the model.

Usage:
  export GEMINI_API_KEY=...
  python ask.py "How many restaurants got bad reviews today, and which ones?"
  python ask.py            # interactive: type questions, empty line to quit
"""

import json
import os
import re
import sys

from google import genai
from google.genai import types
from pydantic import BaseModel

from enrich_reviews import MODEL, snowflake_connection

MAX_ROWS = 50

# Only these tables and columns are described to the LLM. What the model is not
# told about (for example customer emails and incomes) it cannot query, so
# describing the schema is also a simple form of access control.
SCHEMA = """
Table ZOMATO.AI.FCT_REVIEW_ENRICHED  (one row per customer review, 300,000 rows)
  review_id, order_id, customer_id, restaurant_id, restaurant_city,
  rating (1-5 stars), review_date (DATE), comment (text),
  sentiment ('positive'|'neutral'|'negative', assigned by an LLM),
  topic ('food_quality'|'delivery_speed'|'delivery_partner'|'packaging'|
         'price_value'|'overall_experience'|'other'),
  is_negative (BOOLEAN, true when sentiment = 'negative')

Table ZOMATO.MARTS.DIM_RESTAURANTS  (one row per restaurant)
  restaurant_id, restaurant_name, city, rating, rating_count,
  cost_for_two, cuisine

Table ZOMATO.MARTS.FCT_ORDERS  (one row per order, 10 million rows)
  order_id, order_timestamp, order_date (DATE), customer_id, restaurant_id,
  city, cuisine, items_count, sales_amount, payment_method,
  order_status ('Delivered'|'Cancelled'|'Refunded'), is_delivered,
  is_cancelled, customer_rating, delivery_time_min

Table ZOMATO.MARTS.DIM_CUSTOMER  (one row per customer)
  customer_id, customer_name, age_segment, gender

Join keys: restaurant_id joins reviews/orders to DIM_RESTAURANTS;
customer_id joins to DIM_CUSTOMER; order_id joins reviews to orders.
"""

PROMPT = """You are a Snowflake SQL expert. Write ONE read-only SELECT query that
answers the question, using only the tables and columns below.

{schema}

Rules:
- Return a single SELECT (a WITH ... SELECT is fine). No comments, no semicolon.
- Always use the full table names shown above (ZOMATO.<schema>.<table>).
- "today" means {today}. This is a static historical dataset, so today's real
  date has no data; treat {today} as the current date.
- A "bad review" means is_negative = true in ZOMATO.AI.FCT_REVIEW_ENRICHED.
- When the question asks for restaurants, join DIM_RESTAURANTS and return
  restaurant_name, not just restaurant_id.
- If the question asks "how many ... and which", return the list with a count
  per restaurant.

Question: {question}
"""

FORBIDDEN = re.compile(
    r"\b(insert|update|delete|drop|create|alter|merge|truncate|grant|revoke|copy|call)\b",
    re.IGNORECASE,
)


class SqlAnswer(BaseModel):
    sql: str


def check_sql(sql):
    """Refuse anything that is not a plain single SELECT. Returns the cleaned SQL."""
    cleaned = sql.strip().rstrip(";").strip()
    if ";" in cleaned:
        raise ValueError("more than one statement")
    if not re.match(r"(?is)^(select|with)\b", cleaned):
        raise ValueError("query must start with SELECT or WITH")
    hit = FORBIDDEN.search(cleaned)
    if hit:
        raise ValueError(f"forbidden keyword: {hit.group(0)}")
    return cleaned


def generate_sql(client, question, today):
    config = types.GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=SqlAnswer,
        temperature=0,
    )
    resp = client.models.generate_content(
        model=MODEL,
        contents=PROMPT.format(schema=SCHEMA, today=today, question=question),
        config=config,
    )
    return SqlAnswer.model_validate(json.loads(resp.text)).sql


def print_table(columns, rows):
    widths = [
        max(len(str(c)), *(len(str(r[i])) for r in rows)) if rows else len(str(c))
        for i, c in enumerate(columns)
    ]
    print("  " + " | ".join(str(c).ljust(w) for c, w in zip(columns, widths)))
    print("  " + "-+-".join("-" * w for w in widths))
    for r in rows:
        print("  " + " | ".join(str(v).ljust(w) for v, w in zip(r, widths)))


def answer(client, cur, question, today):
    print(f"\nQuestion: {question}")
    sql = generate_sql(client, question, today)
    print(f"\nGenerated SQL:\n{sql}\n")
    try:
        sql = check_sql(sql)
    except ValueError as e:
        print(f"REFUSED to run this query: {e}")
        return
    cur.execute(sql)
    columns = [d[0] for d in cur.description]
    rows = cur.fetchmany(MAX_ROWS + 1)
    print_table(columns, rows[:MAX_ROWS])
    if len(rows) > MAX_ROWS:
        print(f"  ... showing the first {MAX_ROWS} rows only")
    print(f"  ({min(len(rows), MAX_ROWS)} row(s) shown)")


def main():
    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    conn = snowflake_connection()
    cur = conn.cursor()

    cur.execute("select max(review_date) from ZOMATO.AI.FCT_REVIEW_ENRICHED")
    today = cur.fetchone()[0]
    print(f"model: {MODEL} | 'today' = latest review date in the data: {today}")

    if len(sys.argv) > 1:
        answer(client, cur, " ".join(sys.argv[1:]), today)
    else:
        while True:
            question = input("\nAsk a question (empty line to quit): ").strip()
            if not question:
                break
            answer(client, cur, question, today)
    conn.close()


if __name__ == "__main__":
    main()
