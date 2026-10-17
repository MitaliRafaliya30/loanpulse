-- Snapshots must never contain PII columns.
-- dbt sees masked values, so a PII snapshot would store masked text forever.
-- A test passes when this query returns zero rows.

SELECT
    table_name,
    column_name
FROM {{ target.database }}.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SNAPSHOTS'
  AND column_name IN ('FULL_NAME', 'PHONE', 'AADHAAR_NUMBER')
