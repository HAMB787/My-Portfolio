WITH

activity_events AS (SELECT * FROM {{ source('gsheet_lookup_tables', 'activity_events') }})

SELECT * FROM activity_events