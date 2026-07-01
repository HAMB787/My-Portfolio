{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'adset_id',
    '_fivetran_id',
    'account_id',
    'campaign_id'
] %}
{% set strings = [
    'adset_name',
    'campaign_name',
    'inline_link_click_ctr'
] %}
{% set integers = [
    'impressions',
    'inline_link_clicks',
    'reach'
] %}
{% set floats = [
    'cost_per_inline_link_click',
    'cpc',
    'cpm',
    'ctr',
    'frequency',
    'spend'
] %}
{% set timestamps = [
    'date',
    '_fivetran_synced'
] %}


with
base_source as (select * from {{ source('facebook_ads', 'basic_ad_set') }}),

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
        adset_id,
        campaign_id,
        adset_name,
        campaign_name,
        inline_link_click_ctr,
        account_id,
        impressions,
        inline_link_clicks,
        reach,
        cost_per_inline_link_click,
        cpc,
        cpm,
        ctr,
        frequency,
        spend,
        date AS reported_at,
        _fivetran_synced AS fivetran_synced_at
    FROM
        cast_variables
)

select * from adapt_variables_names