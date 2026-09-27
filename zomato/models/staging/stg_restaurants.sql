-- Silver: restaurant dimension, cleaned from messy TEXT source columns.
-- Source quirks handled here (all confirmed against real loaded data):
--   RATING        '--' for no rating, else a decimal string like '4.4'
--   RATING_COUNT  free text like '50+ ratings' or 'Too Few Ratings'
--   COST          currency-prefixed string like '₹ 200'
--   ID            numeric value stored as TEXT — cast to match the NUMBER
--                 restaurant-id columns in the fact tables (orders, reviews)
with source as (
    select * from {{ source('raw', 'restaurants') }}
)

select
    try_to_number(trim(id))                                    as restaurant_id,
    trim(name)                                                 as restaurant_name,
    trim(city)                                                 as city,
    try_to_decimal(regexp_substr(rating, '[0-9]+\\.?[0-9]*'), 10, 2)   as rating,
    try_to_number(regexp_substr(rating_count, '[0-9]+'))       as rating_count,
    try_to_number(regexp_substr(cost, '[0-9]+'))               as cost_for_two,
    trim(cuisine)                                              as cuisine,
    trim(lic_no)                                                as license_number,
    trim(link)                                                  as restaurant_link,
    trim(address)                                               as address
from source
where id is not null
