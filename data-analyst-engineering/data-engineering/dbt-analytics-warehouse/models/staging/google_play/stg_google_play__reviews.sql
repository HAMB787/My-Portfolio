{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    '_file',
    '_line'
] %}
{% set strings = [
    'device',
    'package_name',
    'reviewer_language'
] %}
{% set integers = [
    'review_last_update_millis_since_epoch',
    'review_submit_millis_since_epoch',
    'star_rating'
] %}
{% set timestamps = [
    '_fivetran_synced',
    '_modified',
    'review_last_update_date_and_time',
    'review_submit_date_and_time'
] %}


with
base_source as (select * from {{ source('google_play', 'reviews') }}),

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
        MD5(_file || CAST(_line AS STRING)) AS id,
        _file AS file_id,
        _line AS line_number,
        _fivetran_synced AS fivetran_synced_at,
        _modified AS modified_at,
        device,
        package_name,
        review_last_update_date_and_time AS review_last_update_at,
        review_last_update_millis_since_epoch,
        review_submit_date_and_time AS review_submit_at,
        review_submit_millis_since_epoch,
        reviewer_language,
        star_rating,
        MIN(review_submit_date_and_time) OVER(PARTITION BY device)     AS created_at,
        ROW_NUMBER() OVER(PARTITION BY device ORDER BY _modified DESC) AS rnk
    FROM
        cast_variables
)

select * from adapt_variables_names