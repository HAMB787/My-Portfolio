{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'customer_id'
] %}
{% set strings = [
    'billing_detail_address_city',
    'billing_detail_address_country',
    'billing_detail_address_line_1',
    'billing_detail_address_line_2',
    'billing_detail_address_postal_code',
    'billing_detail_address_state',
    'billing_detail_email',
    'billing_detail_name',
    'billing_detail_phone',
    'type'
] %}
{% set timestamps = [
    'created',
    '_fivetran_synced'
] %}
{% set booleans = [
    'livemode'
] %}



with
base_source as (select * from {{ source('stripe', 'payment_method') }}),

-- Cast variables for declaring the right data type for each column in compiler
cast_variables as (

    select

        {% for i in ids %}
            cast({{i}} as string) as {{i}},
        {% endfor %}

        {% for s in strings %}
            upper(cast({{s}} as string)) as {{s}},
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
        {% endfor %},

        metadata

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        -- IDs
        id,
        customer_id,

        -- Billing Details (aliased for clarity)
        billing_detail_address_city AS address_city,
        billing_detail_address_country AS address_country,
        billing_detail_address_line_1 AS address_line_1,
        billing_detail_address_line_2 AS address_line_2,
        billing_detail_address_postal_code AS address_postal_code,
        billing_detail_address_state AS address_state,
        billing_detail_email AS billing_email,
        billing_detail_name AS billing_name,
        billing_detail_phone AS billing_phone,

        -- Misc
        metadata,
        type,
        livemode,

        -- Timestamps
        created,
        _fivetran_synced AS fivetran_synced_at

    FROM
        cast_variables

)
select * from adapt_variables_names