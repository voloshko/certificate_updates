# Certificate Updates Toolkit

SQL snippets supporting certificate-compliance analytics. Each query targets a different reporting slice so the results can feed Looker Studio dashboards or CSV exports.

## Available Queries

### Certificate Status by Country

| File | Purpose |
| --- | --- |
| `cert_status_by_country.sql` | Certificate status by country for all not-deleted users. Groups Germany/Austria/Switzerland as "Germany". |
| `cert_status_by_country_acitve_users.sql` | Certificate status by country for active users (measurements in last 30 days). |

### Non-Compliant Users

| File | Purpose |
| --- | --- |
| `users_non_compliant_versions.sql` | Users whose latest app or firmware falls short of required versions. Includes country + compliance flags. |
| `users_non_compliant_more_numbers.sql` | Extended version with user_type, device_type, device_number, last_measurement_date, procedure_count. |
| `users_non_compliant_no_procedure.sql` | Optimized version without expensive procedure_count and last_measurement_date (fastest). |
| `users_compliant_without_certificate.sql` | Users who satisfy version requirements but have **no** entry in `user_certificates`. |

### Daily Progress & Dynamics

| File | Purpose |
| --- | --- |
| `update_dynamics.sql` | Daily progress for active users (rolling 30-day window). For Looker Studio: cumulative stats + new certificates per day. |
| `update_dynamics_not_deleted.sql` | Daily progress for all not-deleted users. Same as above but without activity filter. |
| `certificate_updates_daily_counts.sql` | Parameterized daily counts within an optional date window (defaults to last 30 days). |
| `certificate_updates_histogram.sql` | Simple histogram of certificate issues from `2025-11-24` forward. |
| `users_with_cert_by_country_with_total.sql` | Country rollup (Germany/Austria/Switzerland consolidated) with `Total` row. |

## Running the Queries

All snippets are plain SQL and can be executed with `psql`, DBeaver, or any Postgres-compatible client pointed at the production replica.

```bash
# Example: fetch non-compliant versions and export to CSV
psql "$CERT_DB_URL" -f users_non_compliant_versions.sql > users_non_compliant_versions.csv
```

### Parameter placeholders

`certificate_updates_daily_counts.sql` uses optional bound parameters:

- `:start_date` – inclusive `DATE` (empty/`0` defaults to 30 days ago)
- `:end_date` – inclusive `DATE` (empty/`0` defaults to today)

Example with `psql` using `
\set start_date '2025-01-01'
\set end_date '2025-02-01'
\i certificate_updates_daily_counts.sql
```

## Data Sources

- `users`, `country`, `user_certificates`: core certification data
- `app_util_info`: latest reported app versions (`ts` timestamp)
- `measures`, `photo_metadata`: measurement data for active user detection
- `device`: device information (`device_number`)

### Configuration

Some queries have a `config` CTE at the top for easy parameter editing:
- **Minimum versions** (`users_non_compliant_*.sql`): `min_app_version`, `min_firmware_v2_version`, `min_firmware_v3_version`
- **Date range** (`update_dynamics*.sql`): `start_date` for cumulative stats calculation

## Extending

Add new SQL files alongside the existing ones; keep formatting consistent and document intent in this README so future automation agents know where to start.
