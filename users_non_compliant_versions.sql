-- Find users with non-compliant app or firmware versions

-- CONFIG: Edit minimum versions here
WITH config AS (
    SELECT
        '6.3.2'::text AS min_app_version,
        '2.5.3'::text AS min_firmware_v2_version,
        '3.5.3'::text AS min_firmware_v3_version
),
-- Helper: Convert version string "X.Y.Z" to comparable number
-- Example: "6.3.2" -> 6003002000, "2.5.3" -> 2005003000
version_number AS (
    SELECT
        major * 1000000000::bigint +
        minor * 1000000::bigint +
        patch * 1000::bigint +
        build * 1::bigint AS val,
        major AS major_val
    FROM (
        SELECT
            COALESCE(NULLIF(split_part(ver, '.', 1), ''), '0')::int AS major,
            COALESCE(NULLIF(split_part(ver, '.', 2), ''), '0')::int AS minor,
            COALESCE(NULLIF(split_part(ver, '.', 3), ''), '0')::int AS patch,
            COALESCE(NULLIF(split_part(ver, '.', 4), ''), '0')::int AS build
        FROM (VALUES ('6.3.2')) AS v(ver)  -- placeholder, replaced below
    ) t
),
latest_app AS (
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
        -- Convert app version "X.Y.Z" -> number (e.g., "6.3.2" -> 6003002000)
        (COALESCE(NULLIF(split_part(la.app_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(la.app_version, '.', 4), ''), '0')::bigint) AS app_val,
        -- Convert firmware version "X.Y.Z" -> number (e.g., "3.5.3" -> 3005003000)
        (COALESCE(NULLIF(split_part(u.firmware_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(u.firmware_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(u.firmware_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(u.firmware_version, '.', 4), ''), '0')::bigint) AS fw_val,
        COALESCE(NULLIF(split_part(u.firmware_version, '.', 1), ''), '0')::int AS fw_major
    FROM latest_app la
    JOIN users u ON u.id = la.user_id AND u.delete_date IS NULL
    LEFT JOIN country c ON c.id = u.country_id
),
min_versions AS (
    -- Convert config version strings to numbers for comparison
    SELECT
        (COALESCE(NULLIF(split_part(min_app_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(min_app_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(min_app_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(min_app_version, '.', 4), ''), '0')::bigint) AS min_app_val,
        (COALESCE(NULLIF(split_part(min_firmware_v2_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(min_firmware_v2_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(min_firmware_v2_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(min_firmware_v2_version, '.', 4), ''), '0')::bigint) AS min_fw_v2_val,
        (COALESCE(NULLIF(split_part(min_firmware_v3_version, '.', 1), ''), '0')::bigint * 1000000000::bigint +
         COALESCE(NULLIF(split_part(min_firmware_v3_version, '.', 2), ''), '0')::bigint * 1000000::bigint +
         COALESCE(NULLIF(split_part(min_firmware_v3_version, '.', 3), ''), '0')::bigint * 1000::bigint +
         COALESCE(NULLIF(split_part(min_firmware_v3_version, '.', 4), ''), '0')::bigint) AS min_fw_v3_val
    FROM config
),
evaluated AS (
    SELECT
        user_id,
        common_id,
        country,
        app_version,
        firmware_version,
        -- App version check: below minimum?
        COALESCE(app_val, 0::bigint) < (SELECT min_app_val FROM min_versions) AS app_not_meeting,
        -- Firmware check: based on major version
        NOT (
            (fw_major = 3 AND fw_val >= (SELECT min_fw_v3_val FROM min_versions)) OR
            (fw_major = 2 AND fw_val >= (SELECT min_fw_v2_val FROM min_versions))
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
