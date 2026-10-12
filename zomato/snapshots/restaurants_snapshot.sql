{#
  SCD Type 2 history for the restaurant dimension via dbt's native snapshot
  feature. It covers the insert and update parts of a hand-coded PySpark CDC
  pattern: detect a changed row (by comparing check_cols), close out the old
  version (dbt_valid_to), insert a new version (dbt_valid_from = now).

  Known limitation: deleted rows are not tracked. dbt's default is
  hard_deletes='ignore', so a restaurant removed from the source stays
  "current" forever. Adding hard_deletes='invalidate' (dbt 1.9+) would close
  it out. Also, the source data is static, so this snapshot has never
  actually captured a change.

  Why this dimension specifically: rating, cost_for_two, and cuisine are
  exactly the kind of slowly-changing attributes where "what was this
  restaurant's rating when this order was placed" is a legitimate business
  question — the same justification used for SCD2 on the Fabric side.
#}
{% snapshot restaurants_snapshot %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='restaurant_id',
        strategy='check',
        check_cols=['rating', 'rating_count', 'cost_for_two', 'cuisine'],
    )
}}

select * from {{ ref('stg_restaurants') }}

{% endsnapshot %}
