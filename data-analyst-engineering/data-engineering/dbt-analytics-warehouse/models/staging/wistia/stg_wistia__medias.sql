{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'hashed_id'
] %}
{% set strings = [
    'name',
    'type',
    'description',
    'status',
    'project.name'
] %}
{% set floats = [
    'duration',
    'progress'
] %}
{% set booleans = [
    'archived'
] %}
{% set timestamps = [
    'created',
    'updated',
    '_databricks_synced_at'
] %}



with
base_source as (select * from {{ source('wistia', 'medias') }}),

-- Cast variables for declaring the right data type for each column in compiler
cast_variables as (

    select

        {% for i in ids %}
            cast({{i}} as string) as {{i}},
        {% endfor %}

        {% for s in strings %}
            {% if '.' in s %}
                cast({{ s.split('.')[0] }}.{{ s.split('.')[1] }} as string) as {{ s.replace('.', '_') }}
            {% else %}
                cast({{s}} as string) as {{s}}
            {% endif %},
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
        hashed_id,
        name,
        type,
        project_name,
        created AS created_at,
        updated AS last_updated_at,
        description,
        status,
        duration,
        progress,
        archived AS is_archived,
        _databricks_synced_at AS databricks_synced_at
    FROM
        cast_variables
)

select * from adapt_variables_names