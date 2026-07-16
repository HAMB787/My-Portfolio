{% snapshot appstore_review_snapshot %}

    {{
        config(
          target_schema='01_dbt_production_snapshots',
          strategy='timestamp',
          unique_key='id',
          updated_at='last_modified',
          invalidate_hard_deletes=True,
        )
    }}

    select * from {{ source('appstore', 'review') }}

{% endsnapshot %}