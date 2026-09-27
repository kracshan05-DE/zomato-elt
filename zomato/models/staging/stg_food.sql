-- Silver: food item lookup. F_ID is alphanumeric (not purely numeric) in the
-- source, matching how it's stored in menu and order_items — kept as a
-- trimmed string key throughout, never cast to NUMBER.
with source as (
    select * from {{ source('raw', 'food') }}
)

select
    trim(f_id)                       as food_id,
    trim(item)                       as food_name,
    initcap(trim(veg_or_non_veg))    as food_type
from source
where f_id is not null
