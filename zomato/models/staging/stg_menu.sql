-- Silver: menu bridge table (restaurant x food item x price).
-- R_ID cast to NUMBER to match dim_restaurants / fact tables.
-- F_ID kept as string to match stg_food's key type.
with source as (
    select * from {{ source('raw', 'menu') }}
)

select
    trim(menu_id)                                                  as menu_id,
    try_to_number(trim(r_id))                                      as restaurant_id,
    trim(f_id)                                                     as food_id,
    trim(cuisine)                                                  as cuisine,
    try_to_decimal(regexp_substr(price, '[0-9]+\\.?[0-9]*'), 10, 2) as price
from source
where menu_id is not null
