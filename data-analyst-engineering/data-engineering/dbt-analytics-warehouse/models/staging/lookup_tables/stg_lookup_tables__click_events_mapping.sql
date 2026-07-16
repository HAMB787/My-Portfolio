WITH

click_events_mapping AS (SELECT * FROM {{ source('gsheet_lookup_tables', 'click_events_mapping') }})

SELECT * FROM click_events_mapping