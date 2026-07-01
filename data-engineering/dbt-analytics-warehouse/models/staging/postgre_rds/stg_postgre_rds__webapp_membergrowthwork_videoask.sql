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
    'uuid'
] %}
{% set strings = [
    'url',
    'url_hash',
    'growthwork_type',
    'answer_type'
] %}
{% set integers = [
    'status',
    'question_media_duration',
    'answer_media_duration'
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
        REPLACE(JSON_EXTRACT(result, '$.metadata.type'), '"', '')                             AS growthwork_type,
        CAST(JSON_EXTRACT_SCALAR(result, '$.form.questions[0].media_duration') AS INT64)      AS question_media_duration,
        JSON_EXTRACT_SCALAR(result, '$.contact.answers[0].type')                              AS answer_type,
        CASE
            WHEN JSON_EXTRACT_SCALAR(result, '$.contact.answers[0].type') = 'text' THEN LENGTH(JSON_EXTRACT_SCALAR(result, '$.contact.answers[0].input_text')) * 0.3 -- dynamic calculation assuming for 1 character typing member spends 0.3 seconds
            ELSE CAST(JSON_EXTRACT_SCALAR(result, '$.contact.answers[0].media_duration') AS INT64)
        END                                                                                   AS answer_media_duration,
        _fivetran_deleted                                                                     AS is_fivetran_deleted,
        _fivetran_synced                                                                      AS fivetran_synced_at
    from {{ source('postgre_rds', 'webapp_membergrowthwork') }}
    where JSON_EXTRACT(result, '$.metadata.type') = '"videoask"' 
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
        url,
        url_hash,
        growthwork_type,
        status,
        question_media_duration,
        answer_type,
        answer_media_duration,
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