with 

module_part_assigned AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY expert_uuid, member_uuid, part_cms_id ORDER BY created_at) AS rnk
    FROM {{ ref('stg_segment_backend_members_prod__module_part_assigned') }}
    WHERE created_at < '{{ var('no_code_switch') }}'
),
module_part_assigned_new AS (
    SELECT *,
        ROW_NUMBER() OVER(
            PARTITION BY 
            JSON_EXTRACT_SCALAR(payload, '$.expert_uuid'), 
            JSON_EXTRACT_SCALAR(payload, '$.member_uuid'), 
            JSON_EXTRACT_SCALAR(payload, '$.part_cms_id') 
            ORDER BY created_at) AS rnk
    FROM {{ ref('stg_pubsub__events') }}
    WHERE created_at >= '{{ var('no_code_switch') }}'
        AND event_name = 'module_part_assigned'
),
module_growthwork_complete AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY expert_uuid, member_uuid, growthwork_id ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_segment_backend_experts_prod__module_growthwork_complete') }}
    WHERE created_at < '{{ var('no_code_switch') }}'
),
module_growthwork_complete_new AS (
    SELECT *,
        ROW_NUMBER() OVER(
            PARTITION BY 
            JSON_EXTRACT_SCALAR(payload, '$.expert_uuid'), 
            JSON_EXTRACT_SCALAR(payload, '$.member_uuid'), 
            JSON_EXTRACT_SCALAR(payload, '$.growthwork_id') 
            ORDER BY created_at DESC) AS rnk
    FROM {{ ref('stg_pubsub__events') }}
    WHERE created_at >= '{{ var('no_code_switch') }}'
        AND event_name = 'module_growthwork_complete'
),
dim_growthwork AS (SELECT * FROM {{ ref('dim_growthwork') }}),
members AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_member') }}),
experts AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_expert') }}),

member_growthworks AS (SELECT * FROM {{ ref('stg_postgre_rds__webapp_membergrowthwork_no_type') }}),
wisita_medias AS (SELECT * FROM {{ ref('stg_wistia__medias') }}),


part_assigned_before_dedup AS (

    SELECT 
        P.id,
        P.created_at AS part_assigned_at,
        P.event_name,
        CASE
            WHEN P.expert_email = 'expert@heyritual.com' AND E.email IS NOT NULL THEN E.email
            ELSE P.expert_email
        END AS expert_email,
        CASE
            WHEN P.expert_email = 'expert@heyritual.com' AND E.email IS NOT NULL THEN E.uuid
            ELSE P.expert_uuid
        END AS expert_uuid,
        P.member_email,
        P.member_uuid,
        GW.growthwork_id,
        GW.growthwork_order,
        GW.growthwork_title,
        GW.growthwork_description,
        GW.growthwork_type,
        GW.part_id,
        GW.part_order,
        GW.part_description,
        GW.part_goal,
        GW.pathway_id,
        GW.pathway_name,
        GW.pathway_description,
        GW.pathway_goal
    FROM module_part_assigned AS P
    LEFT JOIN dim_growthwork AS GW ON CAST(P.part_cms_id AS STRING) = GW.id
    LEFT JOIN members AS M ON P.member_uuid = M.uuid
    LEFT JOIN experts AS E ON M.expert_id = E.id    
    WHERE rnk = 1

    UNION ALL

    SELECT 
        P.id,
        P.created_at AS part_assigned_at,
        P.event_name,
        CASE
            WHEN JSON_EXTRACT_SCALAR(P.payload, '$.expert_email') = 'expert@heyritual.com' AND E.email IS NOT NULL THEN E.email
            ELSE JSON_EXTRACT_SCALAR(P.payload, '$.expert_email')
        END AS expert_email,
        CASE 
            WHEN JSON_EXTRACT_SCALAR(P.payload, '$.expert_email') = 'expert@heyritual.com' AND E.email IS NOT NULL THEN E.uuid
            ELSE JSON_EXTRACT_SCALAR(P.payload, '$.expert_uuid')
        END AS expert_uuid,
        JSON_EXTRACT_SCALAR(P.payload, '$.member_email') AS member_email,
        JSON_EXTRACT_SCALAR(P.payload, '$.member_uuid') AS member_uuid,
        GW.growthwork_id,
        GW.growthwork_order,
        GW.growthwork_title,
        GW.growthwork_description,
        GW.growthwork_type,
        GW.part_id,
        GW.part_order,
        GW.part_description,
        GW.part_goal,
        GW.pathway_id,
        GW.pathway_name,
        GW.pathway_description,
        GW.pathway_goal
    FROM module_part_assigned_new AS P
    LEFT JOIN dim_growthwork AS GW ON CAST(JSON_EXTRACT_SCALAR(P.payload, '$.part_cms_id') AS STRING) = GW.id
    LEFT JOIN members AS M ON JSON_EXTRACT_SCALAR(P.payload, '$.member_uuid') = M.uuid
    LEFT JOIN experts AS E ON M.expert_id = E.id      
    WHERE rnk = 1


),

part_assigned AS (

    SELECT *
    FROM part_assigned_before_dedup
    QUALIFY ROW_NUMBER() OVER(PARTITION BY expert_uuid, member_uuid, part_id ORDER BY part_assigned_at) = 1 -- we do this to avoid old to new flow transition duplications

),

growthwork_completed_before_dedup AS (

    SELECT 
        C.id,
        C.created_at AS growthwork_completed_at,
        C.event_name,    
        C.expert_email,
        C.expert_uuid,
        C.member_email,  
        C.member_uuid,
        GW.growthwork_id,
        GW.growthwork_order,
        GW.growthwork_title,
        GW.growthwork_description,
        GW.growthwork_type,
        GW.part_id,
        GW.part_order,
        GW.part_description,
        GW.part_goal,
        GW.pathway_id,
        GW.pathway_name,
        GW.pathway_description,
        GW.pathway_goal
    FROM module_growthwork_complete AS C 
    LEFT JOIN dim_growthwork AS GW ON C.growthwork_id = GW.id
    WHERE C.rnk = 1

    UNION ALL

    SELECT 
        C.id,
        C.created_at AS growthwork_completed_at,
        C.event_name,
        JSON_EXTRACT_SCALAR(C.payload, '$.expert_email') AS expert_email,
        JSON_EXTRACT_SCALAR(C.payload, '$.expert_uuid') AS expert_uuid,
        JSON_EXTRACT_SCALAR(C.payload, '$.member_email') AS member_email,    
        JSON_EXTRACT_SCALAR(C.payload, '$.member_uuid') AS member_uuid,    
        GW.growthwork_id,
        GW.growthwork_order,
        GW.growthwork_title,
        GW.growthwork_description,
        GW.growthwork_type,
        GW.part_id,
        GW.part_order,
        GW.part_description,
        GW.part_goal,
        GW.pathway_id,
        GW.pathway_name,
        GW.pathway_description,
        GW.pathway_goal
    FROM module_growthwork_complete_new AS C 
    LEFT JOIN dim_growthwork AS GW ON JSON_EXTRACT_SCALAR(C.payload, '$.growthwork_id') = GW.id
    WHERE C.rnk = 1

    UNION ALL

    SELECT 
        C.id,
        C.created_at AS growthwork_completed_at,
        'growthwork_passed' AS event_name,
        E.email AS expert_email,
        E.uuid AS expert_uuid,
        M.email AS member_email,  
        M.uuid AS member_uuid,
        GW.growthwork_id,
        GW.growthwork_order,
        GW.growthwork_title,
        GW.growthwork_description,
        CASE
            WHEN GW.growthwork_type = 'WISTIA' THEN CONCAT(GW.growthwork_type, '-', WM.type)
            ELSE GW.growthwork_type
        END AS growthwork_type,
        GW.part_id,
        GW.part_order,
        GW.part_description,
        GW.part_goal,
        GW.pathway_id,
        GW.pathway_name,
        GW.pathway_description,
        GW.pathway_goal
    FROM member_growthworks AS C 
    LEFT JOIN dim_growthwork AS GW ON C.gw_cms_id = GW.id
    LEFT JOIN members AS M ON C.member_id = M.id
    LEFT JOIN experts AS E ON M.expert_id = E.id
    LEFT JOIN wisita_medias AS WM ON GW.growthwork_source_id = WM.hashed_id


),

growthwork_completed AS (

    SELECT *
    FROM growthwork_completed_before_dedup
    QUALIFY ROW_NUMBER() OVER(PARTITION BY expert_uuid, member_uuid, growthwork_id ORDER BY growthwork_completed_at DESC) = 1

),

final_before_expert_correction AS (

    SELECT 
        MD5(COALESCE(PA.expert_uuid, '') || COALESCE(PA.member_uuid, '') || COALESCE(PA.pathway_id, '') || COALESCE(PA.part_id, '') || COALESCE(GC.growthwork_id, '')) AS unique_id,
        PA.part_assigned_at,
        PA.expert_email,
        PA.expert_uuid,
        PA.member_email,
        PA.member_uuid,
        PA.part_id,
        PA.part_order,
        PA.part_description,
        PA.part_goal,
        PA.pathway_id AS module_id,
        PA.pathway_name AS module_name,
        GC.growthwork_completed_at,
        GC.growthwork_id,
        GC.growthwork_order,
        GC.growthwork_title,
        GC.growthwork_description,
        GC.growthwork_type,
        COALESCE(PA.part_assigned_at > GC.growthwork_completed_at, FALSE) AS is_gw_completed_before_part_assigned
    FROM part_assigned AS PA
    LEFT JOIN growthwork_completed AS GC ON PA.expert_uuid = GC.expert_uuid
        AND PA.member_uuid = GC.member_uuid
        AND PA.pathway_id = GC.pathway_id
        AND PA.part_id = GC.part_id

),

final AS (

    SELECT 
        F.unique_id,
        F.part_assigned_at,
        CASE
            WHEN F.expert_email = 'expert@heyritual.com' AND E.email IS NOT NULL THEN E.email
            ELSE F.expert_email
        END AS expert_email,
        CASE
            WHEN F.expert_email = 'expert@heyritual.com' AND E.email IS NOT NULL THEN E.uuid
            ELSE F.expert_uuid
        END AS expert_uuid, 
        F.member_email,
        F.member_uuid,
        F.part_id,
        F.part_order,
        F.part_description,
        F.part_goal,
        F.module_id,
        F.module_name,
        F.growthwork_completed_at,
        F.growthwork_id,    
        F.growthwork_order,
        F.growthwork_title,
        F.growthwork_description,
        F.growthwork_type,
        F.is_gw_completed_before_part_assigned
    FROM final_before_expert_correction AS F
    LEFT JOIN members AS M ON F.member_uuid = M.uuid
    LEFT JOIN experts AS E ON M.expert_id = E.id
)

SELECT * FROM final