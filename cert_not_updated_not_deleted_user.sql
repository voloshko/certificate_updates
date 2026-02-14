WITH users_without_cert AS (
    SELECT DISTINCT user_id
    FROM user_certificates
)
SELECT
    u.id AS user_id,
    u.common_id,
    c.name AS country,
    MAX(mp.procedure_date) AS last_measurement_date
FROM users u
LEFT JOIN country c ON c.id = u.country_id
LEFT JOIN measure_procedure mp ON mp.user_id = u.id
LEFT JOIN users_without_cert uc ON uc.user_id = u.id
WHERE uc.user_id IS NULL
  AND u.delete_date IS NULL
GROUP BY u.id, u.common_id, c.name
ORDER BY last_measurement_date DESC NULLS LAST;
