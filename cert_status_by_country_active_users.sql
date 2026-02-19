WITH all_users AS (
    SELECT
        u.id AS user_id,
        CASE
            WHEN c.name IN ('Germany', 'Austria', 'Switzerland') THEN 'Germany'
            ELSE COALESCE(c.name, 'Unknown')
        END AS country,
        CASE
            WHEN uc.user_id IS NOT NULL THEN 1
            ELSE 0
        END AS has_certificate
    FROM users u
    LEFT JOIN country c ON c.id = u.country_id
    LEFT JOIN user_certificates uc ON uc.user_id = u.id
    WHERE u.delete_date IS NULL
      AND EXISTS (
          SELECT 1
          FROM measures m
          JOIN photo_metadata pm ON pm.id = m.photo_metadata_id
          WHERE pm.user_id = u.id
            AND pm.create_ts >= CURRENT_DATE - INTERVAL '30 days'
      )
),
country_stats AS (
    SELECT
        country,
        SUM(has_certificate) AS updated,
        SUM(1 - has_certificate) AS not_updated
    FROM all_users
    GROUP BY country
),
combined_results AS (
    SELECT
        country,
        updated,
        not_updated,
        updated + not_updated AS total
    FROM country_stats
    UNION ALL
    SELECT
        'Total',
        SUM(updated),
        SUM(not_updated),
        SUM(updated + not_updated)
    FROM country_stats
)
SELECT *
FROM combined_results
ORDER BY
    CASE WHEN country = 'Germany' THEN 0 ELSE 1 END,
    CASE WHEN country = 'Total' THEN 1 ELSE 0 END,
    total DESC;
