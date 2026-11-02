-- Grille tarifaire (nouveau modèle) : prix d'un établissement selon son nombre d'employés facturables.
-- Isolée en macro pour être testée seule contre les exemples de l'énoncé (tests/assert_pricing_grid.sql).

{% macro location_size(n) -%}
    CASE
        WHEN {{ n }} <= 5  THEN 'micro'
        WHEN {{ n }} <= 39 THEN 'small'
        ELSE 'large'
    END
{%- endmacro %}

{% macro location_price(n) -%}
    CASE
        WHEN {{ n }} <= 5  THEN 60
        WHEN {{ n }} <= 39 THEN 80 + ({{ n }} - 6) * 4
        ELSE 216 + 33 * 4 + ({{ n }} - 39) * 2.4
    END
{%- endmacro %}
