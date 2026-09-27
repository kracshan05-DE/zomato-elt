-- Gold mart: delivery SLA by city — median (p50) and worst-case (p90)
-- delivery time. p90 matters more than the average here: it tells ops
-- how bad the slow tail is, which is what actually drives complaints.
select
    city,
    count(*)                                                                as delivered_order_count,
    round(avg(delivery_time_min), 1)                                        as avg_delivery_minutes,
    round(percentile_cont(0.5) within group (order by delivery_time_min), 1) as p50_delivery_minutes,
    round(percentile_cont(0.9) within group (order by delivery_time_min), 1) as p90_delivery_minutes
from {{ ref('fct_orders') }}
where is_delivered
group by 1
