-- Gold: generated date dimension spanning the order history's date range
-- plus a safety margin, so joins against fct_orders.order_date never miss
-- a row at the edges of the range.
with date_spine as (
    select
        dateadd(day, seq4(), '2023-01-01'::date) as date_day
    from table(generator(rowcount => 1500))
)

select
    date_day,
    year(date_day)          as year,
    month(date_day)         as month,
    day(date_day)           as day,
    dayofweek(date_day)     as day_of_week,
    dayname(date_day)       as day_name,
    monthname(date_day)     as month_name,
    (dayofweek(date_day) in (0, 6)) as is_weekend
from date_spine
