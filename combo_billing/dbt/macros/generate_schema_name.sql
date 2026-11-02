-- dbt concatène par défaut target.schema et le schéma custom (BRONZE_SILVER).
-- Ici le schéma porte la couche : on garde le nom exact (BRONZE, SILVER, GOLD).

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
