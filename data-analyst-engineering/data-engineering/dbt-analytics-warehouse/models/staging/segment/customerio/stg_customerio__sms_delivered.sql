{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'action_id',
    'campaign_id',
    'delivery_id',
    'id',
    'journey_id',
    'user_id',
    'customer_id',
    'trigger_event_id'
] %}
{% set strings = [
    'anonymous_id',
    'context_integration_name',
    'context_integration_version',
    'context_library_name',
    'context_library_version',
    'context_traits_email',
    'event',
    'event_text',
    'recipient'
] %}
{% set timestamps = [
    'loaded_at',
    'original_timestamp',
    'received_at',
    'sent_at',
    'timestamp',
    'uuid_ts'
] %}

with
base_source as (select * from {{ source('segment_customerio', 'sms_delivered') }}),

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
        action_id,
        campaign_id,
        delivery_id,
        id,
        journey_id,
        user_id,
        customer_id,
        trigger_event_id,
        anonymous_id,
        context_integration_name AS integration_name,
        context_integration_version AS integration_version,
        context_library_name AS library_name,
        context_library_version AS library_version,
        context_traits_email AS traits_email,
        event AS event_name,
        event_text,
        recipient,
        loaded_at,
        original_timestamp,
        received_at,
        sent_at,
        timestamp AS created_at,
        uuid_ts
    FROM
        cast_variables
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY timestamp DESC) = 1
)

select * from adapt_variables_names