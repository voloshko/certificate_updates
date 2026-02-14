WITH parameters AS (
    SELECT
        COALESCE(NULLIF(NULLIF(:start_date::text, ''), '0')::date, (CURRENT_DATE - INTERVAL '30 days')::date) AS start_date,
        COALESCE(NULLIF(NULLIF(:end_date::text, ''), '0')::date, CURRENT_DATE) AS end_date
    ),
daily AS (
    SELECT
        uc.created_at::date AS date_only,
        uc.user_id
    FROM user_certificates uc
    CROSS JOIN parameters p
    WHERE uc.created_at::date BETWEEN p.start_date AND p.end_date
)
SELECT
    date_only AS certificate_date,
    COUNT(DISTINCT user_id) AS certificates_created
FROM daily
GROUP BY date_only
ORDER BY date_only;
