WITH
      Conversion AS (
        SELECT
          i.customer_id,
          DATE(MIN(i.created)) AS conversion_date,
          MIN(i.id) AS invoice_id,
          SUM(i.amount_paid) AS amount
        FROM
          {{ source('stripe', 'invoice') }} i
        WHERE
          i.status = 'paid' and i.amount_paid > 0
        GROUP BY
          i.customer_id
      ),
      CustomerMetadata AS (
        SELECT
        c.id,
        JSON_EXTRACT_SCALAR(metadata, '$.uuid') AS uuid,
        JSON_EXTRACT_SCALAR(metadata, '$.coupon') AS coupon,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn') AS rfsn,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn_v4_aid') AS rfsn_v4_aid,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn_v4_cs') AS rfsn_v4_cs,
        JSON_EXTRACT_SCALAR(metadata, '$.rfsn_v4_id') AS rfsn_v4_id,
        JSON_EXTRACT_SCALAR(metadata, '$.tier_type') AS tier_type,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_campaign') AS utm_campaign,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_content') AS utm_content,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_medium') AS utm_medium,
        JSON_EXTRACT_SCALAR(metadata, '$.utm_source') AS utm_source
      FROM
      {{ source('stripe', 'customer') }} c
      )
      SELECT
        cm.uuid,
        cv.conversion_date,
        cm.utm_source,
        cm.utm_medium,
        cm.utm_campaign,
        cm.utm_content,
      FROM
        Conversion cv
      JOIN
        CustomerMetadata cm ON cv.customer_id = cm.id
      GROUP BY
        cm.uuid, cv.conversion_date, cm.utm_source, cm.utm_medium, cm.utm_campaign, cm.utm_content
      ORDER BY
        cv.conversion_date DESC