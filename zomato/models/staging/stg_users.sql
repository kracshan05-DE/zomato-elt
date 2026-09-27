-- Silver: customer dimension. PASSWORD column deliberately excluded — no
-- reason to carry credential-shaped data past Bronze even in a demo project.
with source as (
    select * from {{ source('raw', 'users') }}
)

select
    try_to_number(trim(user_id))                       as customer_id,
    trim(name)                                         as customer_name,
    lower(trim(email))                                 as email,
    try_to_number(regexp_substr(age, '[0-9]+'))        as age,
    trim(gender)                                       as gender,
    trim(marital_status)                               as marital_status,
    trim(occupation)                                   as occupation,
    try_to_number(regexp_substr(monthly_income, '[0-9]+')) as monthly_income,
    trim(education)                                    as education,
    try_to_number(regexp_substr(family_size, '[0-9]+')) as family_size
from source
where user_id is not null
