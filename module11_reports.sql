BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- ============================================================
-- MODULE 11: RETURNS / EXCHANGES / REFUNDS REPORTING
-- 15 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Return Summary (Daily, Critical)
-- All returns by status/type
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_summary AS
SELECT
    DATE(rr.request_date)                       AS return_date,
    rtl.code                                    AS return_type,
    rtl.name                                    AS return_type_name,
    rsl.code                                    AS return_status,
    rsl.name                                    AS status_name,
    COUNT(DISTINCT rr.return_request_id)        AS return_count,
    SUM(rr.total_items)                         AS total_items,
    SUM(rr.total_quantity)                      AS total_quantity,
    SUM(rr.refund_amount)                       AS total_refund_amount,
    SUM(rr.restocking_fee)                      AS total_restocking_fee,
    SUM(rr.total_refund_amount)                 AS net_refund_amount
FROM returns.return_requests rr
JOIN returns.return_type_lookup rtl ON rtl.return_type_id = rr.return_type_id
JOIN returns.return_status_lookup rsl ON rsl.return_status_id = rr.return_status_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(rr.request_date), rtl.code, rtl.name, rsl.code, rsl.name
ORDER BY return_date DESC;

-- ------------------------------------------------------------
-- Report 2: Exchange Report (Daily, Critical)
-- Exchange transactions
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_exchange_report AS
SELECT
    eo.exchange_order_id,
    eo.exchange_number,
    eo.exchange_date,
    eo.status                                   AS exchange_status,
    rr.return_number,
    rr.return_type_id,
    c.customer_id,
    COALESCE(c.first_name || ' ' || c.last_name, c.display_name) AS customer_name,
    eo.price_difference,
    eo.additional_charge,
    eo.refund_due,
    eo.created_at
FROM returns.exchange_orders eo
JOIN returns.return_requests rr ON rr.return_request_id = eo.return_request_id
LEFT JOIN crm.customers c ON c.customer_id = eo.customer_id
WHERE eo.exchange_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY eo.exchange_date DESC;

-- ------------------------------------------------------------
-- Report 3: Refund Report (Daily, Critical)
-- Refund transactions
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_refund_report AS
SELECT
    r.refund_id,
    r.refund_number,
    r.refund_date,
    rsl.code                                    AS refund_status,
    rml.code                                    AS refund_method,
    rml.name                                    AS refund_method_name,
    rr.return_number,
    COALESCE(c.first_name || ' ' || c.last_name, c.display_name) AS customer_name,
    r.refund_amount,
    r.restocking_fee,
    r.shipping_refund,
    r.net_refund_amount,
    r.completed_at
FROM returns.refunds r
JOIN returns.refund_status_lookup rsl ON rsl.refund_status_id = r.refund_status_id
JOIN returns.refund_method_lookup rml ON rml.refund_method_id = r.refund_method_id
JOIN returns.return_requests rr ON rr.return_request_id = r.return_request_id
LEFT JOIN crm.customers c ON c.customer_id = r.customer_id
WHERE r.refund_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY r.refund_date DESC;

-- ------------------------------------------------------------
-- Report 4: Return Reason Analysis (Weekly, Important)
-- Reasons for returns
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_reason_analysis AS
SELECT
    rrl.code                                    AS reason_code,
    rrl.name                                    AS reason_name,
    rrl.is_customer_fault,
    COUNT(DISTINCT rr.return_request_id)        AS return_count,
    SUM(rr.total_quantity)                      AS total_quantity,
    SUM(rr.refund_amount)                       AS total_refund_amount,
    ROUND((COUNT(DISTINCT rr.return_request_id)::NUMERIC /
        NULLIF(SUM(COUNT(DISTINCT rr.return_request_id)) OVER (), 0) * 100), 2
    ) AS percent_of_total
FROM returns.return_requests rr
JOIN returns.return_reason_lookup rrl ON rrl.return_reason_id = rr.return_reason_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY rrl.return_reason_id, rrl.code, rrl.name, rrl.is_customer_fault
ORDER BY return_count DESC;

-- ------------------------------------------------------------
-- Report 5: Return Processing Time (Weekly, Important)
-- Time to process returns
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_processing_time AS
SELECT
    rr.return_request_id,
    rr.return_number,
    rr.request_date,
    rsl.code                                    AS current_status,
    rr.approved_at,
    rr.items_received_at,
    rr.refund_completed_at,
    rr.exchange_completed_at,
    COALESCE(rr.refund_completed_at, rr.exchange_completed_at) AS completed_at,
    EXTRACT(EPOCH FROM (COALESCE(rr.refund_completed_at, rr.exchange_completed_at) - rr.created_at)) / 3600 AS processing_hours,
    CASE
        WHEN EXTRACT(EPOCH FROM (COALESCE(rr.refund_completed_at, rr.exchange_completed_at) - rr.created_at)) / 3600 <= 24 THEN 'WITHIN_24H'
        WHEN EXTRACT(EPOCH FROM (COALESCE(rr.refund_completed_at, rr.exchange_completed_at) - rr.created_at)) / 3600 <= 72 THEN 'WITHIN_72H'
        WHEN EXTRACT(EPOCH FROM (COALESCE(rr.refund_completed_at, rr.exchange_completed_at) - rr.created_at)) / 3600 <= 168 THEN 'WITHIN_7D'
        ELSE 'OVER_7D'
    END AS processing_bucket
FROM returns.return_requests rr
JOIN returns.return_status_lookup rsl ON rsl.return_status_id = rr.return_status_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '30 days'
  AND rsl.is_terminal = TRUE
ORDER BY processing_hours DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 6: Inventory Impact (Weekly, Important)
-- Items returned to inventory
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_inventory_impact AS
SELECT
    DATE(rr.request_date)                       AS return_date,
    p.product_code,
    p.product_name,
    SUM(rri.quantity)                           AS total_returned_quantity,
    SUM(rri.accepted_quantity)                  AS accepted_quantity,
    SUM(rri.rejected_quantity)                  AS rejected_quantity,
    SUM(rri.restocked_quantity)                 AS restocked_quantity,
    COUNT(DISTINCT rr.return_request_id)        AS return_count
FROM returns.return_request_items rri
JOIN returns.return_requests rr ON rr.return_request_id = rri.return_request_id
JOIN catalog.products p ON p.product_id = rri.product_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(rr.request_date), p.product_code, p.product_name
ORDER BY total_returned_quantity DESC;

-- ------------------------------------------------------------
-- Report 7: Return Approval Rate (Monthly, Important)
-- Approval vs rejection rates
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_approval_rate AS
SELECT
    DATE_TRUNC('month', rr.request_date)        AS approval_month,
    COUNT(DISTINCT rr.return_request_id)        AS total_requests,
    COUNT(DISTINCT CASE WHEN rsl.code IN ('APPROVED', 'ITEMS_RECEIVED', 'INSPECTION_PENDING', 'INSPECTION_COMPLETED', 'REFUND_PROCESSING', 'REFUND_COMPLETED', 'EXCHANGE_PROCESSING', 'EXCHANGE_COMPLETED') THEN rr.return_request_id END) AS approved_count,
    COUNT(DISTINCT CASE WHEN rsl.code = 'REJECTED' THEN rr.return_request_id END) AS rejected_count,
    ROUND((COUNT(DISTINCT CASE WHEN rsl.code IN ('APPROVED', 'ITEMS_RECEIVED', 'INSPECTION_PENDING', 'INSPECTION_COMPLETED', 'REFUND_PROCESSING', 'REFUND_COMPLETED', 'EXCHANGE_PROCESSING', 'EXCHANGE_COMPLETED') THEN rr.return_request_id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT rr.return_request_id), 0) * 100), 2
    ) AS approval_rate_percent
FROM returns.return_requests rr
JOIN returns.return_status_lookup rsl ON rsl.return_status_id = rr.return_status_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', rr.request_date)
ORDER BY approval_month DESC;

-- ------------------------------------------------------------
-- Report 8: Returns by Customer Segment (Monthly, Standard)
-- Returns by customer type
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_returns_by_customer_segment AS
SELECT
    cg.group_name,
    COUNT(DISTINCT rr.return_request_id)        AS return_count,
    SUM(rr.total_quantity)                      AS total_quantity,
    SUM(rr.refund_amount)                       AS total_refund_amount,
    ROUND((SUM(rr.refund_amount) / NULLIF(COUNT(DISTINCT rr.return_request_id), 0))::NUMERIC, 2) AS avg_refund_per_return
FROM returns.return_requests rr
JOIN crm.customers c ON c.customer_id = rr.customer_id
LEFT JOIN crm.customer_group_memberships cgm ON cgm.customer_id = c.customer_id AND cgm.is_active = TRUE
LEFT JOIN crm.customer_groups cg ON cg.customer_group_id = cgm.customer_group_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY cg.group_name
ORDER BY return_count DESC;

-- ------------------------------------------------------------
-- Report 9: Return Shipping Cost (Monthly, Important)
-- Cost of return shipping
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_shipping_cost AS
SELECT
    DATE_TRUNC('month', rs.created_at)          AS shipping_month,
    rs.courier_name,
    COUNT(DISTINCT rs.return_shipment_id)       AS shipment_count,
    SUM(rs.shipping_cost)                       AS total_shipping_cost,
    AVG(rs.shipping_cost)                       AS avg_shipping_cost
FROM returns.return_shipments rs
WHERE rs.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', rs.created_at), rs.courier_name
ORDER BY shipping_month DESC;

-- ------------------------------------------------------------
-- Report 10: Defective Product Analysis (Monthly, Critical)
-- Products returned as defective
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_defective_product_analysis AS
SELECT
    p.product_code,
    p.product_name,
    rrl.name                                    AS reason_name,
    COUNT(DISTINCT rr.return_request_id)        AS return_count,
    SUM(rri.quantity)                           AS total_quantity,
    SUM(rri.refund_amount)                      AS total_refund_amount,
    ROUND((COUNT(DISTINCT rr.return_request_id)::NUMERIC /
        NULLIF((SELECT COUNT(DISTINCT oi.order_item_id) FROM sales.order_items oi WHERE oi.product_id = p.product_id), 0) * 100), 2
    ) AS return_rate_percent
FROM returns.return_request_items rri
JOIN returns.return_requests rr ON rr.return_request_id = rri.return_request_id
JOIN catalog.products p ON p.product_id = rri.product_id
JOIN returns.return_reason_lookup rrl ON rrl.return_reason_id = rr.return_reason_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '90 days'
  AND rrl.code IN ('DEFECTIVE', 'DAMAGED_IN_TRANSIT', 'QUALITY_ISSUE', 'NOT_AS_DESCRIBED')
GROUP BY p.product_code, p.product_name, rrl.name
ORDER BY return_count DESC;

-- ------------------------------------------------------------
-- Report 11: Return Trend (Monthly, Important)
-- Return trends over time
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_trend AS
SELECT
    DATE_TRUNC('month', rr.request_date)        AS trend_month,
    rtl.code                                    AS return_type,
    COUNT(DISTINCT rr.return_request_id)        AS return_count,
    SUM(rr.total_quantity)                      AS total_quantity,
    SUM(rr.refund_amount)                       AS total_refund_amount,
    AVG(rr.refund_amount)                       AS avg_refund_amount
FROM returns.return_requests rr
JOIN returns.return_type_lookup rtl ON rtl.return_type_id = rr.return_type_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('month', rr.request_date), rtl.code
ORDER BY trend_month DESC;

-- ------------------------------------------------------------
-- Report 12: Customer Satisfaction - Returns (Quarterly, Important)
-- Return-related satisfaction
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_satisfaction AS
SELECT
    DATE_TRUNC('quarter', rr.request_date)      AS satisfaction_quarter,
    COUNT(DISTINCT rr.return_request_id)        AS total_returns,
    COUNT(DISTINCT CASE WHEN rsl.code IN ('REFUND_COMPLETED', 'EXCHANGE_COMPLETED') THEN rr.return_request_id END) AS resolved_returns,
    ROUND((COUNT(DISTINCT CASE WHEN rsl.code IN ('REFUND_COMPLETED', 'EXCHANGE_COMPLETED') THEN rr.return_request_id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT rr.return_request_id), 0) * 100), 2
    ) AS resolution_rate_percent,
    AVG(EXTRACT(EPOCH FROM (COALESCE(rr.refund_completed_at, rr.exchange_completed_at) - rr.created_at)) / 3600) AS avg_resolution_hours
FROM returns.return_requests rr
JOIN returns.return_status_lookup rsl ON rsl.return_status_id = rr.return_status_id
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('quarter', rr.request_date)
ORDER BY satisfaction_quarter DESC;

-- ------------------------------------------------------------
-- Report 13: Restocking Fee Analysis
-- Restocking fees collected
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_restocking_fee_analysis AS
SELECT
    DATE_TRUNC('month', rr.request_date)        AS fee_month,
    COUNT(DISTINCT rr.return_request_id)        AS returns_with_fee,
    SUM(rr.restocking_fee)                      AS total_restocking_fees,
    AVG(rr.restocking_fee)                      AS avg_restocking_fee
FROM returns.return_requests rr
WHERE rr.restocking_fee > 0
  AND rr.request_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', rr.request_date)
ORDER BY fee_month DESC;

-- ------------------------------------------------------------
-- Report 14: Return Window Compliance
-- Returns within/outside return window
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_window_compliance AS
SELECT
    DATE_TRUNC('month', rr.request_date)        AS compliance_month,
    COUNT(DISTINCT rr.return_request_id)        AS total_returns,
    COUNT(DISTINCT CASE WHEN rr.request_date <= (SELECT order_date FROM sales.orders o WHERE o.order_id = rr.order_id) + rr.return_window_days THEN rr.return_request_id END) AS within_window,
    COUNT(DISTINCT CASE WHEN rr.request_date > (SELECT order_date FROM sales.orders o WHERE o.order_id = rr.order_id) + rr.return_window_days THEN rr.return_request_id END) AS outside_window
FROM returns.return_requests rr
WHERE rr.request_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', rr.request_date)
ORDER BY compliance_month DESC;

-- ------------------------------------------------------------
-- Report 15: Return Health Dashboard
-- High-level return metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_return_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT return_request_id) FROM returns.return_requests WHERE request_date >= CURRENT_DATE - INTERVAL '30 days') AS returns_30d,
    (SELECT COUNT(DISTINCT return_request_id) FROM returns.return_requests WHERE request_date >= CURRENT_DATE - INTERVAL '30 days' AND return_status_id = (SELECT return_status_id FROM returns.return_status_lookup WHERE code = 'PENDING_APPROVAL')) AS pending_approvals,
    (SELECT COUNT(DISTINCT return_request_id) FROM returns.return_requests WHERE request_date >= CURRENT_DATE - INTERVAL '30 days' AND return_status_id = (SELECT return_status_id FROM returns.return_status_lookup WHERE code = 'INSPECTION_PENDING')) AS pending_inspections,
    (SELECT COUNT(DISTINCT refund_id) FROM returns.refunds WHERE refund_date >= CURRENT_DATE - INTERVAL '30 days' AND refund_status_id = (SELECT refund_status_id FROM returns.refund_status_lookup WHERE code = 'PROCESSING')) AS processing_refunds,
    (SELECT COALESCE(SUM(refund_amount), 0) FROM returns.refunds WHERE refund_date >= CURRENT_DATE - INTERVAL '30 days') AS total_refunds_30d,
    (SELECT COALESCE(SUM(refund_amount), 0) FROM returns.refunds WHERE refund_date >= CURRENT_DATE - INTERVAL '30 days' AND refund_status_id = (SELECT refund_status_id FROM returns.refund_status_lookup WHERE code = 'COMPLETED')) AS completed_refunds_30d;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Return Summary by Period
CREATE OR REPLACE FUNCTION reports.fn_return_summary(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    return_date DATE,
    return_count BIGINT,
    total_quantity NUMERIC,
    total_refund_amount NUMERIC,
    avg_processing_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rr.request_date,
        COUNT(DISTINCT rr.return_request_id),
        SUM(rr.total_quantity),
        SUM(rr.refund_amount),
        AVG(EXTRACT(EPOCH FROM (COALESCE(rr.refund_completed_at, rr.exchange_completed_at) - rr.created_at)) / 3600)
    FROM returns.return_requests rr
    WHERE rr.request_date BETWEEN p_start_date AND p_end_date
    GROUP BY rr.request_date
    ORDER BY rr.request_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Refund Summary by Period
CREATE OR REPLACE FUNCTION reports.fn_refund_summary(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    refund_date DATE,
    refund_count BIGINT,
    total_refund_amount NUMERIC,
    avg_refund_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.refund_date,
        COUNT(DISTINCT r.refund_id),
        SUM(r.refund_amount),
        AVG(r.refund_amount)
    FROM returns.refunds r
    WHERE r.refund_date BETWEEN p_start_date AND p_end_date
    GROUP BY r.refund_date
    ORDER BY r.refund_date;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Return Reasons by Period
CREATE OR REPLACE FUNCTION reports.fn_return_reasons(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    reason_code VARCHAR,
    reason_name VARCHAR,
    return_count BIGINT,
    total_refund_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rrl.code::VARCHAR,
        rrl.name::VARCHAR,
        COUNT(DISTINCT rr.return_request_id),
        SUM(rr.refund_amount)
    FROM returns.return_requests rr
    JOIN returns.return_reason_lookup rrl ON rrl.return_reason_id = rr.return_reason_id
    WHERE rr.request_date BETWEEN p_start_date AND p_end_date
    GROUP BY rrl.code, rrl.name
    ORDER BY return_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Defective Products
CREATE OR REPLACE FUNCTION reports.fn_defective_products(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    product_code VARCHAR,
    product_name VARCHAR,
    return_count BIGINT,
    total_quantity NUMERIC,
    total_refund_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.product_code::VARCHAR,
        p.product_name::VARCHAR,
        COUNT(DISTINCT rr.return_request_id),
        SUM(rri.quantity),
        SUM(rri.refund_amount)
    FROM returns.return_request_items rri
    JOIN returns.return_requests rr ON rr.return_request_id = rri.return_request_id
    JOIN catalog.products p ON p.product_id = rri.product_id
    JOIN returns.return_reason_lookup rrl ON rrl.return_reason_id = rr.return_reason_id
    WHERE rr.request_date BETWEEN p_start_date AND p_end_date
      AND rrl.code IN ('DEFECTIVE', 'DAMAGED_IN_TRANSIT', 'QUALITY_ISSUE')
    GROUP BY p.product_code, p.product_name
    ORDER BY return_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Return Processing Metrics
CREATE OR REPLACE FUNCTION reports.fn_return_processing_metrics(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    metric_name VARCHAR,
    metric_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'Total Returns'::VARCHAR, COUNT(DISTINCT rr.return_request_id)::NUMERIC
    FROM returns.return_requests rr
    WHERE rr.request_date BETWEEN p_start_date AND p_end_date
    UNION ALL
    SELECT 'Total Refund Amount'::VARCHAR, COALESCE(SUM(rr.refund_amount), 0)
    FROM returns.return_requests rr
    WHERE rr.request_date BETWEEN p_start_date AND p_end_date
    UNION ALL
    SELECT 'Avg Processing Hours'::VARCHAR,
        AVG(EXTRACT(EPOCH FROM (COALESCE(rr.refund_completed_at, rr.exchange_completed_at) - rr.created_at)) / 3600)
    FROM returns.return_requests rr
    WHERE rr.request_date BETWEEN p_start_date AND p_end_date
      AND rsl.is_terminal = TRUE;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 11 Returns
-- 15 Views + 5 Functions = 20 Report Objects
-- 15 Reports as per reports02.html catalog
-- ============================================================