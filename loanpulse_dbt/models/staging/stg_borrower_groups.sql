-- One row per borrower group: the LATEST version.
-- RAW is append-only and keeps every version of a group that ever arrived.

select
    group_id,
    branch_id,
    formed_date
from {{ source('raw', 'borrower_groups') }}
qualify row_number() over (
    partition by group_id
    order by _loaded_at desc, _source_file desc
) = 1
