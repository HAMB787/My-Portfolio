with all_dates AS (
  SELECT date
  FROM UNNEST(GENERATE_DATE_ARRAY('2024-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date
)

-- Step 2: Get primary invoice customers with valid, non-test, paid invoices
,invoice_customers AS (
  SELECT
    i.created_at,
    i.customer_id,
    m.id AS user_id,
    i.customer_uuid,
    m.email,
    m.full_name,
    i.subscription_id,
    i.subscription_current_period_start_at,
    i.subscription_current_period_end_at,
    i.subscription_created_at,
    i.subscription_ended_at
  FROM `01_dbt_production_marts.fct_invoices` i
  INNER JOIN `01_dbt_production_marts.dim_member` m
    ON i.customer_uuid = m.uuid
  WHERE charge_is_paid = TRUE
    AND charge_failure_code IS NULL
    AND invoice_status = 'paid'
    AND invoice_total > 500
    AND NOT (
      LOWER(i.customer_email) LIKE '%ritual%' OR
      LOWER(i.customer_email) LIKE '%test%' OR
      LOWER(i.customer_email) LIKE '%+rm%'
    )
  GROUP BY ALL
)

-- Step 3: Get secondary members (partners) linked via primary_member_id
,add_secondary_members AS (
  SELECT
    p.created_at,
    p.customer_id,
    s.id AS user_id,
    s.uuid AS customer_uuid,
    s.email,
    s.full_name,
    p.subscription_id,
    p.subscription_current_period_start_at,
    p.subscription_current_period_end_at,
    p.subscription_created_at,
    p.subscription_ended_at
  FROM invoice_customers p
  INNER JOIN `01_dbt_production_marts.dim_member` s
    ON p.user_id = s.primary_member_id
  GROUP BY ALL
)

-- Step 4: Union both primary and partner members
,all_members AS (
  SELECT *, 'Primary Member' AS flag FROM invoice_customers
  UNION DISTINCT
  SELECT *, 'Partner' AS flag FROM add_secondary_members
)

-- Step 5: Track each member's journey with subscription start/end dates
,primary_member_journey AS (
  SELECT
    customer_id,
    m.id as user_id,
    customer_uuid,
    customer_email as email,
    subscription_id,
    DATE(i.subscription_created_at) AS member_start_date,
    COALESCE(DATE(i.subscription_ended_at), CURRENT_DATE())
     AS member_end_date
  FROM `01_dbt_production_marts.fct_subscriptions` i
  INNER JOIN `01_dbt_production_marts.dim_member` m
    ON i.customer_uuid = m.uuid
  GROUP BY ALL
)

,secondary_member_journey AS (
  SELECT
    p.customer_id,
    s.id AS user_id,
    s.uuid AS customer_uuid,
    s.email,
    p.subscription_id,
    p.member_start_date,
    p.member_end_date
  FROM primary_member_journey p
  INNER JOIN `01_dbt_production_marts.dim_member` s
    ON p.user_id = s.primary_member_id
  GROUP BY ALL
)

,member_journey AS (
  SELECT * FROM primary_member_journey
  UNION DISTINCT
  SELECT *  FROM secondary_member_journey
)

-- Step 6: Track expert change events per user
,all_members_per_expert AS (
  SELECT
    p.created_at,
    DATE(DATE_TRUNC(p.created_at, WEEK(MONDAY))) AS week_start_date,
    CASE
      WHEN JSON_VALUE(payload, '$.prev_expert') = 'expert@heyritual.com' THEN DATE(p.created_at)
      ELSE DATE(p.created_at) + 1
    END AS start_date,
    COALESCE(
      LEAD(DATE(p.created_at)) OVER (PARTITION BY p.user_id ORDER BY p.created_at ASC),
      CASE WHEN JSON_VALUE(payload, '$.reason') = 'subscription cancelled' THEN DATE(p.created_at) ELSE CURRENT_DATE() END
    ) AS end_date,
    p.user_id,
    p.user_email,
    JSON_VALUE(payload, '$.expert_id') AS expert_id,
    JSON_VALUE(payload, '$.expert_email') AS expert_email,
    JSON_VALUE(payload, '$.prev_expert') AS prev_expert,
    JSON_VALUE(payload, '$.reason') AS reason
  FROM `01_dbt_production_marts.fct_product_events` p
  WHERE event_name = 'expert_changed'
)

-- Step 7: Filter only valid expert assignments
,relevant_records_per_expert AS (
  SELECT * FROM all_members_per_expert
  WHERE expert_email <> 'expert@heyritual.com'
)

-- Step 8: Add customer + membership info to expert assignments
,paying_members AS (
  SELECT
    -- e.*,
    p.created_at,
    p.customer_uuid as user_id,
    p.email as user_email,
    p.customer_id,
    p.subscription_id,
    DATE(p.subscription_current_period_start_at) AS subscription_current_period_start_at,
    DATE(p.subscription_current_period_end_at) AS subscription_current_period_end_at,
    DATE_DIFF(p.subscription_current_period_end_at, p.subscription_current_period_start_at, DAY) AS revenue_days,
    COUNT(DISTINCT p.user_id) OVER (PARTITION BY customer_id) AS members_per_invoice
  FROM all_members p
  -- INNER JOIN relevant_records_per_expert e
  --   ON e.user_id = p.customer_uuid
  --   AND DATE(e.created_at) BETWEEN DATE(p.subscription_current_period_start_at) AND DATE(p.subscription_current_period_end_at) - 1
)

-- Step 9: Pull and deduplicate completed sessions
-- all_completed_sessions AS (
--   SELECT
--     created_at,
--     DATE(created_at) AS session_date,
--     user_id,
--     user_email,
--     JSON_VALUE(payload, '$.expert_email') AS expert_email,
--     JSON_VALUE(payload, '$.expert_uuid') AS expert_uuid,
--     JSON_VALUE(payload, '$.session_uuid') AS session_uuid,
--     JSON_VALUE(payload, '$.last_meeting_status') AS last_meeting_status,
--     JSON_VALUE(payload, '$.meeting_type') AS meeting_type,
--     JSON_VALUE(payload, '$.next_session_number') AS next_session_number,
--     -- LAG(created_at) OVER (
--     --   PARTITION BY user_id, JSON_VALUE(payload, '$.expert_uuid'), DATE(created_at)
--     --   ORDER BY created_at
--     -- ) AS prev_created_at
--     ROW_NUMBER() OVER (PARTITION BY DATE(created_at), user_id, JSON_VALUE(payload, '$.expert_uuid') ORDER BY created_at) AS session_row,
--   FROM {{ ref('fct_product_events') }}
--   WHERE event_name = 'program_complete_session'
-- ),

-- deduped_completed_sessions AS (
--   SELECT *
--   FROM all_completed_sessions
--   where session_row = 1
--   -- WHERE prev_created_at IS NULL OR TIMESTAMP_DIFF(created_at, prev_created_at, MINUTE) > 60
-- ),


,deduped_completed_sessions as (SELECT
s.next_session_at as created_at,
m.email as user_email,m.uuid as user_id,
e.email as expert_email,e.uuid as expert_uuid,
s.uuid as session_uuid,
s.next_session_event_id as unique_session_id,
s.next_session_at as session_date,
s.session_status as last_meeting_status,
s.session_type as meeting_type
FROM `dbt-analytics-412206.01_dbt_production_marts.fct_webapp_sessions` s
left join `01_dbt_production_marts.dim_member` m on
s.member_id=m.id
left join `01_dbt_production_marts.dim_expert` e on
s.expert_id=e.id
where
 NOT (
      LOWER(m.email) LIKE '%ritual%' OR
      LOWER(m.email) LIKE '%test%' OR
      LOWER(m.email) LIKE '%+rm%'
    )
and session_status ='Ended'
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY s.uuid
  ORDER BY s.next_session_at ASC
) = 1
)

-- Step 10: Pull and deduplicate canceled sessions
,cancelled_sessions AS (
  WITH base_cancelled AS (
    SELECT
      created_at,
      DATE(created_at) AS session_date,
      user_id,
      user_email,
      JSON_VALUE(payload, '$.meeting_id') AS meeting_id,
      JSON_VALUE(payload, '$.expert_uuid') AS expert_uuid,
      JSON_VALUE(payload, '$.expert_email') AS expert_email,
      JSON_VALUE(payload, '$.canceled_by') AS session_canceled_by,
      JSON_VALUE(payload, '$.hours_from_session') AS hours_from_session,
      JSON_VALUE(payload, '$.time_variable') AS time_variable,
      JSON_VALUE(payload, '$.meeting_type') AS meeting_type,
      -- LAG(created_at) OVER (
      --   PARTITION BY user_id, JSON_VALUE(payload, '$.expert_uuid'), DATE(created_at)
      --   ORDER BY created_at
      -- ) AS prev_created_at
      ROW_NUMBER() OVER (PARTITION BY DATE(created_at), user_id, JSON_VALUE(payload, '$.expert_uuid') ORDER BY created_at) AS session_row,
    FROM `01_dbt_production_marts.fct_product_events`
    WHERE event_name = 'canceled_meeting'
  )
  SELECT *
  FROM base_cancelled
  -- WHERE prev_created_at IS NULL OR TIMESTAMP_DIFF(created_at, prev_created_at, MINUTE) > 60
  where session_row = 1
)

-- Step 11: Create date-wise member-expert records using all_dates
,all_members_start_end AS (
  SELECT a.date, mj.*
  FROM all_dates a
  LEFT JOIN member_journey mj
    ON a.date BETWEEN mj.member_start_date AND mj.member_end_date-1
  INNER join paying_members p
    on mj.customer_uuid = p.user_id
  group by all
)

,member_expert_snaphot as (
  SELECT
    me.uuid as member_uuid,
    me.email as member_email,
    expert_id,
    e.uuid as expert_uuid,
    e.email as expert_email,
    expert_full_name, 
    dbt_updated_at,
    date(dbt_valid_from) as dbt_valid_from,
    COALESCE(date(dbt_valid_to),current_date()) as dbt_valid_to,
    FROM `dbt-analytics-412206.01_dbt_production_snapshots.dim_member_snapshot` me
    left join `01_dbt_production_marts.dim_expert` e on
    me.expert_id=e.id
  group by all
)

-- Step 12: Join members with expert records, sessions, and cancellations
,expert_details AS (
  SELECT
    a.date,
    a.member_start_date,
    a.member_end_date,
    a.customer_id,
    a.subscription_id,
    COALESCE(a.customer_uuid, r.user_id) AS user_id,
    COALESCE(a.email, r.user_email) AS user_email,
    CASE WHEN m.is_primary THEN 'Primary' ELSE 'Partner' END AS member_flag,
    COALESCE(r.created_at,me.dbt_updated_at) as created_at,
    COALESCE(start_date,me.dbt_valid_from) as start_date,
    COALESCE(end_date,me.dbt_valid_to) as end_date,
    e.id,
    COALESCE(r.expert_id,me.expert_uuid) as expert_id,
    COALESCE(r.expert_email,me.expert_email) as expert_email,
    e.assigned_supervisor_id,
    e.assigned_supervisor_email,
CASE WHEN (DATE_DIFF(a.date, COALESCE(start_date,me.dbt_valid_from), DAY) + 1) < 0 THEN 0 ELSE DATE_DIFF(a.date, COALESCE(start_date,me.dbt_valid_from), DAY) + 1 END AS days_with_expert,
    r.reason AS expert_changed_reason,
    s.session_uuid AS session_id,
    s.unique_session_id,
    s.last_meeting_status AS meeting_status,
    s.meeting_type,
    c.meeting_id AS cancelled_session_id,
    c.session_canceled_by,
    c.time_variable AS cancelled_time_variable,
    c.meeting_type AS cancelled_meeting_type,
    CASE WHEN currency = 'NIS' THEN ROUND(e.hourly_rate / 3.5, 2) ELSE e.hourly_rate END AS expert_hourly_rate_usd,
    -- Ranking to dedupe session_id
    ROW_NUMBER() OVER (PARTITION BY a.date, COALESCE(a.customer_uuid, r.user_id), r.expert_id, s.session_uuid ORDER BY c.meeting_id) AS session_row,
    -- Ranking to dedupe cancelled_session_id
    ROW_NUMBER() OVER (PARTITION BY a.date, COALESCE(a.customer_uuid, r.user_id), r.expert_id, c.meeting_id ORDER BY s.session_uuid) AS cancel_row

  FROM all_members_start_end a
  LEFT JOIN relevant_records_per_expert r
    ON a.customer_uuid = r.user_id AND a.date BETWEEN r.start_date AND r.end_date
  LEFT JOIN member_expert_snaphot me
    ON a.customer_uuid = me.member_uuid AND a.date BETWEEN me.dbt_valid_from AND me.dbt_valid_to
  LEFT JOIN deduped_completed_sessions s
    ON a.date = DATE(s.created_at) AND a.customer_uuid = s.user_id
    -- and r.expert_id = s.expert_uuid
  LEFT JOIN cancelled_sessions c
    ON a.date = DATE(c.created_at) AND a.customer_uuid = c.user_id
    and r.expert_email = s.expert_email
  LEFT JOIN `01_dbt_production_marts.dim_member` m
    ON a.customer_uuid = m.uuid
  LEFT JOIN `01_dbt_production_marts.dim_expert` e
    ON r.expert_id = e.uuid
)

-- Step 13: Allocate revenue per day per member
,revenue_per_day AS (
  SELECT
    DATE(i.created_at) AS created_at,
    p.user_id,
    p.user_email,
    p.customer_id,
    p.subscription_id,
    DATE(i.subscription_current_period_start_at) AS subscription_current_period_start_at,
    DATE(i.subscription_current_period_end_at) AS subscription_current_period_end_at,
    p.members_per_invoice,
    p.revenue_days,
    SAFE_DIVIDE((i.invoice_total / 100), members_per_invoice) AS revenue_per_member,
    SAFE_DIVIDE(SAFE_DIVIDE((i.invoice_total / 100), members_per_invoice),revenue_days) AS revenue_per_day_usd
  FROM paying_members p
  FULL JOIN `01_dbt_production_marts.fct_invoices` i
    ON p.customer_id = i.customer_id
    and p.subscription_id = i.subscription_id
    and p.created_at =i.created_at
    WHERE charge_is_paid = TRUE
    AND charge_failure_code IS NULL
    AND invoice_status = 'paid'
    AND invoice_total > 500
    AND NOT (
      LOWER(i.customer_email) LIKE '%ritual%' OR
      LOWER(i.customer_email) LIKE '%test%' OR
      LOWER(i.customer_email) LIKE '%+rm%'
    )
  GROUP BY ALL
)

-- Step 14: Monthly expert-level compensation values
,expert_monthly_compensation AS (
  SELECT
    c.expert_id,
    c.full_name,
    PARSE_DATE('%Y-%B', year_month) AS date_month,
    SUM(CASE WHEN e.currency = 'NIS' THEN ROUND(total_compensation / 3.5, 2) ELSE total_compensation END) AS total_compensation,
    SUM(CASE WHEN e.currency = 'NIS' THEN ROUND(total_compensation_with_overhead / 3.5, 2) ELSE total_compensation_with_overhead END) AS total_compensation_with_overhead
  FROM `dbt-analytics-412206.01_dbt_production_marts.fct_expert_compensations` c
  LEFT JOIN `01_dbt_production_marts.dim_expert` e ON e.id = c.expert_id
  WHERE report_status IN ('Processed')
  GROUP BY ALL
)

-- Step 15: Count monthly expert sessions (completed + qualified cancelled)
,expert_sessions AS (
  SELECT
    id AS expert_id,
    expert_email,
    DATE_TRUNC(date, MONTH) AS date_month,
    COUNT(DISTINCT CASE WHEN session_id IS NOT NULL THEN session_id END) +
    COUNT(DISTINCT CASE WHEN session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session' and upper(cancelled_meeting_type)='INDIVIDUAL' THEN cancelled_session_id END)+
    COUNT(DISTINCT CASE WHEN session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session' and upper(cancelled_meeting_type)='COUPLES' THEN cancelled_session_id END)*2
     AS expert_total_paid_sessions
  FROM expert_details
  GROUP BY 1, 2, 3
)

-- Step 16: Compute per-session rate by compensation model
,session_rate_by_compensation_method AS (
  SELECT
    e.expert_id,
    e.date_month,
    c.total_compensation,
    c.total_compensation_with_overhead,
    e.expert_total_paid_sessions as expert_total_paid_sessions_monthly,
    ROUND(SAFE_DIVIDE(c.total_compensation_with_overhead, e.expert_total_paid_sessions), 2) AS per_session_rate,
    ROUND(SAFE_DIVIDE(c.total_compensation, e.expert_total_paid_sessions), 2) AS per_session_rate_wo_overhead
  FROM expert_sessions e
  FULL JOIN expert_monthly_compensation c
    ON e.expert_id = c.expert_id AND e.date_month = c.date_month
)

-- Step 17: Enrich each expert-day-member record with compensation model comparisons & Revenue per member per day
,final AS (
  SELECT
    e.*,
    c.expert_total_paid_sessions_monthly,
    case when e.expert_id IS NULL then 0 else (COUNT(DISTINCT e.user_id) OVER (PARTITION BY date, e.expert_id)) end AS active_members_per_expert,
    CASE
      WHEN session_id IS NOT NULL AND session_row =1 AND session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session' THEN ROUND((expert_hourly_rate_usd / 3), 2) * 2
      WHEN session_id IS NOT NULL AND session_row =1 OR (session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session') THEN ROUND((expert_hourly_rate_usd / 3), 2)
    END AS session_rate_by_hourly_method,
    CASE
      WHEN session_id IS NOT NULL AND session_row =1 AND session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session' THEN per_session_rate * 2
      WHEN session_id IS NOT NULL AND session_row =1 OR (session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session') THEN per_session_rate
    END AS session_rate_by_compensation_method,
    CASE
      WHEN session_id IS NOT NULL AND session_row =1 AND session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session' THEN per_session_rate_wo_overhead * 2
      WHEN session_id IS NOT NULL AND session_row =1 OR (session_canceled_by = 'Member' AND cancelled_time_variable = 'Within 24 hours of session') THEN per_session_rate_wo_overhead
    END AS session_rate_wo_overhead_by_compensation_method,
    MAX(days_with_expert) OVER (PARTITION BY start_date, e.user_id, expert_email) AS total_days_with_expert,
    COUNT(DISTINCT session_id) OVER (PARTITION BY e.user_id, expert_email) AS total_sessions_with_expert,
    COUNT(DISTINCT CASE WHEN meeting_type <> 'Matching' THEN session_id END) OVER (PARTITION BY e.user_id, expert_email) AS total_session_with_expert_exl_matching,
    COUNT(DISTINCT session_id) OVER (PARTITION BY e.user_id, expert_email, DATE_TRUNC(date, MONTH)) AS total_session_with_expert_in_month,
    COUNT(DISTINCT session_id) OVER (PARTITION BY e.user_id, expert_email, DATE_TRUNC(date, WEEK(MONDAY))) AS total_session_with_expert_in_week
  FROM expert_details e
  LEFT JOIN session_rate_by_compensation_method c
    ON e.id = c.expert_id AND DATE(DATE_TRUNC(e.date, MONTH)) = c.date_month
  where NOT (
      LOWER(user_email) LIKE '%ritual%' OR
      LOWER(user_email) LIKE '%test%' OR
      LOWER(user_email) LIKE '%+rm%'
    )
)

,final_with_rownum AS (
  SELECT
    f.*,
    r.revenue_per_day_usd,
    ROW_NUMBER() OVER (
      PARTITION BY f.user_id, f.subscription_id, f.date
      ORDER BY f.created_at -- or any other field that makes sense
    ) AS row_num
  FROM final f
  LEFT JOIN revenue_per_day r
    ON f.user_id = r.user_id
    AND f.subscription_id = r.subscription_id
    AND f.date BETWEEN r.subscription_current_period_start_at
                   AND r.subscription_current_period_end_at - 1
)


SELECT
  f.* EXCEPT(revenue_per_day_usd, row_num)
  ,CASE
    WHEN row_num = 1 THEN ROUND(revenue_per_day_usd, 2)
    ELSE NULL
  END AS revenue_per_day_usd
FROM
final_with_rownum f