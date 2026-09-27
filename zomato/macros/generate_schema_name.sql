{#
  dbt's default behaviour concatenates target_schema_custom_schema
  (e.g. "STAGING_marts"). We override it so a model's custom schema
  config is used exactly as given — STAGING, MARTS, SNAPSHOTS, AI —
  which is what dbt_project.yml's +schema settings expect.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
