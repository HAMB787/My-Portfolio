{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'account_id'
] %}
{% set strings = [
    'ad_distribution',
    'bid_match_type',
    'currency_code',
    'delivered_match_type',
    'device_os',
    'device_type',
    'network',
    'top_vs_other'
] %}
{% set timestamps = [
    'date',
    '_fivetran_synced'
] %}
{% set integers = [
    'impressions',
    'clicks',
    'conversions',
    'low_quality_clicks',
    'low_quality_general_clicks',
    'low_quality_sophisticated_clicks',    
    'low_quality_impressions',
    'low_quality_conversions',
    'phone_impressions',
    'phone_calls',
    'assists'
] %}
{% set floats = [
    'ctr',
    'average_cpc',
    'spend',
    'average_position',
    'conversions_qualified',
    'conversion_rate',
    'cost_per_conversion',
    'low_quality_clicks_percent',
    'low_quality_impressions_percent',
    'low_quality_conversions_qualified',
    'low_quality_conversion_rate',
    'revenue',
    'return_on_ad_spend',
    'cost_per_assist',
    'revenue_per_conversion',
    'revenue_per_assist',
    'all_conversions_qualified'
] %}


with
base_source as (select * from {{ source('bing_ads', 'account_performance_daily_report') }}),

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
        account_id,
        ad_distribution,
        bid_match_type,
        currency_code,
        delivered_match_type,
        device_os,
        device_type,
        network,
        top_vs_other,
        date,
        _fivetran_synced,
        impressions,
        clicks,
        ctr,
        average_cpc,
        spend,
        average_position,
        conversions,
        conversions_qualified,
        conversion_rate,
        cost_per_conversion,
        low_quality_clicks,
        low_quality_clicks_percent,
        low_quality_impressions,
        low_quality_impressions_percent,
        low_quality_conversions,
        low_quality_conversions_qualified,
        low_quality_conversion_rate,
        phone_impressions,
        phone_calls,
        assists,
        revenue,
        return_on_ad_spend,
        cost_per_assist,
        revenue_per_conversion,
        revenue_per_assist,
        low_quality_general_clicks,
        low_quality_sophisticated_clicks,
        all_conversions_qualified
    FROM
        cast_variables
)

select * from adapt_variables_names