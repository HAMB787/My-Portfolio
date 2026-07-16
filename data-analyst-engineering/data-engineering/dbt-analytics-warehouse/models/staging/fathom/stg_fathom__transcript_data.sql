{{ config(
    materialized='table'
)}}

{% set strings = [
    'data_type',
    'meeting_actual_duration',
    'meeting_host',
    'meeting_invitees',
    'meeting_title',
    'meeting_id',
    'meeting_transcript',
    'unique_key'
] %}
{% set timestamps = [
    'meeting_scheduled_end_time',
    'meeting_scheduled_start_time',
    '_databricks_synced_at',
    'stored_at'
] %}
{% set integers = [
    'meeting_scheduled_duration'
] %}

with

source as (
    select * from {{ source('fathom', 'transcript_data') }}
),

cast_variables as (
    select
        {% for s in strings %}
            cast({{s}} as string) as {{s}},
        {% endfor %}

        {% for i in integers %}
            cast({{i}} as int64) as {{i}},
        {% endfor %}

        {% for t in timestamps %}
            cast({{t}} as timestamp) as {{t}}{% if not loop.last %},{% endif %}
        {% endfor %},

        cast(ceil(cast(meeting_actual_duration as float64)) as int64) as rounded_meeting_duration

    from source
),

adjusted_names as (
    select 
        data_type,
        rounded_meeting_duration as actual_duration,
        meeting_host as host,
        meeting_id as id,
        meeting_invitees as invitees,
        meeting_scheduled_duration as scheduled_duration,
        meeting_scheduled_end_time as scheduled_end_time,
        meeting_scheduled_start_time as scheduled_start_time,
        meeting_title as session_title,
        meeting_transcript as transcript,
        _databricks_synced_at,
        stored_at,
        unique_key

    from cast_variables
),


final as (
    select
        data_type,
        actual_duration,
        host,
        id,
        invitees,
        scheduled_duration,
        scheduled_end_time,
        scheduled_start_time,
        session_title,
        transcript,
        _databricks_synced_at,
        stored_at,
        unique_key
    from adjusted_names
)

select * from final
