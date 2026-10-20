-- One row per branch: the LATEST version.
-- RAW is append-only and keeps every version of a branch that ever arrived.

select
    branch_id,
    branch_name,
    district,
    state,
    opened_date
from {{ source('raw', 'branches') }}
qualify row_number() over (
    partition by branch_id
    order by _loaded_at desc, _source_file desc
) = 1
