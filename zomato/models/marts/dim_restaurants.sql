-- Gold: restaurant dimension. Pass-through from Silver — all cleaning
-- already happened in stg_restaurants; Gold's job is presentation and
-- serving as a join target for facts, not re-cleaning.
select * from {{ ref('stg_restaurants') }}
