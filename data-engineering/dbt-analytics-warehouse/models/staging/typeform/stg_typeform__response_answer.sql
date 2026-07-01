{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'field_id',
    'form_id',
    'response_id'
] %}
{% set strings = [
    'date',
    'email',
    'file_url',
    'payment_amount',
    'payment_last_4',
    'payment_name',
    'phone_number',
    'text',
    'type',
    'url'
] %}
{% set floats = [
    'number'
] %}
{% set booleans = [
    'boolean'
] %}
{% set timestamps = [
    '_fivetran_synced'
] %}


with
base_source as (select * from {{ source('typeform', 'response_answer') }}),

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
        field_id,
        form_id,
        response_id,
        date,
        email,
        file_url,
        payment_amount,
        payment_last_4,
        payment_name,
        phone_number,
        text,
        type,
        url,
        number,
        boolean,
        _fivetran_synced AS fivetran_synced_at
    FROM
        cast_variables
)

select * from adapt_variables_names