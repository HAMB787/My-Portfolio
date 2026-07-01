{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'id',
    'gw_id',
    'expert_id',
    'part_id',
    'module_id'
] %}
{% set strings = [
    'gw_short_title',
    'gw_description',
    'gw_baselink',
    'gw_platform',
    'gw_tier_group',
    'expert_name',
    'expert_mgmt_uid',
    'part_description',
    'part_goal',
    'module_name',
    'module_goal',
    'module_description',
    'module_quotes'
] %}
{% set integers = [
    'part_order',
    'gw_order',
    'gw_length_minutes',
    'module_weeks_length'
] %}
{% set booleans = [
    'module_blocked_for_selection'
] %}
{% set timestamps = [
    'createdAt',
    'updatedAt',
    'publishedAt',
    'gw_createdAt',
    'gw_updatedAt',
    'gw_publishedAt',
    'expert_createdAt',
    'expert_updatedAt',
    'expert_publishedAt',
    'part_createdAt',
    'part_updatedAt',
    'part_publishedAt',
    'module_createdAt',
    'module_updatedAt',
    'module_publishedAt',
    '_databricks_synced_at'
] %}



with
base_source as (select * from {{ source('strapi', 'gw_module_relations') }}),

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
        -- IDs
        id,
        gw_id,
        expert_id,
        part_id,
        module_id,

        -- Strings
        gw_short_title AS growthwork_short_title,
        gw_description AS growthwork_description,
        gw_baselink AS growthwork_baselink,
        gw_platform AS growthwork_platform,
        gw_tier_group AS growthwork_tier_group,
        expert_name,
        expert_mgmt_uid AS expert_management_uid,
        part_description,
        part_goal,
        module_name,
        module_goal,
        module_description,
        module_quotes,

        -- Integers
        part_order,
        gw_order,
        gw_length_minutes AS growthwork_length_minutes,
        module_weeks_length,

        -- Booleans
        module_blocked_for_selection,

        -- Timestamps
        createdAt AS created_at,
        updatedAt AS updated_at,
        publishedAt AS published_at,
        gw_createdAt AS growthwork_created_at,
        gw_updatedAt AS growthwork_updated_at,
        gw_publishedAt AS growthwork_published_at,
        expert_createdAt AS expert_created_at,
        expert_updatedAt AS expert_updated_at,
        expert_publishedAt AS expert_published_at,
        part_createdAt AS part_created_at,
        part_updatedAt AS part_updated_at,
        part_publishedAt AS part_published_at,
        module_createdAt AS module_created_at,
        module_updatedAt AS module_updated_at,
        module_publishedAt AS module_published_at,
        _databricks_synced_at AS databricks_synced_at
    FROM
        cast_variables
)

select * from adapt_variables_names