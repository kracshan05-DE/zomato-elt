-- Silver: order line items. Already well-typed at RAW; this model exists so
-- every downstream fact/mart reads from STAGING, never RAW directly — one
-- rule, no exceptions, so a future source-schema change only touches this
-- one file's mapping, not every mart built on top of it.
with source as (
    select * from {{ source('raw', 'order_items') }}
)

select
    order_item_id,
    order_id,
    r_id as restaurant_id,
    trim(f_id) as food_id,
    price,
    quantity,
    line_amount
from source
where order_item_id is not null
