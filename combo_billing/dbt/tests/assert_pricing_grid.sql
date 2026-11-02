-- La grille doit retrouver les montants de l'énoncé et se comporter correctement aux bornes.

WITH cases (n_employees, expected_price, label) AS (
    SELECT * FROM VALUES
        (0,  60,    'micro vide'),
        (5,  60,    'Boutique Gare'),
        (6,  80,    'borne petit : 6 inclus'),
        (10, 96,    'Boutique Centre-ville'),
        (25, 156,   'Laboratoire semaine 15-21 janvier'),
        (30, 176,   'Laboratoire'),
        (39, 212,   'borne haute petit'),
        (40, 350.4, 'borne grand'),
        (50, 374.4, 'restaurant 50 employés')
)

SELECT
    label,
    n_employees,
    expected_price,
    {{ location_price('n_employees') }} AS computed_price
FROM cases
WHERE {{ location_price('n_employees') }} <> expected_price
