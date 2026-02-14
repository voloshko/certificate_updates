# Certificate Updates Toolkit

SQL snippets supporting certificate-compliance analytics. Each query targets a different reporting slice so the results can feed Looker Studio dashboards or CSV exports.

## Available Queries

| File | Purpose |
| --- | --- |
| `users_non_compliant_versions.sql` | Active users whose latest app (`app_util_info`) or firmware release falls short of the required versions and includes country + compliance flags. |
| `users_compliant_without_certificate.sql` | Users who satisfy both version requirements but have **no** entry in `user_certificates`; includes `has_no_certificate='yes'`. |
| `certificate_updates_daily_counts.sql` | Parameterized daily counts of new certificates within an optional date window (defaults to the last 30 days). |
| `certificate_updates_histogram.sql` | Simple histogram of certificate issues from `2025-11-24` forward for charting. |
| `users_with_cert_by_country_with_total.sql` | Country rollup (Germany/Austria/Switzerland consolidated) of certified users with an appended `Total` row. |

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

Ensure the warehouse snapshot contains those tables before running the scripts.

## Extending

Add new SQL files alongside the existing ones; keep formatting consistent and document intent in this README so future automation agents know where to start.
