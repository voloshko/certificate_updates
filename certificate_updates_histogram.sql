SELECT
    created_at::date AS certificate_date,
    COUNT(DISTINCT user_id) AS certificates_created
FROM user_certificates
WHERE created_at::date >= DATE '2025-11-24'
GROUP BY certificate_date
ORDER BY certificate_date;
