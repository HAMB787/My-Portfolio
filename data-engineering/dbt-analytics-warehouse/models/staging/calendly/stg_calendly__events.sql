{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'uri',
    'user_uri'
] %}
{% set strings = [
    'name',
    'status',
    'event_type',
    'meeting_notes_html',
    'meeting_notes_plain',
    'calendar_external_id',
    'calendar_kind',
    'location_type',
    'location_value',
    'user_email',
    'user_name',
    'guest_email'
] %}
{% set integers = [
    'invitees_active',
    'invitees_total',
    'invitees_limit'
] %}
{% set timestamps = [
    '_databricks_synced_at',
    'created_at',
    'updated_at',
    'start_time',
    'end_time',
    'guest_created_at',
    'guest_updated_at',
    'buffered_start_time',
    'buffered_end_time'
] %}


with
base_source as (select * from {{ source('calendly_databricks', 'events') }}),

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
        -- IDs
        uri AS id,
        user_uri AS user_id,

        -- Strings
        name,
        status,
        event_type,
        start_time,
        end_time,
        created_at,
        updated_at,
        meeting_notes_html,
        meeting_notes_plain,
        calendar_external_id,
        calendar_kind,
        location_type,
        location_value,
        user_email,
        user_name,
        guest_email,
        guest_created_at,
        guest_updated_at,
        buffered_start_time,
        buffered_end_time,

        -- Integers
        invitees_active,
        invitees_total,
        invitees_limit,

        -- Timestamps
        _databricks_synced_at AS databricks_synced_at

    FROM 
        cast_variables
),

-- Join with users to get timezone and convert times to UTC
final as (
    SELECT 
        e.id,
        e.user_id,
        e.name,
        e.status,
        e.event_type,
        e.start_time AS start_time_original,
        DATETIME(e.start_time, u.user_timezone) AS start_time,        
        e.end_time AS end_time_original,
        DATETIME(e.end_time, u.user_timezone) AS end_time,        
        e.created_at,
        e.updated_at,
        e.meeting_notes_html,
        e.meeting_notes_plain,
        e.calendar_external_id,
        e.calendar_kind,
        e.location_type,
        e.location_value,
        e.user_email,
        e.user_name,
        e.guest_email,
        e.guest_created_at,
        e.guest_updated_at,
        e.buffered_start_time AS buffered_start_time_original,
        DATETIME(e.buffered_start_time, u.user_timezone) AS buffered_start_time,        
        e.buffered_end_time AS buffered_end_time_original,
        DATETIME(e.buffered_end_time, u.user_timezone) AS buffered_end_time,        
        e.invitees_active,
        e.invitees_total,
        e.invitees_limit,
        e.databricks_synced_at,
        u.user_timezone AS expert_timezone
    FROM adapt_variables_names e
    LEFT JOIN {{ source('calendly_databricks', 'users') }} u ON e.user_id = u.user_uri
)

select * from final