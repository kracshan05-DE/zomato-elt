-- Gold: food item dimension, joined with menu to expose which
-- restaurants sell each item at what price.
select
    f.food_id,
    f.food_name,
    f.food_type,
    m.restaurant_id,
    m.cuisine,
    m.price
from {{ ref('stg_food') }} f
left join {{ ref('stg_menu') }} m on f.food_id = m.food_id
