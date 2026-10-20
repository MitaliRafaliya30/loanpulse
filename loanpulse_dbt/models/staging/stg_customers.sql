-- One row per customer: the LATEST version.
-- RAW is append-only and keeps every version of a customer that ever arrived.

select
    customer_id,
    full_name,
    phone,
    aadhaar_number,
    group_id,
    branch_id,
    occupation,
    onboarded_date
from {{ source('raw', 'customers') }}
qualify row_number() over (
    partition by customer_id
    order by _loaded_at desc, _source_file desc
) = 1
