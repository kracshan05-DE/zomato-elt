-- Silver: order-level fact. Already well-typed at RAW.
-- ORDER_STATUS confirmed (2026-09-27, real data): 'Delivered' (9,150,122),
-- 'Cancelled' (599,251), 'Refunded' (250,627) — exact casing verified by
-- query, not assumed.
with source as (
    select * from {{ source('raw', 'orders') }}
)

select
    order_id,
    order_timestamp,
    order_date,
    user_id as customer_id,
    r_id as restaurant_id,
    restaurant_city as city,
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
    (order_status = 'Delivered') as is_delivered,
    (order_status = 'Cancelled') as is_cancelled,
    customer_rating,
    delivery_time_min
from source
where order_id is not null
