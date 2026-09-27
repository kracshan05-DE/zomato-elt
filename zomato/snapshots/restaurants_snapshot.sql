{#
  SCD Type 2 history for the restaurant dimension via dbt's native snapshot
  feature. This is the declarative equivalent of the four-DataFrame CDC
  pattern (insert/update/reactive/delete via hash comparison) you'd hand-code
  in PySpark for a Fabric Silver layer — dbt's snapshot strategy does the
  same job: detect a changed row (via check_cols, dbt's equivalent of a
  content hash), close out the old version (dbt_valid_to), insert a new
  version (dbt_valid_from = now). No SHA256 hash column to maintain by
  hand — dbt computes the equivalent comparison internally.

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
