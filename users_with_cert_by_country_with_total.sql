WITH certified_users AS (
    SELECT DISTINCT
        u.id AS user_id,
        CASE
            WHEN c.name IN ('Germany', 'Austria', 'Switzerland') THEN 'Germany'
            ELSE c.name
        END AS reporting_country
    FROM users u
    JOIN user_certificates uc ON uc.user_id = u.id
    LEFT JOIN country c ON c.id = u.country_id
    WHERE u.delete_date IS NULL
),
aggregated AS (
    SELECT
        reporting_country AS country,
        COUNT(*) AS users_with_certificate
    FROM certified_users
    GROUP BY reporting_country
)
SELECT
    country,
    users_with_certificate
FROM (
    SELECT
        country,
        users_with_certificate,
        0 AS sort_order
    FROM aggregated
    UNION ALL
    SELECT
        'Total' AS country,
        SUM(users_with_certificate) AS users_with_certificate,
        1 AS sort_order
    FROM aggregated
) ranked
ORDER BY sort_order, users_with_certificate DESC;
