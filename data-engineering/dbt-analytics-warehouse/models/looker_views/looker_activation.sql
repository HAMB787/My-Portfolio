WITH params AS (
 SELECT DATE '2024-01-01' AS floor_date
),
 /* ============= 1) Paid filtered customers ============= */
 filtered_invoices AS (
   SELECT DISTINCT customer_id
   FROM `01_dbt_production_marts.fct_invoices`
   WHERE charge_is_paid = TRUE
     AND charge_failure_code IS NULL
     AND invoice_status = 'paid'
     AND invoice_total > 500
 ),


 /* ============= 2) Primary members from subscriptions ============= */
 invoice_customers AS (
   SELECT DISTINCT
     s.subscription_id,
     s.customer_id,
     s.customer_uuid,
     m.email,
     m.full_name,
     m.id AS member_id,
     s.subscription_created_at,
     s.subscription_canceled_at,
     s.subscription_ended_at,
     s.plan_name AS member_plan_name,
     s.plan_duration AS member_plan_duration,
     m.utm_source AS member_utm_source,
     m.attribution_source AS member_attribution_source,
     s.subscription_status,
     CASE
       WHEN s.product_name = 'Ritual Membership' THEN 'Couples'
       WHEN s.product_name = 'Ritual - Expert Led Journey' THEN 'Individuals'
       WHEN s.product_name = 'Ritual - Expert Led For Couples' THEN 'Couples'
       WHEN s.product_name = 'Matching session' THEN 'Matching'
       WHEN s.product_name = 'Ritual Hybrid Experience' THEN 'Individuals'
       WHEN s.product_name = 'Ritual Subscription' THEN 'Couples'
       WHEN s.product_name = 'Ritual - Digital First' THEN 'Individuals'
       WHEN s.product_name LIKE '%Couple%' THEN 'Couples'
       WHEN s.product_name LIKE '%Individual%' THEN 'Individuals'
       ELSE 'Other'
     END AS subscriber_type
   FROM `01_dbt_production_marts.fct_subscriptions` s
   JOIN filtered_invoices f ON f.customer_id = s.customer_id
   JOIN `01_dbt_production_marts.dim_member` m ON s.customer_uuid = m.uuid
   WHERE NOT (
     LOWER(s.customer_email) LIKE '%ritual%' OR
     LOWER(s.customer_email) LIKE '%test%'   OR
     LOWER(s.customer_email) LIKE '%+rm%'
   )
     AND DATE(s.subscription_created_at) >= (SELECT floor_date FROM params)
 ),


 /* ============= 3) Partner members (secondary seat) ============= */
 partner_members AS (
   SELECT DISTINCT
     p.subscription_id,
     p.customer_id,
     s.uuid AS customer_uuid,
     s.email,
     s.full_name,
     s.id AS member_id,
     p.subscription_created_at,
     p.subscription_canceled_at,
     p.subscription_ended_at,
     p.member_plan_name,
     p.member_plan_duration,
     s.utm_source AS member_utm_source,
     s.attribution_source AS member_attribution_source,
     p.subscription_status,
     p.subscriber_type
   FROM invoice_customers p
   JOIN `01_dbt_production_marts.dim_member` s
     ON p.member_id = s.primary_member_id
 ),


 /* ============= 4) All members (primary + partner) ============= */
 all_members AS (
   SELECT ic.*, 'Primary Member' AS member_flag FROM invoice_customers ic
   UNION DISTINCT
   SELECT pm.*, 'Partner' AS member_flag FROM partner_members pm
 ),


 /* ============= 4b) Partner presence on same subscription ============= */
 partner_presence_by_subscription AS (
   SELECT
     subscription_id,
     customer_id,
     COUNTIF(member_flag = 'Partner') > 0 AS has_partner_same_sub,
     MIN(CASE WHEN member_flag = 'Partner' THEN DATE(subscription_created_at) END) AS partner_first_seen_date
   FROM all_members
   GROUP BY subscription_id, customer_id
 ),


 /* ============= 4c) Winback flag ============= */
 winbacks AS (
   SELECT
     curr.subscription_id,
     EXISTS (
       SELECT 1
       FROM all_members prev
       WHERE prev.email = curr.email
         AND prev.subscription_canceled_at IS NOT NULL
         AND DATE(prev.subscription_canceled_at) < DATE(curr.subscription_created_at)
         AND prev.subscription_id != curr.subscription_id
     ) AS is_winback_subscription
   FROM all_members curr
 ),


 /* ============= 4d) Matching-first customers (for MBG exclusion) ============= */
 matching_first_customers AS (
   WITH first_sub AS (
     SELECT
       customer_id,
       ARRAY_AGG(
         STRUCT(product_name, subscription_created_at)
         ORDER BY subscription_created_at
       )[OFFSET(0)] AS first_rec
     FROM `01_dbt_production_marts.fct_subscriptions`
     GROUP BY customer_id
   )
   SELECT customer_id
   FROM first_sub
   WHERE first_rec.product_name = 'Matching session'
 ),


 /* ============= 5) Activity events (significant + supporting) ============= */
 active_users_list AS (
   -- Wistia (exclude Expert Onboarding)
   SELECT
     uuid,
     received_at AS activity_ts,
     CASE
       WHEN project_name IN ('Audio introductions') THEN 'Pathways-Audio'
       WHEN project_name IN (
         'Art of Conflict Videos','Befriending Anger','Pathway Extension Videos','Rebuilding After Infidelity',
         'Conscious Communication','Desire to Pleasure','Emotional Intimacy','Love after Kids',
         'Loving Boundaries','Re:Connection','Reflection Pathway','Foundations of Connection'
       ) THEN 'Pathways-Videos'
       WHEN project_name IN ('Teaser trailers','Copy of Teaser trailers') THEN 'Trailers'
       WHEN project_name = 'Expert Onboarding pathway' THEN NULL
       ELSE 'Media'
     END AS activity
   FROM `01_dbt_production_marts.fct_wistia_events`
   WHERE uuid IS NOT NULL


   UNION ALL
   -- Questionnaire
   SELECT uuid, survey_started_at AS activity_ts, 'Pathway-Questionnaire' AS activity
   FROM `01_dbt_production_marts.fct_questionnaire_answers`
   WHERE uuid IS NOT NULL


   UNION ALL
   -- Journaling
   SELECT dm.uuid, vj.updated_at AS activity_ts, 'Pathway-Journaling' AS activity
   FROM `01_dbt_production_marts.fct_video_journaling` vj
   LEFT JOIN `01_dbt_production_marts.dim_member` dm ON dm.id = vj.member_id
   WHERE dm.uuid IS NOT NULL


   UNION ALL
   -- Topic of month / content completed
   SELECT user_id AS uuid, created_at AS activity_ts, 'Topic of month' AS activity
   FROM `dbt-analytics-412206.01_dbt_production_marts.fct_content_interactions`
   WHERE event_name = 'member_content_completed'


   UNION ALL
   -- Chat message sent (two patterns)
   SELECT user_id AS uuid, created_at AS activity_ts, 'Chat message sent' AS activity
   FROM `dbt-analytics-412206.01_dbt_production_marts.fct_product_events`
   WHERE event_name LIKE '%member_sent_message%'


   UNION ALL
   SELECT user_id AS uuid, created_at AS activity_ts, 'Chat message sent' AS activity
   FROM `dbt-analytics-412206.01_dbt_production_marts.fct_product_events`
   WHERE event_name LIKE '%member_message_sent%'


   UNION ALL
   -- Expert rec clicks
   SELECT user_id AS uuid, created_at AS activity_ts, 'Member clicks Recommended by Expert' AS activity
   FROM `dbt-analytics-412206.01_dbt_production_marts.fct_product_events`
   WHERE event_name LIKE '%member_content_clicked%'
     AND JSON_EXTRACT_SCALAR(payload, '$.expertrec') = 'true'


   UNION ALL
   -- Message read
   SELECT user_id AS uuid, created_at AS activity_ts, 'Chat message read' AS activity
   FROM `dbt-analytics-412206.01_dbt_production_marts.fct_product_events`
   WHERE event_name LIKE '%message_read%'


   UNION ALL
   -- Emotional check-in
   SELECT user_id AS uuid, created_at AS activity_ts, 'Emotion Checkin' AS activity
   FROM `dbt-analytics-412206.01_dbt_production_marts.fct_product_events`
   WHERE event_name = 'member_emotional_checkin_completed'
 ),


 /* ============= 5b) Activity aggregated per day per uuid ============= */
 activity_per_day AS (
   SELECT
     uuid AS customer_uuid,
     DATE(activity_ts) AS activity_date,
     COUNT(*) AS activity_count,
     MAX(
       CASE
         WHEN activity IN (
           'Pathways-Audio','Pathways-Videos','Pathway-Questionnaire','Pathway-Journaling',
           'Chat message sent','Emotion Checkin','Topic of month','Trailers','Media'
         ) THEN 1 ELSE 0
       END
     ) AS has_significant_activity_flag
   FROM active_users_list
   GROUP BY uuid, DATE(activity_ts)
 ),


 /* ============= 6) Sessions per day (all ended) ============= */
 sessions_all_per_day AS (
   SELECT
     s.member_id,
     DATE(s.session_ended_at) AS session_date,
     COUNT(DISTINCT s.next_session_event_id) AS sessions_attended
   FROM `01_dbt_production_marts.fct_webapp_sessions` s
   WHERE LOWER(s.session_status) = 'ended'
   GROUP BY s.member_id, DATE(s.session_ended_at)
 ),


 /* ============= 7) First & second session completion dates ============= */
 first_second_session AS (
   WITH first_session AS (
     SELECT member_id, MIN(DATE(session_ended_at)) AS first_session_date
     FROM `01_dbt_production_marts.fct_webapp_sessions`
     WHERE LOWER(session_status) = 'ended'
     GROUP BY member_id
   ),
   second_session AS (
     SELECT
       s.member_id,
       MIN(DATE(s.session_ended_at)) AS second_session_date
     FROM `01_dbt_production_marts.fct_webapp_sessions` s
     JOIN first_session f USING (member_id)
     WHERE LOWER(s.session_status) = 'ended'
       AND DATE(s.session_ended_at) > f.first_session_date
       AND (s.session_type IS NULL OR s.session_type != 'Welcome')
     GROUP BY s.member_id
   )
   SELECT f.member_id, f.first_session_date, s.second_session_date
   FROM first_session f
   LEFT JOIN second_session s USING (member_id)
 ),


/* ============= 7b) NEW — second scheduled session date (for engagement) ============= */
second_session_scheduled AS (
 SELECT
   member_id,
   MIN(DATE(next_session_at)) AS second_session_scheduled_date
 FROM (
   SELECT
     ws.member_id,
     ws.next_session_at,
     ROW_NUMBER() OVER (
       PARTITION BY ws.member_id
       ORDER BY ws.next_session_at
     ) AS rn
   FROM `01_dbt_production_marts.fct_webapp_sessions` ws
   WHERE LOWER(ws.session_status) = 'scheduled'
     AND ws.next_session_at IS NOT NULL
 )
 WHERE rn = 2
 GROUP BY member_id
),


/* ============= 8) Partner inviters ============= */
partner_inviters AS (
 SELECT
   pe.user_id AS customer_uuid,
   MIN(DATE(pe.created_at)) AS partner_invited_date
 FROM `dbt-analytics-412206.01_dbt_production_marts.fct_product_events` pe
 WHERE pe.event_name IN ('invite_partner_complete', 'partner_form_filled')
   AND pe.user_id IS NOT NULL
 GROUP BY pe.user_id
),


/* ============= 9) Activation components ============= */
activation_components AS (
 SELECT
   m.subscription_id,
   m.member_id,
   m.customer_uuid,
   m.customer_id,
   m.subscriber_type,
   m.member_flag,
   m.subscription_created_at,
   m.subscription_canceled_at,


   /* MBG base logic (14 days OR 2 completed sessions) */
   CASE
     WHEN DATE_DIFF(
            IFNULL(DATE(m.subscription_canceled_at), CURRENT_DATE()),
            DATE(m.subscription_created_at),
            DAY
          ) > 14
       OR (
         SELECT COUNT(*)
         FROM `01_dbt_production_marts.fct_webapp_sessions` s
         WHERE s.member_id = m.member_id
           AND LOWER(s.session_status) = 'ended'
           AND DATE(s.session_ended_at)
                 BETWEEN DATE(m.subscription_created_at)
                     AND DATE_ADD(DATE(m.subscription_created_at), INTERVAL 14 DAY)
       ) >= 2
     THEN DATE_ADD(DATE(m.subscription_created_at), INTERVAL 15 DAY)
     ELSE NULL
   END AS base_mbg_date,
   fs.first_session_date,
   fs.second_session_date,             -- completed 2nd session
   sss.second_session_scheduled_date,  -- NEW scheduled 2nd session


   /* first significant activity */
   (
     SELECT MIN(apd.activity_date)
     FROM activity_per_day apd
     WHERE apd.customer_uuid = m.customer_uuid
       AND apd.has_significant_activity_flag = 1
       AND apd.activity_date BETWEEN DATE(m.subscription_created_at)
                                 AND IFNULL(DATE(m.subscription_canceled_at), CURRENT_DATE())
   ) AS first_significant_activity_date,


   pi.partner_invited_date AS invite_date,
   pi.partner_invited_date AS partner_form_date,
   pps.partner_first_seen_date


 FROM all_members m
 LEFT JOIN first_second_session fs ON fs.member_id = m.member_id
 LEFT JOIN second_session_scheduled sss ON sss.member_id = m.member_id  -- ★ added join
 LEFT JOIN partner_inviters pi ON pi.customer_uuid = m.customer_uuid
 LEFT JOIN partner_presence_by_subscription pps
   ON pps.subscription_id = m.subscription_id
  AND pps.customer_id = m.customer_id
),


/* ============= 9b) Activation components with MBG rule applied ============= */
activation_components_mbg AS (
 SELECT
   ac.*,
   CASE
     WHEN ac.base_mbg_date IS NOT NULL
      AND ac.customer_id IN (SELECT customer_id FROM matching_first_customers)
      AND ac.subscriber_type != 'Matching'
     THEN NULL
     ELSE ac.base_mbg_date
   END AS passed_mbg_date
 FROM activation_components ac
),


/* ============= 10) Activation dates () ============= */
activation_dates AS (
 SELECT
   a.*,


   /* NEW: engagement_date uses second *scheduled* session */
   CASE
     WHEN a.first_significant_activity_date IS NULL THEN a.second_session_scheduled_date
     WHEN a.second_session_scheduled_date IS NULL THEN a.first_significant_activity_date
     ELSE LEAST(a.first_significant_activity_date, a.second_session_scheduled_date)
   END AS engagement_date,


   /* activation_date logic updated accordingly */
   CASE
     /* Couples – Primary Member */
     WHEN a.subscriber_type = 'Couples' AND a.member_flag = 'Primary Member'
      AND a.passed_mbg_date IS NOT NULL
      AND a.first_session_date IS NOT NULL
      AND COALESCE(a.invite_date, a.partner_first_seen_date) IS NOT NULL
      AND (
            a.first_significant_activity_date IS NOT NULL
         OR a.second_session_scheduled_date IS NOT NULL
          )
     THEN GREATEST(
            CAST(a.passed_mbg_date AS TIMESTAMP),
            CAST(a.first_session_date AS TIMESTAMP),
            CAST(
              CASE
                WHEN a.first_significant_activity_date IS NULL THEN a.second_session_scheduled_date
                WHEN a.second_session_scheduled_date IS NULL THEN a.first_significant_activity_date
                ELSE LEAST(a.first_significant_activity_date, a.second_session_scheduled_date)
              END AS TIMESTAMP
            ),
            CAST(COALESCE(a.invite_date, a.partner_first_seen_date) AS TIMESTAMP)
          )


     /* Couples – Partner */
     WHEN a.subscriber_type = 'Couples' AND a.member_flag = 'Partner'
      AND a.passed_mbg_date IS NOT NULL
      AND COALESCE(a.partner_form_date, a.partner_first_seen_date, a.second_session_scheduled_date) IS NOT NULL
      AND a.first_session_date IS NOT NULL
      AND (
            a.first_significant_activity_date IS NOT NULL
         OR a.second_session_scheduled_date IS NOT NULL
          )
     THEN GREATEST(
            CAST(a.passed_mbg_date AS TIMESTAMP),
            CAST(a.first_session_date AS TIMESTAMP),
            CAST(
              CASE
                WHEN a.first_significant_activity_date IS NULL THEN a.second_session_scheduled_date
                WHEN a.second_session_scheduled_date IS NULL THEN a.first_significant_activity_date
                ELSE LEAST(a.first_significant_activity_date, a.second_session_scheduled_date)
              END AS TIMESTAMP
            ),
            CAST(COALESCE(a.partner_form_date, a.partner_first_seen_date, a.second_session_scheduled_date) AS TIMESTAMP)
          )


     /* Individuals */
     WHEN a.subscriber_type = 'Individuals'
      AND a.passed_mbg_date IS NOT NULL
      AND a.first_session_date IS NOT NULL
      AND (
            a.first_significant_activity_date IS NOT NULL
         OR a.second_session_scheduled_date IS NOT NULL
          )
     THEN GREATEST(
            CAST(a.passed_mbg_date AS TIMESTAMP),
            CAST(a.first_session_date AS TIMESTAMP),
            CAST(
              CASE
                WHEN a.first_significant_activity_date IS NULL THEN a.second_session_scheduled_date
                WHEN a.second_session_scheduled_date IS NULL THEN a.first_significant_activity_date
                ELSE LEAST(a.first_significant_activity_date, a.second_session_scheduled_date)
              END AS TIMESTAMP
            )
          )


     /* Matching */
     WHEN a.subscriber_type = 'Matching'
      AND a.passed_mbg_date IS NOT NULL
      AND a.first_session_date IS NOT NULL
      AND (
            a.first_significant_activity_date IS NOT NULL
         OR a.second_session_scheduled_date IS NOT NULL
          )
     THEN GREATEST(
            CAST(a.passed_mbg_date AS TIMESTAMP),
            CAST(a.first_session_date AS TIMESTAMP),
            CAST(
              CASE
                WHEN a.first_significant_activity_date IS NULL THEN a.second_session_scheduled_date
                WHEN a.second_session_scheduled_date IS NULL THEN a.first_significant_activity_date
                ELSE LEAST(a.first_significant_activity_date, a.second_session_scheduled_date)
              END AS TIMESTAMP
            )
          )


     /* Fallback */
     WHEN a.passed_mbg_date IS NOT NULL
      AND a.first_session_date IS NOT NULL
      AND (
            a.first_significant_activity_date IS NOT NULL
         OR a.second_session_scheduled_date IS NOT NULL
          )
     THEN GREATEST(
            CAST(a.passed_mbg_date AS TIMESTAMP),
            CAST(a.first_session_date AS TIMESTAMP),
            CAST(
              CASE
                WHEN a.first_significant_activity_date IS NULL THEN a.second_session_scheduled_date
                WHEN a.second_session_scheduled_date IS NULL THEN a.first_significant_activity_date
                ELSE LEAST(a.first_significant_activity_date, a.second_session_scheduled_date)
              END AS TIMESTAMP
            )
          )


     ELSE NULL
   END AS activation_date


 FROM activation_components_mbg a
),


 /* ============= 11) Daily spine (one row per day per member/sub) ============= */
 daily_spine AS (
   SELECT
     m.subscription_id,
     m.member_id,
     m.customer_uuid,
     d AS asof_date
   FROM all_members m
   CROSS JOIN UNNEST(
     GENERATE_DATE_ARRAY(
       GREATEST(DATE(m.subscription_created_at), (SELECT floor_date FROM params)),
       LEAST(IFNULL(DATE(m.subscription_canceled_at), CURRENT_DATE()), CURRENT_DATE())
     )
   ) AS d
 ),


 /* ============= 12) Daily windows & metrics per asof_date ============= */
 daily_state_calc AS (
   SELECT
     ds.subscription_id,
     ds.member_id,
     ds.customer_uuid,
     ds.asof_date,
     -- sessions in last 30 days
     EXISTS (
       SELECT 1
       FROM sessions_all_per_day sdp
       WHERE sdp.member_id = ds.member_id
         AND sdp.session_date BETWEEN DATE_SUB(ds.asof_date, INTERVAL 30 DAY) AND ds.asof_date
     ) AS had_any_session_last_30d,
     -- app activity in last 30 days
     EXISTS (
       SELECT 1
       FROM activity_per_day apd
       WHERE apd.customer_uuid = ds.customer_uuid
         AND apd.has_significant_activity_flag = 1
         AND apd.activity_date BETWEEN DATE_SUB(ds.asof_date, INTERVAL 30 DAY) AND ds.asof_date
     ) AS had_app_activity_last_30d,
     -- app activity today
     EXISTS (
       SELECT 1
       FROM activity_per_day apd
       WHERE apd.customer_uuid = ds.customer_uuid
         AND apd.has_significant_activity_flag = 1
         AND apd.activity_date = ds.asof_date
     ) AS had_significant_activity_today,
     -- last session date up to asof_date
     (
       SELECT MAX(sdp.session_date)
       FROM sessions_all_per_day sdp
       WHERE sdp.member_id = ds.member_id
         AND sdp.session_date <= ds.asof_date
     ) AS last_session_date,
     -- last app activity date up to asof_date
     (
       SELECT MAX(apd.activity_date)
       FROM activity_per_day apd
       WHERE apd.customer_uuid = ds.customer_uuid
         AND apd.has_significant_activity_flag = 1
         AND apd.activity_date <= ds.asof_date
     ) AS last_app_activity_date,
     -- total sessions up to asof_date
     (
       SELECT COALESCE(SUM(sdp.sessions_attended), 0)
       FROM sessions_all_per_day sdp
       WHERE sdp.member_id = ds.member_id
         AND sdp.session_date <= ds.asof_date
     ) AS total_sessions_to_date
   FROM daily_spine ds
 ),


 /* ============= 13) Attach member facts & compute true daily state ============= */
 with_member_facts AS (
   SELECT
     dsc.asof_date,
     dsc.member_id,
     dsc.customer_uuid,
     dsc.subscription_id,
     m.customer_id,
     m.email,
     m.full_name,
     m.member_plan_name     AS plan_name,
     m.member_plan_duration AS plan_duration,
     m.subscription_status,
     m.subscription_created_at,
     m.subscription_canceled_at,
     m.subscription_ended_at,
     m.member_utm_source,
     m.member_attribution_source,
     m.subscriber_type,
     m.member_flag,
     w.is_winback_subscription,
     dsc.had_any_session_last_30d,
     dsc.had_app_activity_last_30d,
     dsc.had_significant_activity_today,
     dsc.last_session_date,
     dsc.last_app_activity_date,
     dsc.total_sessions_to_date,
     CASE WHEN dsc.last_session_date IS NULL THEN NULL ELSE DATE_DIFF(dsc.asof_date, dsc.last_session_date, DAY) END AS days_since_session,
     CASE WHEN dsc.last_app_activity_date IS NULL THEN NULL ELSE DATE_DIFF(dsc.asof_date, dsc.last_app_activity_date, DAY) END AS days_since_app,
     ad.activation_date,
     ad.passed_mbg_date,
     ad.first_session_date,
     ad.second_session_date,
     ad.invite_date,
     ad.partner_form_date,
     ad.partner_first_seen_date,
     ad.first_significant_activity_date,
     CASE WHEN ad.activation_date IS NOT NULL AND DATE(ad.activation_date) <= dsc.asof_date THEN TRUE ELSE FALSE END AS is_activated_by_today,
     CASE WHEN dsc.had_significant_activity_today OR dsc.total_sessions_to_date >= 2 THEN TRUE ELSE FALSE END AS is_active_member_today,
     -- user_state_today: state as of that date
     CASE
       WHEN dsc.asof_date = DATE(m.subscription_created_at)
            AND NOT dsc.had_any_session_last_30d
            AND NOT dsc.had_app_activity_last_30d
         THEN 'joined_today'
       WHEN ad.activation_date IS NOT NULL
            AND dsc.asof_date = DATE(ad.activation_date)
         THEN 'activation'
       WHEN dsc.had_app_activity_last_30d AND dsc.had_any_session_last_30d
         THEN 'ritual_active'
       WHEN NOT dsc.had_app_activity_last_30d AND dsc.had_any_session_last_30d
         THEN 'session_only'
       WHEN dsc.had_app_activity_last_30d AND NOT dsc.had_any_session_last_30d
         THEN 'app_only'
       WHEN NOT dsc.had_app_activity_last_30d AND NOT dsc.had_any_session_last_30d
         THEN 'ghost'
       ELSE 'unknown'
     END AS user_state_today
   FROM daily_state_calc dsc
   JOIN all_members m
     ON m.subscription_id = dsc.subscription_id
    AND m.member_id       = dsc.member_id
    AND m.customer_uuid   = dsc.customer_uuid
   LEFT JOIN winbacks w
     ON w.subscription_id = m.subscription_id
   LEFT JOIN activation_dates ad
     ON ad.subscription_id = m.subscription_id
    AND ad.member_id       = m.member_id
    AND ad.customer_uuid   = m.customer_uuid
 ),


 /* ============= 14) Churn & activity-loss flags ============= */
 with_statuses AS (
   SELECT
     mf.*,
     CASE WHEN mf.subscription_canceled_at IS NOT NULL AND mf.asof_date = DATE(mf.subscription_canceled_at) THEN TRUE ELSE FALSE END AS is_churn_day,
     CASE WHEN mf.subscription_canceled_at IS NOT NULL AND mf.asof_date = DATE(mf.subscription_canceled_at) THEN mf.had_any_session_last_30d ELSE NULL END AS had_session_last_30d_at_churn,
     CASE WHEN mf.subscription_canceled_at IS NOT NULL AND mf.asof_date = DATE(mf.subscription_canceled_at) THEN mf.had_app_activity_last_30d ELSE NULL END AS had_app_activity_last_30d_at_churn,
     -- ever session_only before churn
     EXISTS (
       SELECT 1
       FROM with_member_facts hist
       WHERE hist.member_id = mf.member_id
         AND hist.subscription_id = mf.subscription_id
         AND mf.subscription_canceled_at IS NOT NULL
         AND hist.asof_date < DATE(mf.subscription_canceled_at)
         AND hist.had_any_session_last_30d = TRUE
         AND hist.had_app_activity_last_30d = FALSE
     ) AS ever_session_only_before_churn,
     -- ever ritual_active before today
     EXISTS (
       SELECT 1
       FROM with_member_facts hist
       WHERE hist.member_id = mf.member_id
         AND hist.subscription_id = mf.subscription_id
         AND hist.asof_date < mf.asof_date
         AND hist.had_any_session_last_30d = TRUE
         AND hist.had_app_activity_last_30d = TRUE
     ) AS ever_ritual_active_before_today,
     -- activity loss: previously ritual_active AND now >=30d without app activity, pre-churn
     CASE
       WHEN EXISTS (
              SELECT 1
              FROM with_member_facts hist
              WHERE hist.member_id = mf.member_id
                AND hist.subscription_id = mf.subscription_id
                AND hist.asof_date < mf.asof_date
                AND hist.had_any_session_last_30d = TRUE
                AND hist.had_app_activity_last_30d = TRUE
            )
        AND (mf.last_app_activity_date IS NULL OR DATE_DIFF(mf.asof_date, mf.last_app_activity_date, DAY) >= 30)
        AND NOT (mf.subscription_canceled_at IS NOT NULL AND mf.asof_date >= DATE(mf.subscription_canceled_at))
       THEN TRUE ELSE FALSE
     END AS is_activity_loss
   FROM with_member_facts mf
 ),


 /* ============= 15) Track previous state & last state change date ============= */
 with_prev_state AS (
   SELECT
     ws.*,
     LAG(ws.user_state_today) OVER (PARTITION BY ws.member_id, ws.subscription_id ORDER BY ws.asof_date) AS prev_state
   FROM with_statuses ws
 ),
 with_state_change AS (
   SELECT
     wps.*,
     CASE WHEN wps.prev_state IS DISTINCT FROM wps.user_state_today THEN TRUE ELSE FALSE END AS is_state_change
   FROM with_prev_state wps
 ),
 with_last_change AS (
   SELECT
     wsc.*,
     MAX(CASE WHEN wsc.is_state_change THEN wsc.asof_date END)
       OVER (PARTITION BY wsc.member_id, wsc.subscription_id ORDER BY wsc.asof_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
       AS last_state_change_date
   FROM with_state_change wsc
 ),


 /* ============= 16) Final daily output ============= */
 final AS (
   SELECT
     TIMESTAMP(asof_date) AS change_date,
     member_id,
     customer_uuid,
     subscription_id,
     customer_id,
     email,
     full_name,
     plan_name,
     plan_duration,
     subscription_status,
     CAST(subscription_created_at AS TIMESTAMP) AS subscription_created_at,
     CAST(subscription_canceled_at AS TIMESTAMP) AS subscription_canceled_at,
     CAST(subscription_ended_at AS TIMESTAMP) AS subscription_ended_at,
     member_flag,
     subscriber_type,
     member_utm_source,
     member_attribution_source,
     is_winback_subscription,
     had_any_session_last_30d,
     had_app_activity_last_30d,
     had_significant_activity_today,
     CAST(last_session_date AS TIMESTAMP) AS last_session_date,
     CAST(last_app_activity_date AS TIMESTAMP) AS last_app_activity_date,
     days_since_session,
     days_since_app,
     total_sessions_to_date,
     CAST(activation_date AS TIMESTAMP) AS activation_date,
     is_activated_by_today,
     CAST(passed_mbg_date AS TIMESTAMP) AS passed_mbg_date,
     CAST(first_session_date AS TIMESTAMP) AS first_session_date,
     CAST(second_session_date AS TIMESTAMP) AS second_session_date,
     CAST(invite_date AS TIMESTAMP) AS invite_date,
     CAST(partner_form_date AS TIMESTAMP) AS partner_form_date,
     CAST(partner_first_seen_date AS TIMESTAMP) AS partner_first_seen_date,
     CAST(first_significant_activity_date AS TIMESTAMP) AS first_significant_activity_date,
     is_active_member_today,
     user_state_today,
     is_activity_loss,
     -- churn_type
     CASE
       WHEN is_churn_day THEN
         CASE
           WHEN had_session_last_30d_at_churn = TRUE AND had_app_activity_last_30d_at_churn = FALSE
             THEN 'session_only_churn'
           WHEN is_activated_by_today = TRUE
             THEN 'standard_churn(activated_members)'
           WHEN is_activated_by_today = FALSE AND COALESCE(ever_session_only_before_churn, FALSE) = FALSE
             THEN 'intent_churn'
           ELSE NULL
         END
       ELSE NULL
     END AS churn_type,
     -- mbg_flag_at_churn
     CASE
       WHEN is_churn_day THEN
         CASE
           WHEN DATE_DIFF(DATE(subscription_canceled_at), DATE(subscription_created_at), DAY) <= 14
                AND total_sessions_to_date < 2 THEN 'MBG'
           ELSE 'No MBG'
         END
       ELSE NULL
     END AS mbg_flag_at_churn,
     -- churn_bucket_at_churn
     CASE
       WHEN is_churn_day THEN
         CASE
           WHEN DATE_DIFF(DATE(subscription_canceled_at), DATE(subscription_created_at), DAY) <= 14
                AND total_sessions_to_date < 2 THEN 'MBG'
           WHEN DATE_DIFF(DATE(subscription_canceled_at), DATE(subscription_created_at), DAY) < 30 THEN '<30d'
           WHEN DATE_DIFF(DATE(subscription_canceled_at), DATE(subscription_created_at), DAY) < 60 THEN '<60d'
           WHEN DATE_DIFF(DATE(subscription_canceled_at), DATE(subscription_created_at), DAY) < 90 THEN '<90d'
           WHEN DATE_DIFF(DATE(subscription_canceled_at), DATE(subscription_created_at), DAY) > 180 THEN '>180d'
           ELSE '90-180d'
         END
       ELSE NULL
     END AS churn_bucket_at_churn,
     is_churn_day,
     TIMESTAMP(last_state_change_date) AS last_state_change_date
   FROM with_last_change
   ORDER BY asof_date, member_id, subscription_id
 )


SELECT DISTINCT * FROM final

