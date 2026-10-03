-- depends_on: {{ ref('fct_orders') }}
-- (Parse-time hint: dbt parses with is_incremental() = false, so it cannot
-- see the ref('fct_orders') inside the incremental block below. Without this
-- hint, the first run passes but every later run fails to compile.)
--
-- Gold: order line-item fact, INCREMENTAL (~23M rows — same reasoning as
-- fct_orders). order_items has no timestamp of its own, so the incremental
-- filter joins back to fct_orders (already incrementally loaded) to find
-- which order_ids are new, then only pulls line items for those orders.
{{
    config(
        materialized = 'incremental',
        unique_key = 'order_item_id',
        incremental_strategy = 'merge'
    )
}}

select
    oi.order_item_id,
    oi.order_id,
    oi.restaurant_id,
    oi.food_id,
    oi.price,
    oi.quantity,
    oi.line_amount
from {{ ref('stg_order_items') }} oi

{% if is_incremental() %}
inner join {{ ref('fct_orders') }} o
    on oi.order_id = o.order_id
   and o.order_timestamp > (
        select coalesce(max(o2.order_timestamp), '1900-01-01'::timestamp_ntz)
        from {{ this }} t
        inner join {{ ref('fct_orders') }} o2 on t.order_id = o2.order_id
   )
{% endif %}
