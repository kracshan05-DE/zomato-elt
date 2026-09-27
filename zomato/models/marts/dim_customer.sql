-- Gold: customer dimension, enriched with an analytics-friendly age
-- segment. This is a Gold-layer decision, not a Silver one: age_segment
-- is a business categorisation for reporting, not a data-quality fix —
-- Silver stays faithful to the source, Gold adds business meaning.
select
    customer_id,
    customer_name,
    email,
    age,
    case
        when age is null then 'Unknown'
        when age < 25 then 'Gen Z'
        when age < 40 then 'Millennial'
        when age < 55 then 'Gen X'
        else 'Boomer'
    end as age_segment,
    gender,
    marital_status,
    occupation,
    monthly_income,
    education,
    family_size
from {{ ref('stg_users') }}
