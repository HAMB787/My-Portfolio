{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'expert_id',
    'module_id',
    'primary_member_id',
    'account_id',
    'uuid'
] %}
{% set strings = [
    'calendly_additional_notes',
    'email',
    'extra_details',
    'first_name',
    'gender',
    'last_name',
    'phone_number',
    'timezone'
] %}
{% set integers = [
    'age',
    'app_status',
    'funnel',
    'push_notifications_status',
    'status',
    'tier_type'
] %}
{% set booleans = [
    '_fivetran_deleted',
    'deleted_by_cascade'
] %}
{% set floats = [] %}
{% set arrays = [] %}
{% set timestamps = [
    '_fivetran_synced',
    'created',
    'deleted',
    'updated'
] %}

with
base_source as (
    select *
    from {{ source('postgre_rds', 'webapp_member') }}
    WHERE id NOT IN (2511) -- David test user
        AND NOT _fivetran_deleted
), 

-- Cast variables for declaring the right data type for each column in compiler
cast_variables as (

    select

        {% for i in ids %}
            cast({{i}} as string) as {{i}},
        {% endfor %}

        {% for s in strings %}
            cast({{s}} as string) as {{s}},
        {% endfor %}

        {% for n in integers %}
            cast({{n}} as int64) as {{n}},
        {% endfor %}

        {% for f in floats %}
            cast({{f}} as float64) as {{f}},
        {% endfor %}

        {% for b in booleans %}
            cast({{b}} as boolean) as {{b}},
        {% endfor %}

        {% for arr in arrays %}
            ARRAY(SELECT SAFE_CAST(num AS STRING) 
            FROM UNNEST(SPLIT(substr({{arr}}, 2 , LENGTH({{arr}}) - 2))) AS num
            ) as {{arr}},
        {% endfor %}

        {% for t in timestamps %}
            cast({{t}} as timestamp) as {{t}}{% if not loop.last %},{% endif %}
        {% endfor %}

        ,
        geo_data

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        id,
        _fivetran_deleted AS is_fivetran_deleted,
        _fivetran_synced AS fivetran_synced_at,
        age,
        app_status,
        calendly_additional_notes,
        created AS created_at,
        deleted AS deleted_at,
        deleted_by_cascade AS is_deleted,
        email,
        expert_id,
        extra_details,
        first_name,
        funnel,
        gender,
        last_name,
        module_id,
        phone_number,
        primary_member_id,
        push_notifications_status,
        status,
        tier_type,
        timezone,
        REPLACE(JSON_EXTRACT(geo_data, '$.geo_ip'), '"','') AS geo_ip,        
        REPLACE(JSON_EXTRACT(geo_data, '$.geo_state'), '"','') AS geo_state,        
        REPLACE(JSON_EXTRACT(geo_data, '$.geo_locale'), '"','') AS geo_locale,        
        REPLACE(JSON_EXTRACT(geo_data, '$.geo_country'), '"','') AS geo_country,        
        REPLACE(JSON_EXTRACT(geo_data, '$.geo_timezone'), '"','') AS geo_timezone,        
        updated AS updated_at,
        uuid,
        account_id
    FROM  
        cast_variables
)

select * from adapt_variables_names