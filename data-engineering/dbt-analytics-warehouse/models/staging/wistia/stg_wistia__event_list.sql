{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'visitor_key',
    'event_key',
    'media_id'
] %}
{% set strings = [
    'ip',
    'country',
    'region',
    'city',
    'org',
    'email',
    'embed_url',
    'conversion_type',
    'conversion_data',
    'iframe_heatmap_url',
    'media_name',
    'media_url'
] %}
{% set floats = [
    'lat',
    'lon',
    'percent_viewed'
] %}
{% set booleans = [] %}
{% set integers = [] %}
{% set timestamps = [
    'received_at',
    '_databricks_synced_at'
] %}


with
base_source as (select * from {{ source('wistia', 'event_list') }}),

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
        {% endfor %},

        -- casting objects

        CAST(user_agent_details.browser AS STRING)  AS user_agent_details_browser,
        CAST(user_agent_details.browser_version AS STRING) AS user_agent_details_browser_version,
        CAST(user_agent_details.platform AS STRING) AS user_agent_details_platform,
        CAST(user_agent_details.mobile AS BOOLEAN) AS user_agent_details_mobile,
        CAST(thumbnail.url AS STRING) AS thumbnail_url,
        CAST(thumbnail.contentType AS STRING) AS thumbnail_contentType,
        CAST(thumbnail.type AS STRING) AS thumbnail_type,
        CAST(thumbnail.width AS INTEGER) AS thumbnail_width,
        CAST(thumbnail.height AS INTEGER) AS thumbnail_height,
        CAST(thumbnail.fileSize AS INTEGER) AS thumbnail_fileSize        

    from base_source
),

-- Name the columns based on naming and fields conventions
adapt_variables_names as (
    SELECT
        visitor_key AS visitor_id,
        media_id,
        event_key AS event_id,
        received_at,
        ip,
        country,
        region,
        city,
        org,
        CASE
            WHEN ARRAY_LENGTH(SPLIT(email, '_')) > 1 
            THEN SPLIT(email, '_')[OFFSET(1)]
            ELSE NULL
        END AS email,
        embed_url,
        conversion_type,
        conversion_data,
        iframe_heatmap_url,
        user_agent_details_browser AS browser,
        user_agent_details_browser_version AS browser_version,
        user_agent_details_platform AS platform,
        media_name,
        media_url,
        thumbnail_url AS thumbnail_url,
        thumbnail_contentType AS thumbnail_contentType,
        thumbnail_type AS thumbnail_type,
        lat,
        lon,
        percent_viewed,
        user_agent_details_mobile AS is_mobile,
        thumbnail_width AS thumbnail_width,
        thumbnail_height AS thumbnail_height,
        thumbnail_fileSize AS thumbnail_fileSize,
        _databricks_synced_at AS last_updated_at
    FROM 
        cast_variables
)

select * from adapt_variables_names -- event_id is duplicated, look later