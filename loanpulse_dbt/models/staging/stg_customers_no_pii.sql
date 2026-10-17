-- Customer columns WITHOUT personal data, used as the source for snap_customers.
--
-- Why this exists: a dbt snapshot stores EVERY column of its source, not only
-- the tracked ones. Snapshotting stg_customers would save name, phone and
-- Aadhaar. dbt sees masked values, so the masked text would be stored forever.
-- Selecting only safe columns here keeps PII out of the history table.

SELECT
    customer_id,
    branch_id,
    group_id,
    occupation,
    onboarded_date
FROM {{ ref('stg_customers') }}
