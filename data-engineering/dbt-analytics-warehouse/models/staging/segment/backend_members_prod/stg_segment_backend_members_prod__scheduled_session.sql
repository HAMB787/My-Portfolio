{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids        =  [
    'expert_id',
    'id',
    'meeting_id',
    'meeting_invitee_uuid',
    'user_id'
] %}
{% set strings    =  [
    'context_library_name',
    'context_library_version',
    'email',
    'event',
    'event_text',
    'expert_name',
    'meeting_invitee_time',
    'meeting_link',
    'meeting_type',
    'notes',
    'original_timestamp',
    'schedule_link',
    'timezone',
    'meeting_location'
] %}
{% set integers   = ['meeting_timestamp'] %}
{% set floats     = [] %}
{% set booleans   = [] %}
{% set arrays     = [] %}
{% set timestamps = ['loaded_at', 'received_at', 'sent_at', 'timestamp', 'uuid_ts'] %}

with
base_source as (select * from {{ source('segment_backend_members_prod', 'scheduled_session') }}),

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
        context_library_name AS library_name,
        context_library_version AS library_version,
        email,
        event AS event_name,
        event_text,
        expert_id,
        expert_name,
        id,
        loaded_at,
        meeting_id,
        meeting_invitee_time,
        meeting_invitee_uuid,
        meeting_link,
        TIMESTAMP_SECONDS(meeting_timestamp)                                                         AS meeting_created_at,
        meeting_type,
        notes,
        original_timestamp,
        received_at,
        schedule_link,
        sent_at,
        timestamp AS event_timestamp,
        timezone,
        user_id,
        uuid_ts,
        meeting_location
    FROM
        cast_variables

)
select * from adapt_variables_names