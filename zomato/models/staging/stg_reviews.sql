-- Silver: reviews, enriched with the restaurant's city via a ref() join —
-- this is dbt's dependency graph in action: stg_reviews depends on
-- stg_restaurants, not on raw.restaurants directly, so cleanup logic
-- lives in exactly one place.
with reviews as (
    select * from {{ source('raw', 'reviews') }}
),

restaurants as (
    select * from {{ ref('stg_restaurants') }}
)

select
    r.review_id,
    r.order_id,
    r.user_id as customer_id,
    r.restaurant_id,
    r.rating,
    r.comment,
    r.review_date,
    s.city as restaurant_city
from reviews r
left join restaurants s on r.restaurant_id = s.restaurant_id
where r.review_id is not null
