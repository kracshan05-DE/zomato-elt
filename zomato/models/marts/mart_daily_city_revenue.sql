-- Gold mart: daily revenue, cancellation rate, and average order value by
-- city. One row per (order_date, city) — this is the grain the business
-- question ("how did Colombo do yesterday?") actually asks at.
select
    order_date,
    city,
    count(*)                                                  as total_orders,
    count_if(is_delivered)                                    as delivered_orders,
    count_if(is_cancelled)                                    as cancelled_orders,
    round(count_if(is_cancelled) / nullif(count(*), 0), 4)    as cancel_rate,
    round(sum(case when is_delivered then sales_amount else 0 end), 2) as gmv,
    round(
        sum(case when is_delivered then sales_amount else 0 end)
        / nullif(count_if(is_delivered), 0), 2
    )                                                          as avg_order_value
from {{ ref('fct_orders') }}
group by 1, 2
