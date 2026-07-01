{% snapshot webapp_expert_snapshot %}

    {{
        config(
          target_schema='01_dbt_production_snapshots',
          strategy='check',
          unique_key='id',
          check_cols=['uuid', 'email', 'first_name', 'last_name', 'type', 'desired_members'],
          invalidate_hard_deletes=True,
        )
    }}

    select 
        id,
        uuid,
        email,
        first_name,
        last_name,
        type,
        desired_members
    from {{ source('postgre_rds', 'webapp_expert') }}

{% endsnapshot %}