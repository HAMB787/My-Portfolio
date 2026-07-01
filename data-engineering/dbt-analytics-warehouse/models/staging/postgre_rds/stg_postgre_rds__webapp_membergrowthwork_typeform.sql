{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'action_id',
    'expert_id',
    'gw_cms_id',
    'member_id',
    'uuid',
    'typeform_response_id'
] %}
{% set strings = [
    'url',
    'url_hash'
] %}
{% set integers = [
    'status'
] %}
{% set floats = [] %}
{% set booleans = [
    'is_fivetran_deleted',
    'is_deleted'
] %}
{% set arrays = [] %}
{% set timestamps = [
    'created_at',
    'deleted_at',
    'updated_at',
    'fivetran_synced_at'
] %}



with
base_source as ( -- core logic of extraction of videoask S3 data
    SELECT id,
        action_id,
        created AS created_at,
        deleted AS deleted_at,
        deleted_by_cascade AS is_deleted,
        expert_id,
        gw_cms_id,
        member_id,
        status,
        updated AS updated_at,
        url,
        url_hash,
        uuid,
        JSON_EXTRACT_SCALAR(result, '$.form_response.token')                                  AS typeform_response_id, -- only this is needed for now
        _fivetran_deleted                                                                     AS is_fivetran_deleted,
        _fivetran_synced                                                                      AS fivetran_synced_at
    from {{ source('postgre_rds', 'webapp_membergrowthwork') }}
    where JSON_EXTRACT(result, '$.metadata.type') = '"typeform"' 
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

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        id,
        action_id,
        expert_id,
        gw_cms_id,
        member_id,
        uuid,
        typeform_response_id,        
        url,
        url_hash,
        status,
        is_fivetran_deleted,
        is_deleted,
        created_at,
        deleted_at,
        updated_at,
        fivetran_synced_at
    FROM 
        cast_variables
)

select * from adapt_variables_names