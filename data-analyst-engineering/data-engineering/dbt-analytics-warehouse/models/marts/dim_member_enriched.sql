with snapshot as (
    select *
    from {{ ref('dim_member_snapshot') }}
),

first_plan as (
    select
        id,
        first_value(member_plan IGNORE NULLS) over (
            partition by id
            order by dbt_valid_from
        ) as first_member_plan,
        first_value(member_plan_duration IGNORE NULLS) over (
            partition by id
            order by dbt_valid_from
        ) as first_member_plan_duration  
    from snapshot
    WHERE member_plan IS NOT NULL
    qualify row_number() over (
        partition by id
        order by dbt_valid_from
    ) = 1
)

select
    id,
    first_member_plan,
    first_member_plan_duration
from first_plan