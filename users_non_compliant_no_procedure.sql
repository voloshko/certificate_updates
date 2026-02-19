-- Find users with non-compliant app or firmware versions (OPTIMIZED - no procedure count)
-- Extended with: user_type, last measurement date, device number
-- Removed procedure_count for better performance

-- CONFIG: Edit minimum versions here
WITH config AS (
    SELECT
        '6.3.2'::text AS min_app_version,
        '2.5.3'::text AS min_firmware_v2_version,
        '3.5.3'::text AS min_firmware_v3_version,
        -- Pre-calculate version numbers (done once, not per row)
        (COALESCE(NULLIF(split_part('6.3.2', '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part('6.3.2', '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part('6.3.2', '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part('6.3.2', '.', 4), ''), '0')::bigint) AS min_app_val,
        (COALESCE(NULLIF(split_part('2.5.3', '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part('2.5.3', '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part('2.5.3', '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part('2.5.3', '.', 4), ''), '0')::bigint) AS min_fw_v2_val,
        (COALESCE(NULLIF(split_part('3.5.3', '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part('3.5.3', '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part('3.5.3', '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part('3.5.3', '.', 4), ''), '0')::bigint) AS min_fw_v3_val
),
-- Get latest app info with device type in one pass
latest_app AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        app_version,
        CASE
            WHEN os ILIKE '%ios%' OR os ILIKE '%apple%' THEN 'iOS'
            WHEN os ILIKE '%android%' THEN 'Android'
            ELSE 'Unknown'
        END AS device_type
    FROM app_util_info
    WHERE app_version ~ '^[0-9]+(\.[0-9]+)*$'
    ORDER BY user_id, ts DESC NULLS LAST
),
-- Get device numbers
user_device AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        device_number
    FROM device
    WHERE device_number IS NOT NULL
    ORDER BY user_id, update_ts DESC NULLS LAST
),
-- Precise user type classification using window functions
user_type_map AS (
    SELECT
        user_id,
        user_type
    FROM (
        SELECT
            u.id AS user_id,
            CASE
                WHEN u.common_id IS NULL OR u.common_id::text = '' THEN 'SingleUser'
                WHEN ROW_NUMBER() OVER (PARTITION BY NULLIF(u.common_id::text, '') ORDER BY u.id) = 1 THEN 'MainUser'
                WHEN ROW_NUMBER() OVER (PARTITION BY NULLIF(u.common_id::text, '') ORDER BY u.id) = 2 THEN '2ndUser'
                ELSE 'Other'
            END AS user_type
        FROM users u
        WHERE u.delete_date IS NULL
    ) classified
)
SELECT
    v.user_id,
    v.common_id,
    v.country,
    v.app_version,
    v.firmware_version,
    v.device_type,
    ud.device_number,
    ut.user_type,
    v.app_val < c.min_app_val AS app_not_meeting,
    NOT ((v.fw_major = 3 AND v.fw_val >= c.min_fw_v3_val) OR (v.fw_major = 2 AND v.fw_val >= c.min_fw_v2_val)) AS firmware_not_meeting
FROM (
    SELECT
        u.id AS user_id,
        u.common_id,
        c.name AS country,
        u.firmware_version,
        la.app_version,
        la.device_type,
        (COALESCE(NULLIF(split_part(la.app_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 4), ''), '0')::bigint) AS app_val,
        (COALESCE(NULLIF(split_part(COALESCE(u.firmware_version, '0'), '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(COALESCE(u.firmware_version, '0'), '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(COALESCE(u.firmware_version, '0'), '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(COALESCE(u.firmware_version, '0'), '.', 4), ''), '0')::bigint) AS fw_val,
        COALESCE(NULLIF(split_part(COALESCE(u.firmware_version, '0'), '.', 1), ''), '0')::int AS fw_major
    FROM latest_app la
    JOIN users u ON u.id = la.user_id AND u.delete_date IS NULL
    LEFT JOIN country c ON c.id = u.country_id
) v
CROSS JOIN config c
LEFT JOIN user_device ud ON ud.user_id = v.user_id
LEFT JOIN user_type_map ut ON ut.user_id = v.user_id
WHERE v.app_val < c.min_app_val
   OR NOT (
       (v.fw_major = 3 AND v.fw_val >= c.min_fw_v3_val) OR
       (v.fw_major = 2 AND v.fw_val >= c.min_fw_v2_val)
   )
ORDER BY v.user_id;
