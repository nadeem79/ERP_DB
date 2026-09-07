BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 10: SHIPPING / COURIER MANAGEMENT REPORTING
-- 15 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Shipment Summary (Daily, Critical)
-- All shipments by status/courier
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_shipment_summary AS
SELECT
    DATE(sh.shipment_date)                      AS shipment_date,
    sp.provider_name,
    ssl.code                                    AS shipment_status,
    ssl.name                                    AS status_name,
    stl.code                                    AS shipment_type,
    COUNT(DISTINCT sh.shipment_id)              AS shipment_count,
    SUM(sh.total_items)                         AS total_items,
    SUM(sh.total_shipping_cost)                 AS total_shipping_cost,
    SUM(sh.total_weight_kg)                     AS total_weight_kg,
    COUNT(DISTINCT CASE WHEN sh.is_cod = TRUE THEN sh.shipment_id END) AS cod_shipments,
    COUNT(DISTINCT CASE WHEN sh.is_insured = TRUE THEN sh.shipment_id END) AS insured_shipments
FROM shipping.shipments sh
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
JOIN shipping.shipment_type_lookup stl ON stl.shipment_type_id = sh.shipment_type_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(sh.shipment_date), sp.provider_name, ssl.code, ssl.name, stl.code
ORDER BY shipment_date DESC;

-- ------------------------------------------------------------
-- Report 2: Courier Performance (Monthly, Critical)
-- Delivery metrics by courier
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_courier_performance AS
SELECT
    sp.provider_code,
    sp.provider_name,
    sp.rating,
    COUNT(DISTINCT sh.shipment_id)              AS total_shipments,
    COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END) AS delivered_count,
    COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERY_FAILED' THEN sh.shipment_id END) AS failed_count,
    COUNT(DISTINCT CASE WHEN ssl.code = 'RETURNED' THEN sh.shipment_id END) AS returned_count,
    COUNT(DISTINCT CASE WHEN ssl.code = 'LOST' THEN sh.shipment_id END) AS lost_count,
    ROUND((COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT sh.shipment_id), 0) * 100), 2
    ) AS delivery_success_rate,
    AVG(EXTRACT(EPOCH FROM (sh.delivered_at - sh.shipped_at)) / 3600) FILTER (WHERE sh.delivered_at IS NOT NULL) AS avg_delivery_hours
FROM shipping.shipments sh
JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY sp.shipping_provider_id, sp.provider_code, sp.provider_name, sp.rating
ORDER BY delivery_success_rate DESC;

-- ------------------------------------------------------------
-- Report 3: Delivery Performance (Daily, Critical)
-- Delivery metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_delivery_performance AS
SELECT
    DATE(sh.shipment_date)                      AS delivery_date,
    COUNT(DISTINCT sh.shipment_id)              AS total_shipments,
    COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END) AS delivered,
    COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERY_FAILED' THEN sh.shipment_id END) AS failed,
    COUNT(DISTINCT CASE WHEN ssl.code = 'RETURNED' THEN sh.shipment_id END) AS returned,
    AVG(sh.delivery_attempts) FILTER (WHERE ssl.code IN ('DELIVERED', 'DELIVERY_FAILED')) AS avg_delivery_attempts,
    AVG(EXTRACT(EPOCH FROM (sh.delivered_at - sh.shipped_at)) / 3600) FILTER (WHERE sh.delivered_at IS NOT NULL) AS avg_delivery_hours
FROM shipping.shipments sh
JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(sh.shipment_date)
ORDER BY delivery_date DESC;

-- ------------------------------------------------------------
-- Report 4: Shipment Cost Analysis (Monthly, Critical)
-- Shipping costs
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_shipment_cost_analysis AS
SELECT
    DATE_TRUNC('month', sh.shipment_date)       AS cost_month,
    sp.provider_name,
    stl.code                                    AS shipment_type,
    COUNT(DISTINCT sh.shipment_id)              AS shipment_count,
    SUM(sh.shipping_cost)                       AS base_shipping_cost,
    SUM(sh.surcharge_amount)                    AS surcharge_amount,
    SUM(sh.insurance_cost)                      AS insurance_cost,
    SUM(sh.discount_amount)                     AS discount_amount,
    SUM(sh.total_shipping_cost)                 AS total_shipping_cost,
    AVG(sh.total_shipping_cost)                 AS avg_shipping_cost_per_shipment
FROM shipping.shipments sh
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
JOIN shipping.shipment_type_lookup stl ON stl.shipment_type_id = sh.shipment_type_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', sh.shipment_date), sp.provider_name, stl.code
ORDER BY cost_month DESC;

-- ------------------------------------------------------------
-- Report 5: COD Collection Report (Daily, Critical)
-- Cash on delivery collections
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_cod_collection AS
SELECT
    DATE(sh.shipment_date)                      AS collection_date,
    sp.provider_name,
    COUNT(DISTINCT cc.cod_collection_id)        AS cod_shipments,
    SUM(cc.cod_amount)                          AS total_cod_amount,
    SUM(cc.collected_amount)                    AS collected_amount,
    SUM(cc.cod_amount) - COALESCE(SUM(cc.collected_amount), 0) AS uncollected_amount,
    COUNT(DISTINCT CASE WHEN cc.collection_status = 'COLLECTED' THEN cc.cod_collection_id END) AS collected_count,
    COUNT(DISTINCT CASE WHEN cc.collection_status = 'PENDING' THEN cc.cod_collection_id END) AS pending_count
FROM shipping.cod_collections cc
JOIN shipping.shipments sh ON sh.shipment_id = cc.shipment_id
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(sh.shipment_date), sp.provider_name
ORDER BY collection_date DESC;

-- ------------------------------------------------------------
-- Report 6: Shipment Aging (Weekly, Important)
-- Shipments by age
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_shipment_aging AS
SELECT
    sh.shipment_id,
    sh.shipment_number,
    sh.shipment_date,
    ssl.code                                    AS shipment_status,
    sp.provider_name,
    sh.estimated_delivery_date,
    CURRENT_DATE - sh.shipment_date             AS days_in_transit,
    CASE
        WHEN CURRENT_DATE - sh.shipment_date <= 2 THEN 'ON_TRACK'
        WHEN CURRENT_DATE - sh.shipment_date <= 5 THEN 'SLIGHT_DELAY'
        WHEN CURRENT_DATE - sh.shipment_date <= 7 THEN 'DELAYED'
        ELSE 'SEVERELY_DELAYED'
    END AS aging_bucket
FROM shipping.shipments sh
JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
WHERE ssl.code IN ('PENDING', 'PICKING', 'PACKED', 'READY_FOR_PICKUP', 'PICKED_UP', 'IN_TRANSIT', 'OUT_FOR_DELIVERY')
ORDER BY days_in_transit DESC;

-- ------------------------------------------------------------
-- Report 7: Tracking Events (On-demand, Important)
-- Tracking event history
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_tracking_events AS
SELECT
    sh.shipment_number,
    sh.tracking_number,
    sp.provider_name,
    ste.event_code,
    ste.event_description,
    ste.event_status,
    ste.event_location,
    ste.event_timestamp,
    ste.received_at
FROM shipping.shipment_tracking_events ste
JOIN shipping.shipment_tracking st ON st.shipment_tracking_id = ste.shipment_tracking_id
JOIN shipping.shipments sh ON sh.shipment_id = ste.shipment_id
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
ORDER BY ste.event_timestamp DESC
LIMIT 1000;

-- ------------------------------------------------------------
-- Report 8: Failed Deliveries (Daily, Critical)
-- Failed delivery attempts
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_failed_deliveries AS
SELECT
    sh.shipment_id,
    sh.shipment_number,
    sh.shipment_date,
    sp.provider_name,
    sh.delivery_attempts,
    sh.delivery_notes,
    sh.shipping_address_city,
    sh.shipping_address_line1,
    se.exception_type,
    se.exception_description,
    se.status                                   AS exception_status
FROM shipping.shipments sh
JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
LEFT JOIN shipping.shipment_exceptions se ON se.shipment_id = sh.shipment_id AND se.status = 'OPEN'
WHERE ssl.code IN ('DELIVERY_FAILED', 'RETURNED')
  AND sh.shipment_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY sh.shipment_date DESC;

-- ------------------------------------------------------------
-- Report 9: Shipment Weight Analysis (Monthly, Important)
-- Weight distribution
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_shipment_weight_analysis AS
SELECT
    DATE_TRUNC('month', sh.shipment_date)       AS weight_month,
    COUNT(DISTINCT sh.shipment_id)              AS shipment_count,
    AVG(sh.total_weight_kg)                     AS avg_weight_kg,
    MIN(sh.total_weight_kg)                     AS min_weight_kg,
    MAX(sh.total_weight_kg)                     AS max_weight_kg,
    SUM(sh.total_weight_kg)                     AS total_weight_kg,
    COUNT(DISTINCT CASE WHEN sh.total_weight_kg <= 1 THEN sh.shipment_id END) AS under_1kg,
    COUNT(DISTINCT CASE WHEN sh.total_weight_kg > 1 AND sh.total_weight_kg <= 5 THEN sh.shipment_id END) AS weight_1_5kg,
    COUNT(DISTINCT CASE WHEN sh.total_weight_kg > 5 AND sh.total_weight_kg <= 10 THEN sh.shipment_id END) AS weight_5_10kg,
    COUNT(DISTINCT CASE WHEN sh.total_weight_kg > 10 THEN sh.shipment_id END) AS over_10kg
FROM shipping.shipments sh
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', sh.shipment_date)
ORDER BY weight_month DESC;

-- ------------------------------------------------------------
-- Report 10: Zone Rate Analysis (Monthly, Important)
-- Shipping rates by zone
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_zone_rate_analysis AS
SELECT
    sz.zone_code,
    sz.zone_name,
    sz.zone_type,
    COUNT(DISTINCT sr.shipping_rate_id)         AS rate_count,
    AVG(sr.base_rate)                           AS avg_base_rate,
    MIN(sr.base_rate)                           AS min_base_rate,
    MAX(sr.base_rate)                           AS max_base_rate,
    AVG(sr.per_kg_rate)                         AS avg_per_kg_rate
FROM shipping.shipping_zones sz
LEFT JOIN shipping.shipping_rates sr ON sr.shipping_zone_id = sz.shipping_zone_id AND sr.is_active = TRUE
GROUP BY sz.shipping_zone_id, sz.zone_code, sz.zone_name, sz.zone_type
ORDER BY sz.zone_name;

-- ------------------------------------------------------------
-- Report 11: Courier Comparison (Quarterly, Important)
-- Compare couriers on multiple criteria
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_courier_comparison AS
SELECT
    sp.provider_code,
    sp.provider_name,
    sp.supports_cod,
    sp.supports_insurance,
    sp.supports_international,
    sp.rating,
    COUNT(DISTINCT sh.shipment_id)              AS total_shipments,
    COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END) AS delivered,
    COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERY_FAILED' THEN sh.shipment_id END) AS failed,
    COUNT(DISTINCT CASE WHEN ssl.code = 'RETURNED' THEN sh.shipment_id END) AS returned,
    COUNT(DISTINCT CASE WHEN ssl.code = 'LOST' THEN sh.shipment_id END) AS lost,
    SUM(sh.total_shipping_cost)                 AS total_cost,
    AVG(sh.total_shipping_cost)                 AS avg_cost_per_shipment,
    ROUND((COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED'DELIVERED' THEN sh.shipment_id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT sh.shipment_id), 0) * 100), 2
    ) AS delivery_rate_percent
FROM shipping.shipments sh
JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY sp.shipping_provider_id, sp.provider_code, sp.provider_name, sp.supports_cod, sp.supports_insurance, sp.supports_international, sp.rating
ORDER BY delivery_rate_percent DESC;

-- ------------------------------------------------------------
-- Report 12: Shipment Insurance (Monthly, Important)
-- Insurance tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_shipment_insurance AS
SELECT
    DATE_TRUNC('month', sh.shipment_date)       AS insurance_month,
    COUNT(DISTINCT si.shipment_insurance_id)    AS insured_shipments,
    SUM(si.insured_value)                       AS total_insured_value,
    SUM(si.premium_amount)                      AS total_premium,
    COUNT(DISTINCT CASE WHEN si.is_claim_filed = TRUE THEN si.shipment_insurance_id END) AS claims_filed,
    SUM(si.claim_amount) FILTER (WHERE si.is_claim_filed = TRUE) AS total_claim_amount
FROM shipping.shipment_insurance si
JOIN shipping.shipments sh ON sh.shipment_id = si.shipment_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', sh.shipment_date)
ORDER BY insurance_month DESC;

-- ------------------------------------------------------------
-- Report 13: Shipment Exceptions (Daily, Critical)
-- Exceptions/issues
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_shipment_exceptions AS
SELECT
    se.shipment_exception_id,
    sh.shipment_number,
    sh.shipment_date,
    sp.provider_name,
    se.exception_type,
    se.exception_description,
    se.severity,
    se.status,
    se.resolution_notes,
    se.created_at,
    se.resolved_at
FROM shipping.shipment_exceptions se
JOIN shipping.shipments sh ON sh.shipment_id = se.shipment_id
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
WHERE se.created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY se.severity DESC, se.created_at DESC;

-- ------------------------------------------------------------
-- Report 14: Delivery Time Analysis (Monthly, Critical)
-- Delivery time metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_delivery_time_analysis AS
SELECT
    DATE_TRUNC('month', sh.shipment_date)       AS delivery_month,
    sp.provider_name,
    stl.code                                    AS shipment_type,
    COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END) AS delivered_count,
    AVG(EXTRACT(EPOCH FROM (sh.delivered_at - sh.shipped_at)) / 3600) FILTER (WHERE sh.delivered_at IS NOT NULL) AS avg_delivery_hours,
    MIN(EXTRACT(EPOCH FROM (sh.delivered_at - sh.shipped_at)) / 3600) FILTER (WHERE sh.delivered_at IS NOT NULL) AS min_delivery_hours,
    MAX(EXTRACT(EPOCH FROM (sh.delivered_at - sh.shipped_at)) / 3600) FILTER (WHERE sh.delivered_at IS NOT NULL) AS max_delivery_hours,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (sh.delivered_at - sh.shipped_at)) / 3600) FILTER (WHERE sh.delivered_at IS NOT NULL) AS p95_delivery_hours
FROM shipping.shipments sh
JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
LEFT JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
JOIN shipping.shipment_type_lookup stl ON stl.shipment_type_id = sh.shipment_type_id
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', sh.shipment_date), sp.provider_name, stl.code
ORDER BY delivery_month DESC;

-- ------------------------------------------------------------
-- Report 15: Shipment Health Dashboard (Daily, Critical)
-- Health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_shipment_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT shipment_id) FROM shipping.shipments WHERE shipment_date >= CURRENT_DATE - INTERVAL '7 days') AS shipments_7d,
    (SELECT COUNT(DISTINCT shipment_id) FROM shipping.shipments WHERE shipment_status_id = (SELECT shipment_status_id FROM shipping.shipment_status_lookup WHERE code = 'IN_TRANSIT')) AS in_transit,
    (SELECT COUNT(DISTINCT shipment_id) FROM shipping.shipments WHERE shipment_status_id = (SELECT shipment_status_id FROM shipping.shipment_status_lookup WHERE code = 'DELIVERED') AND shipment_date >= CURRENT_DATE - INTERVAL '7 days') AS delivered_7d,
    (SELECT COUNT(DISTINCT shipment_id) FROM shipping.shipments WHERE shipment_status_id = (SELECT shipment_status_id FROM shipping.shipment_status_lookup WHERE code = 'DELIVERY_FAILED') AND shipment_date >= CURRENT_DATE - INTERVAL '7 days') AS failed_7d,
    (SELECT COUNT(DISTINCT shipment_id) FROM shipping.shipments WHERE shipment_status_id = (SELECT shipment_status_id FROM shipping.shipment_status_lookup WHERE code = 'RETURNED') AND shipment_date >= CURRENT_DATE - INTERVAL '7 days') AS returned_7d,
    (SELECT COUNT(DISTINCT cod_collection_id) FROM shipping.cod_collections WHERE collection_status = 'PENDING') AS pending_cod,
    (SELECT COUNT(DISTINCT shipment_exception_id) FROM shipping.shipment_exceptions WHERE status = 'OPEN') AS open_exceptions;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Shipment Summary by Period
CREATE OR REPLACE FUNCTION reports.fn_shipment_summary(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    shipment_date DATE,
    shipment_count BIGINT,
    delivered_count BIGINT,
    failed_count BIGINT,
    total_shipping_cost NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sh.shipment_date,
        COUNT(DISTINCT sh.shipment_id),
        COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END),
        COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERY_FAILED' THEN sh.shipment_id END),
        COALESCE(SUM(sh.total_shipping_cost), 0)
    FROM shipping.shipments sh
    JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
    WHERE sh.shipment_date BETWEEN p_start_date AND p_end_date
    GROUP BY sh.shipment_date
    ORDER BY sh.shipment_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Courier Performance
CREATE OR REPLACE FUNCTION reports.fn_courier_performance(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '90 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    provider_code VARCHAR,
    provider_name VARCHAR,
    total_shipments BIGINT,
    delivered_count BIGINT,
    delivery_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sp.provider_code::VARCHAR,
        sp.provider_name::VARCHAR,
        COUNT(DISTINCT sh.shipment_id),
        COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END),
        ROUND((COUNT(DISTINCT CASE WHEN ssl.code = 'DELIVERED' THEN sh.shipment_id END)::NUMERIC /
            NULLIF(COUNT(DISTINCT sh.shipment_id), 0) * 100), 2)
    FROM shipping.shipments sh
    JOIN shipping.shipping_providers sp ON sp.shipping_provider_id = sh.shipping_provider_id
    JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
    WHERE sh.shipment_date BETWEEN p_start_date AND p_end_date
    GROUP BY sp.provider_code, sp.provider_name
    ORDER BY delivery_rate DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get COD Summary
CREATE OR REPLACE FUNCTION reports.fn_cod_summary(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    collection_date DATE,
    cod_shipments BIGINT,
    total_cod_amount NUMERIC,
    collected_amount NUMERIC,
    uncollected_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sh.shipment_date,
        COUNT(DISTINCT cc.cod_collection_id),
        COALESCE(SUM(cc.cod_amount), 0),
        COALESCE(SUM(cc.collected_amount), 0),
        COALESCE(SUM(cc.cod_amount), 0) - COALESCE(SUM(cc.collected_amount), 0)
    FROM shipping.cod_collections cc
    JOIN shipping.shipments sh ON sh.shipment_id = cc.shipment_id
    WHERE sh.shipment_date BETWEEN p_start_date AND p_end_date
    GROUP BY sh.shipment_date
    ORDER BY sh.shipment_date;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Shipment Tracking
CREATE OR REPLACE FUNCTION reports.fn_shipment_tracking(
    p_shipment_id UUID
)
RETURNS TABLE (
    tracking_number VARCHAR,
    event_code VARCHAR,
    event_description TEXT,
    event_location VARCHAR,
    event_timestamp TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        st.tracking_number::VARCHAR,
        ste.event_code::VARCHAR,
        ste.event_description,
        ste.event_location::VARCHAR,
        ste.event_timestamp
    FROM shipping.shipment_tracking_events ste
    JOIN shipping.shipment_tracking st ON st.shipment_tracking_id = ste.shipment_tracking_id
    WHERE ste.shipment_id = p_shipment_id
    ORDER BY ste.event_timestamp DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Delivery Metrics
CREATE OR REPLACE FUNCTION reports.fn_delivery_metrics(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    metric_name VARCHAR,
    metric_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'Total Shipments'::VARCHAR, COUNT(DISTINCT sh.shipment_id)::NUMERIC
    FROM shipping.shipments sh WHERE sh.shipment_date BETWEEN p_start_date AND p_end_date
    UNION ALL
    SELECT 'Delivered'::VARCHAR, COUNT(DISTINCT sh.shipment_id)::NUMERIC
    FROM shipping.shipments sh
    JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
    WHERE sh.shipment_date BETWEEN p_start_date AND p_end_date AND ssl.code = 'DELIVERED'
    UNION ALL
    SELECT 'Failed Deliveries'::VARCHAR, COUNT(DISTINCT sh.shipment_id)::NUMERIC
    FROM shipping.shipments sh
    JOIN shipping.shipment_status_lookup ssl ON ssl.shipment_status_id = sh.shipment_status_id
    WHERE sh.shipment_date BETWEEN p_start_date AND p_end_date AND ssl.code = 'DELIVERY_FAILED'
    UNION ALL
    SELECT 'Avg Delivery Hours'::VARCHAR,
        AVG(EXTRACT(EPOCH FROM (sh.delivered_at - sh.shipped_at)) / 3600)
    FROM shipping.shipments sh
    WHERE sh.shipment_date BETWEEN p_start_date AND p_end_date AND sh.delivered_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 10 Shipping
-- 15 Views + 5 Functions = 20 Report Objects
-- 15 Reports as per reports02.html catalog
-- ============================================================