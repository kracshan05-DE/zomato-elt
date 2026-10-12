-- Gold: order-level fact, INCREMENTAL with a merge strategy.
--
-- Why incremental instead of a full table rebuild: this fact has 10M rows.
-- Rebuilding it from scratch on every dbt run means re-scanning and
-- re-writing all 10M rows even when only a few thousand new orders arrived.
-- Incremental + merge means each run only processes orders newer than the
-- latest order_timestamp already in the table.
--
-- Known limitation: the filter selects by order_timestamp, which never
-- changes. So a later update to an old order (e.g. Delivered -> Refunded)
-- is never picked up, even though MERGE could apply it. Fixing that needs a
-- column that changes when the row changes (an updated_at or a load
-- timestamp), or a lookback window. The source data has neither.
-- The filter also uses '>' where '>=' is safer (rows sharing the max
-- timestamp that arrive later would be skipped; merge would dedupe '>=').
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
