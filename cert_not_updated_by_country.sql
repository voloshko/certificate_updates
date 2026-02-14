WITH certless_users AS (
    SELECT
        u.id AS user_id,
        u.common_id,
        CASE
            WHEN c.name IN ('Germany', 'Austria', 'Switzerland') THEN 'Germany + Austria + Switzerland'
            ELSE c.name
        END AS reporting_country
    FROM users u
    LEFT JOIN country c ON c.id = u.country_id
    LEFT JOIN user_certificates uc ON uc.user_id = u.id
    WHERE uc.user_id IS NULL
      AND u.delete_date IS NULL
)
SELECT
    reporting_country AS country,
    COUNT(*) AS users_without_certificate
FROM certless_users
GROUP BY reporting_country
ORDER BY users_without_certificate DESC;
