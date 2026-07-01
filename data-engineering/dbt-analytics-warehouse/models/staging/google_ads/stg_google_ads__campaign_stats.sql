{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    '_fivetran_id',
    'customer_id',
    'id'
] %}
{% set strings = [
    'ad_network_type',
    'base_campaign',
    'device',
    'interaction_event_types'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'date'
] %}
{% set integers = [
    'active_view_impressions',
    'active_view_measurable_cost_micros',
    'active_view_measurable_impressions',
    'clicks',
    'cost_micros',
    'impressions',
    'interactions',
    'view_through_conversions'
] %}
{% set floats = [
    'active_view_measurability',
    'active_view_viewability',
    'conversions',
    'conversions_value'
] %}

with
base_source as (select * from {{ source('google_ads', 'campaign_stats') }}),

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
        _fivetran_id,
        customer_id,
        id,
        date,
        _fivetran_synced,
        active_view_impressions,
        active_view_measurability,
        active_view_measurable_cost_micros,
        active_view_measurable_impressions,
        active_view_viewability,
        ad_network_type,
        base_campaign,
        clicks,
        conversions,
        conversions_value,
        cost_micros / 1000000 AS cost,
        device,
        impressions,
        interaction_event_types,
        interactions,
        view_through_conversions
    FROM
        cast_variables
)

select * from adapt_variables_names