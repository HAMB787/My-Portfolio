{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'campaign_id'
] %}
{% set strings = [
    'ad_type',
    'campaign_name',
    'deal_products',
    'deal_restricted_media_partner_groups',
    'deal_restricted_media_partners',
    'get_html_code_type',
    'iab_ad_unit',
    'landing_page',
    'language',
    'name',
    'restricted_media_partner_groups',
    'restricted_media_partners',
    'link_text'
] %}
{% set floats = [
    'customisation_charge'
] %}
{% set booleans = [
    '_fivetran_deleted',
    'allow_deep_linking',
    'mobile_ready',
    'phone_tracking',
    'promo_code_tracking',
    'top_seller'
] %}
{% set integers = [
    'third_party_servable_ad_creative_height',
    'third_party_servable_ad_creative_width'
] %}
{% set timestamps = [
    '_fivetran_synced',
    'limited_time_start_date'
] %}


with
base_source as (select * from {{ source('impact', 'ads') }}),

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
        campaign_id,
        ad_type,
        campaign_name,
        deal_products,
        deal_restricted_media_partner_groups,
        deal_restricted_media_partners,
        get_html_code_type,
        iab_ad_unit,
        landing_page,
        language,
        name,
        restricted_media_partner_groups,
        restricted_media_partners,
        link_text,
        customisation_charge,
        _fivetran_deleted AS is_deleted,
        allow_deep_linking,
        mobile_ready,
        phone_tracking,
        promo_code_tracking,
        top_seller,
        third_party_servable_ad_creative_height,
        third_party_servable_ad_creative_width,
        _fivetran_synced AS fivetran_synced_at,
        limited_time_start_date
    FROM
        cast_variables
)

select * from adapt_variables_names