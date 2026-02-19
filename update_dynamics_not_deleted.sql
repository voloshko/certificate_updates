-- Daily certificate progress for all not-deleted users
-- For Looker Studio visualization:
-- - Line chart: cumulative users with/without certificates
-- - Histogram: daily new certificate updates

-- CONFIG: Edit start_date below to change data range
WITH config AS (
    SELECT '2026-01-01'::date AS start_date
),
all_users AS (
    -- All not-deleted users
    SELECT DISTINCT
        u.id AS user_id,
        c.name AS country
    FROM users u
    LEFT JOIN country c ON c.id = u.country_id
    WHERE u.delete_date IS NULL
),
certificate_dates AS (
    -- Get the date each user got their certificate (if any)
    SELECT
        au.user_id,
        DATE(uc.created_at)::date AS cert_date
    FROM all_users au
    LEFT JOIN user_certificates uc ON uc.user_id = au.user_id
),
daily_signups AS (
    -- Count new certificates per day (from config start_date)
    SELECT
        cert_date AS date,
        COUNT(*) AS new_certificates
    FROM certificate_dates
    WHERE cert_date IS NOT NULL
      AND cert_date >= (SELECT start_date FROM config)
    GROUP BY cert_date
),
date_series AS (
    -- Generate all dates from config start_date to today
    SELECT (SELECT start_date FROM config) + (n || ' days')::interval AS date
    FROM generate_series(0, CURRENT_DATE - (SELECT start_date FROM config)) AS n
),
cumulative_stats AS (
    -- Calculate cumulative stats for each day
    SELECT
        d.date::date AS date,
        COALESCE(ds.new_certificates, 0) AS new_certificates,
        (
            SELECT COUNT(*)
            FROM certificate_dates
            WHERE cert_date IS NOT NULL
              AND cert_date <= d.date
        ) AS cumulative_with_certificate,
        (
            SELECT COUNT(*)
            FROM all_users
        ) - (
            SELECT COUNT(*)
            FROM certificate_dates
            WHERE cert_date IS NOT NULL
              AND cert_date <= d.date
        ) AS cumulative_without_certificate
    FROM date_series d
    LEFT JOIN daily_signups ds ON ds.date = d.date::date
)
SELECT *
FROM cumulative_stats
ORDER BY date;
