{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'expert_uuid',
    'user_id',
    'member_uuid'
] %}
{% set strings = [
    'context_library_name',
    'context_library_version',
    'event',
    'event_text',
    'expert_email',
    'module_title',
    'original_timestamp',
    'part_goal',
    'member_email',
    'member_first_name',
    'member_last_name',
    'email'
] %}
{% set integers = [
    'part_cms_id',
    'part_number'
] %}
{% set timestamps = [
    'loaded_at',
    'received_at',
    'sent_at',
    'timestamp',
    'uuid_ts'
] %}

with
base_source as (select * from {{ source('segment_backend_members_prod', 'module_part_assigned') }}),

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
        expert_uuid,
        user_id,
        member_uuid,
        context_library_name AS library_name,
        context_library_version AS library_version,
        event AS event_name,
        event_text,
        expert_email,
        module_title,
        original_timestamp,
        part_goal,
        member_email,
        member_first_name,
        member_last_name,
        email,
        part_cms_id,
        part_number,
        loaded_at,
        received_at,
        sent_at,
        timestamp AS created_at,
        uuid_ts
    FROM
        cast_variables

)
select * from adapt_variables_names