-- Gold mart: per-restaurant performance — orders, revenue, average customer
-- rating, and average delivery time. This is the table a restaurant-ops
-- team would actually query.
select
    r.restaurant_id,
    r.restaurant_name,
    r.city,
    r.cuisine,
    count(o.order_id)                                          as total_orders,
    round(sum(case when o.is_delivered then o.sales_amount else 0 end), 2) as total_revenue,
    round(avg(o.customer_rating), 2)                           as avg_customer_rating,
    round(avg(o.delivery_time_min), 1)                         as avg_delivery_minutes
from {{ ref('dim_restaurants') }} r
left join {{ ref('fct_orders') }} o on r.restaurant_id = o.restaurant_id
group by 1, 2, 3, 4
