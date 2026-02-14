SELECT
  created_at::date AS date,
  COUNT(DISTINCT user_id) AS users
FROM user_certificates
GROUP BY date
ORDER BY date;
