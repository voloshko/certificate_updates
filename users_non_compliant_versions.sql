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
evaluated AS (
    SELECT
        user_id,
        common_id,
        country,
        app_version,
        firmware_version,
        COALESCE(app_val, 0::bigint) < 6003002000::bigint AS app_not_meeting,
        NOT (
            (fw_major = 3 AND fw_val >= 3005000003::bigint) OR
            (fw_major = 2 AND fw_val >= 2005000003::bigint)
        ) AS firmware_not_meeting
    FROM versioned
)
SELECT
    user_id,
    common_id,
    country,
    app_version,
    firmware_version,
    app_not_meeting,
    firmware_not_meeting
FROM evaluated
WHERE app_not_meeting OR firmware_not_meeting;
