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
