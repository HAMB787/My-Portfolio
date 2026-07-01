{{ config(
    materialized='view'
)}}

-- Select the data types for each column
{% set ids = [
    'form_id',
    'id',
    'form_parent_field_id',
    'ref'
] %}
{% set strings = [
    'layout_attachment_href',
    'layout_attachment_property_description',
    'layout_attachment_type',
    'layout_placement',
    'layout_type',
    'property_button_text',
    'property_currency',
    'property_default_country_code',
    'property_description',
    'property_label_center',
    'property_label_left',
    'property_label_right',
    'property_price_type',
    'property_price_value',
    'property_separator',
    'property_shape',
    'property_structure',
    'title',
    'type'
] %}
{% set floats = [
    'layout_attachment_property_brightness',
    'layout_attachment_property_focal_point_x',
    'layout_attachment_property_focal_point_y',
    'layout_attachment_scale'
] %}
{% set integers = [
    'validation_max_length',
    'validation_max_selection',
    'validation_max_value',
    'validation_min_selection',
    'validation_min_value'
] %}
{% set booleans = [
    '_fivetran_active',
    'property_allow_multiple_selection',
    'property_allow_other_choice',
    'property_alphabetical_order',
    'property_hide_marks',
    'property_randomize',
    'property_show_button',
    'property_show_labels',
    'property_start_at_one',
    'property_supersized',
    'property_vertical_alignment',
    'validation_required'
] %}
{% set timestamps = [
    '_fivetran_start',
    '_fivetran_end',
    '_fivetran_synced'
] %}


with
base_source as (select * from {{ source('typeform', 'form_field_history') }}),

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
        form_id,
        id,
        form_parent_field_id,
        ref,
        layout_attachment_href,
        layout_attachment_property_description,
        layout_attachment_type,
        layout_placement,
        layout_type,
        property_button_text,
        property_currency,
        property_default_country_code,
        property_description,
        property_label_center,
        property_label_left,
        property_label_right,
        property_price_type,
        property_price_value,
        property_separator,
        property_shape,
        property_structure,
        title,
        type,
        layout_attachment_property_brightness,
        layout_attachment_property_focal_point_x,
        layout_attachment_property_focal_point_y,
        layout_attachment_scale,
        validation_max_length,
        validation_max_selection,
        validation_max_value,
        validation_min_selection,
        validation_min_value,
        _fivetran_active AS is_active,
        property_allow_multiple_selection,
        property_allow_other_choice,
        property_alphabetical_order,
        property_hide_marks,
        property_randomize,
        property_show_button,
        property_show_labels,
        property_start_at_one,
        property_supersized,
        property_vertical_alignment,
        validation_required,
        _fivetran_start AS fivetran_start,
        _fivetran_end AS fivetran_end,
        _fivetran_synced AS fivetran_synced_at
    FROM
        cast_variables
)

select * from adapt_variables_names