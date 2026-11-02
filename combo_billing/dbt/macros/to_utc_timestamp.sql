-- Timestamps des CSV : '2023-06-20 14:00:00 UTC' -> TIMESTAMP_NTZ en UTC.
-- TRY_ : une valeur illisible devient NULL, attrapée par les tests not_null.

{% macro to_utc_timestamp(column_name) -%}
    TRY_TO_TIMESTAMP_NTZ(REPLACE(TRIM({{ column_name }}), ' UTC', ''))
{%- endmacro %}
