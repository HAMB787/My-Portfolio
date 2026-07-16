{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'action_tracker_id',
    'ad_id',
    'campaign_id',
    'customer_id',
    'media_partner_id',
    'shared_id'
] %}
{% set strings = [
    'action_tracker_name',
    'caller_id',
    'campaign_name',
    'cleared_date',
    'currency',
    'customer_area',
    'customer_city',
    'customer_country',
    'customer_post_code',
    'customer_region',
    'customer_status',
    'event_code',
    'ip_address',
    'media_partner_name',
    'note',
    'o_id',
    'promo_code',
    'referring_domain',
    'referring_type',
    'state'
] %}
{% set booleans = [
    '_fivetran_deleted'
] %}
{% set floats = [
    'amount',
    'client_cost',
    'delta_amount',
    'delta_payout',
    'intended_amount',
    'intended_payout',
    'payout'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'creation_date',
    'event_date',
    'locking_date',
    'referring_date'
] %}


with
base_source as (select * from {{ source('impact', 'action_event') }}),

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
        action_tracker_id,
        ad_id,
        campaign_id,
        customer_id,
        media_partner_id,
        shared_id,
        action_tracker_name,
        caller_id,
        campaign_name,
        cleared_date,
        currency,
        customer_area,
        customer_city,
        customer_country,
        customer_post_code,
        customer_region,
        customer_status,
        event_code,
        ip_address,
        media_partner_name,
        note,
        o_id,
        promo_code,
        referring_domain,
        referring_type,
        state,
        _fivetran_deleted AS is_deleted,
        amount,
        client_cost,
        delta_amount,
        delta_payout,
        intended_amount,
        intended_payout,
        payout,
        _fivetran_synced AS fivetran_synced_at,
        creation_date,
        event_date,
        locking_date,
        referring_date

    FROM 
        cast_variables
)

select * from adapt_variables_names