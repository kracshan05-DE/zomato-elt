-- Gold: order-level fact, INCREMENTAL with a merge strategy.
--
-- Why incremental instead of a full table rebuild: this fact has 10M rows.
-- Rebuilding it from scratch on every dbt run means re-scanning and
-- re-writing all 10M rows even when only a few thousand new orders arrived
-- since yesterday. Incremental + merge means each run only processes rows
-- newer than what's already in the table, and MERGE handles both new
-- inserts and late-arriving updates to existing orders (e.g. a status
-- change from Delivered to Refunded after the fact was first loaded).
{{
    config(
        materialized = 'incremental',
        unique_key = 'order_id',
        incremental_strategy = 'merge'
    )
}}

select
    order_id,
    order_timestamp,
    order_date,
    customer_id,
    restaurant_id,
    city,
    cuisine,
    items_count,
    sales_qty,
    subtotal,
    discount,
    delivery_fee,
    gst,
    sales_amount,
    currency,
    payment_method,
    order_status,
    is_delivered,
    is_cancelled,
    customer_rating,
    delivery_time_min
from {{ ref('stg_orders') }}

{% if is_incremental() %}
    where order_timestamp > (select max(order_timestamp) from {{ this }})
{% endif %}
