-- Customer details for analysts and compliance.
--
-- IMPORTANT: This must stay a VIEW.
-- Masking happens when someone QUERIES the data, based on their role.
-- If this were a TABLE, dbt (which sees masked values) would save the
-- masked text permanently, and even Compliance could never see real data.

{{
    config(
        materialized = 'view'
    )
}}

SELECT
    c.customer_id,
    c.full_name,
    c.phone,
    c.aadhaar_number,
    c.occupation,
    c.onboarded_date,
    c.group_id,
    c.branch_id,
    b.branch_name,
    b.district,
    b.state

FROM {{ ref('stg_customers') }} c

LEFT JOIN {{ ref('stg_branches') }} b
    ON c.branch_id = b.branch_id