{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    '_fivetran_id',
    'customer_id',
    'ad_group_id',
    'ad_id',
    'campaign_id'
] %}
{% set strings = [
    'ad_group_base_ad_group',
    'ad_network_type',
    'campaign_base_campaign',
    'device',
    'interaction_event_types'
] %}
{% set integers = [
    'active_view_impressions',
    'active_view_measurable_cost_micros',
    'active_view_measurable_impressions',
    'clicks',
    'cost_micros',
    'impressions',
    'interactions',
    'video_views',
    'view_through_conversions'
] %}
{% set floats = [
    'active_view_measurability',
    'active_view_viewability',
    'conversions',
    'conversions_value',
    'cost_per_conversion'
] %}
{% set booleans = [] %}
{% set arrays = [] %}
{% set timestamps = [
    '_fivetran_synced',
    'date'
] %}

with
base_source as (select * from {{ source('google_ads', 'ad_stats') }}),

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
        date AS created_at,
        _fivetran_synced AS fivetran_synced_at,
        active_view_impressions,
        active_view_measurability,
        active_view_measurable_cost_micros,
        active_view_measurable_impressions,
        active_view_viewability,
        ad_group_base_ad_group,
        ad_group_id,
        ad_id,
        ad_network_type,
        campaign_base_campaign,
        campaign_id,
        clicks,
        conversions,
        conversions_value,
        cost_micros / 1000000 AS cost,
        cost_per_conversion / 1000000 AS cost_per_conversion,
        device,
        impressions,
        interaction_event_types,
        interactions,
        video_views,
        view_through_conversions
    FROM 
        cast_variables
)

select * from adapt_variables_names