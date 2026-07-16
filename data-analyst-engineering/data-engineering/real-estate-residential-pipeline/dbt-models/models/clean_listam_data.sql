{{ config(materialized='table') }}

SELECT
    id,
    title,
    price_usd,
    district,
    rooms,
    floor,
    area_sqm,
    build_type,
    seller_type,
    date_posted_exact
FROM default.listam_real_estate
WHERE price_usd > 0
  AND price_usd IS NOT NULL