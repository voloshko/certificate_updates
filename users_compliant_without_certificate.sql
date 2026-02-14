WITH latest_app AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        app_version,
        ts
    FROM app_util_info
    WHERE app_version IS NOT NULL
    ORDER BY user_id, ts DESC NULLS LAST
),
versioned AS (
    SELECT
        u.id AS user_id,
        u.common_id,
        c.name AS country,
        u.firmware_version,
        la.app_version,
        (COALESCE(NULLIF(split_part(la.app_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 4), ''), '0')::bigint) AS app_val,
        (COALESCE(NULLIF(split_part(u.firmware_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(u.firmware_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(u.firmware_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(u.firmware_version, '.', 4), ''), '0')::bigint) AS fw_val,
        COALESCE(NULLIF(split_part(u.firmware_version, '.', 1), ''), '0')::int AS fw_major
    FROM latest_app la
    JOIN users u ON u.id = la.user_id AND u.delete_date IS NULL
    LEFT JOIN country c ON c.id = u.country_id
),
compliance AS (
    SELECT
        v.user_id,
        v.common_id,
        v.country,
        v.app_version,
        v.firmware_version,
        COALESCE(v.app_val, 0::bigint) >= 6003002000::bigint AS app_meeting,
        (
            (v.fw_major = 3 AND v.fw_val >= 3005000003::bigint) OR
            (v.fw_major = 2 AND v.fw_val >= 2005000003::bigint)
        ) AS firmware_meeting
    FROM versioned v
),
uncertified AS (
    SELECT DISTINCT user_id
    FROM user_certificates
)
SELECT
    c.user_id,
    c.common_id,
    c.country,
    c.app_version,
    c.firmware_version,
    'yes' AS has_no_certificate,
    c.app_meeting,
    c.firmware_meeting
FROM compliance c
LEFT JOIN uncertified uc ON uc.user_id = c.user_id
WHERE uc.user_id IS NULL
  AND c.app_meeting
  AND c.firmware_meeting;
