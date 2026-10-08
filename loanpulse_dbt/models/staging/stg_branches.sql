select
    branch_id,
    branch_name,
    district,
    state,
    opened_date
from {{ source('raw', 'branches') }}