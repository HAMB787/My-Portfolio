{% snapshot dim_member_snapshot %}

    {{
        config(
          target_schema='01_dbt_production_snapshots',
          strategy='check',
          unique_key='id',
          check_cols=['subscription_created_at', 'expert_id', 'member_plan', 'member_plan_duration' ,'subscription_status'],
          invalidate_hard_deletes=True,
        )
    }}

    select * from {{ ref('dim_member') }}

{% endsnapshot %}