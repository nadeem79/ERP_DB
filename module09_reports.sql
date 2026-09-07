BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 09: PAYMENTS / PAYMENT GATEWAYS REPORTING
-- 15 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Payment Summary (Daily, Critical)
-- All payments by method/status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_summary AS
SELECT
    DATE(p.payment_date)                        AS payment_date,
    pm.method_name                              AS payment_method,
    psl.code                                    AS payment_status,
    psl.name                                    AS status_name,
    COUNT(DISTINCT p.payment_id)                AS payment_count,
    SUM(p.amount)                               AS total_amount,
    SUM(p.refund_amount)                        AS total_refunds,
    SUM(p.amount - p.refund_amount)             AS net_amount,
    COUNT(DISTINCT p.customer_id)               AS unique_customers
FROM payments.payments p
LEFT JOIN payments.payment_methods pm ON pm.payment_method_id = p.payment_method_id
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(p.payment_date), pm.method_name, psl.code, psl.name
ORDER BY payment_date DESC;

-- ------------------------------------------------------------
-- Report 2: Gateway Performance (Daily, Critical)
-- Success/failure rates by gateway
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_gateway_performance AS
SELECT
    pg.gateway_code,
    pg.gateway_name,
    COUNT(DISTINCT p.payment_id)                AS total_payments,
    COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END) AS successful_payments,
    COUNT(DISTINCT CASE WHEN psl.code = 'FAILED' THEN p.payment_id END) AS failed_payments,
    COUNT(DISTINCT CASE WHEN psl.code = 'REFUNDED' THEN p.payment_id END) AS refunded_payments,
    SUM(p.amount) FILTER (WHERE psl.code IN ('COMPLETED', 'SETTLED')) AS successful_amount,
    ROUND((COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT p.payment_id), 0) * 100), 2) AS success_rate_percent,
    AVG(EXTRACT(EPOCH FROM (p.completed_at - p.initiated_at)) / 60) FILTER (WHERE p.completed_at IS NOT NULL) AS avg_processing_minutes
FROM payments.payments p
JOIN payments.payment_gateways pg ON pg.payment_gateway_id = p.payment_gateway_id
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY pg.payment_gateway_id, pg.gateway_code, pg.gateway_name
ORDER BY success_rate_percent DESC;

-- ------------------------------------------------------------
-- Report 3: Payment Method Analysis (Weekly, Important)
-- Performance by payment method
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_method_analysis AS
SELECT
    pm.method_code,
    pm.method_name,
    pm.method_type,
    COUNT(DISTINCT p.payment_id)                AS payment_count,
    SUM(p.amount)                               AS total_amount,
    AVG(p.amount)                               AS avg_payment_amount,
    COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END) AS successful_count,
    COUNT(DISTINCT CASE WHEN psl.code = 'FAILED' THEN p.payment_id END) AS failed_count,
    ROUND((COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT p.payment_id), 0) * 100), 2) AS success_rate_percent
FROM payments.payments p
JOIN payments.payment_methods pm ON pm.payment_method_id = p.payment_method_id
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY pm.payment_method_id, pm.method_code, pm.method_name, pm.method_type
ORDER BY payment_count DESC;

-- ------------------------------------------------------------
-- Report 4: Refund Report (Daily, Critical)
-- All refunds by reason
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_refund_report AS
SELECT
    pr.refund_number,
    pr.refund_date,
    pr.refund_type,
    pr.status                                   AS refund_status,
    pr.refund_amount,
    pr.refund_reason,
    p.payment_number,
    p.amount                                    AS original_payment_amount,
    o.order_number,
    COALESCE(c.first_name || ' ' || c.last_name, c.display_name) AS customer_name,
    pr.created_at
FROM payments.payment_refunds pr
JOIN payments.payments p ON p.payment_id = pr.payment_id
LEFT JOIN sales.orders o ON o.order_id = pr.order_id
LEFT JOIN crm.customers c ON c.customer_id = pr.customer_id
WHERE pr.refund_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY pr.refund_date DESC;

-- ------------------------------------------------------------
-- Report 5: Payment Reconciliation (Daily, Critical)
-- Matched/unmatched payments
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_reconciliation AS
SELECT
    prec.reconciliation_date,
    prec.reconciliation_batch,
    pg.gateway_name,
    prec.status                                 AS reconciliation_status,
    prec.expected_count,
    prec.matched_count,
    prec.unmatched_count,
    prec.discrepancy_count,
    prec.expected_amount,
    prec.matched_amount,
    prec.unmatched_amount,
    prec.discrepancy_amount,
    prec.reconciled_at
FROM payments.payment_reconciliations prec
LEFT JOIN payments.payment_gateways pg ON pg.payment_gateway_id = prec.payment_gateway_id
WHERE prec.reconciliation_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY prec.reconciliation_date DESC;

-- ------------------------------------------------------------
-- Report 6: Failed Payments (Daily, Critical)
-- Failed payment attempts
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_failed_payments AS
SELECT
    p.payment_id,
    p.payment_number,
    p.payment_date,
    p.amount,
    p.failure_reason,
    p.gateway_response_code,
    p.gateway_response_message,
    p.retry_count,
    p.max_retries,
    pm.method_name,
    pg.gateway_name,
    o.order_number,
    COALESCE(c.first_name || ' ' || c.last_name, c.display_name) AS customer_name
FROM payments.payments p
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
LEFT JOIN payments.payment_methods pm ON pm.payment_method_id = p.payment_method_id
LEFT JOIN payments.payment_gateways pg ON pg.payment_gateway_id = p.payment_gateway_id
LEFT JOIN sales.orders o ON o.order_id = p.order_id
LEFT JOIN crm.customers c ON c.customer_id = p.customer_id
WHERE psl.code = 'FAILED'
  AND p.payment_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY p.payment_date DESC;

-- ------------------------------------------------------------
-- Report 7: Payment Aging (Weekly, Important)
-- Outstanding payments by age
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_aging AS
SELECT
    p.payment_id,
    p.payment_number,
    p.payment_date,
    p.amount,
    psl.code                                    AS payment_status,
    pm.method_name,
    CURRENT_DATE - p.payment_date               AS days_pending,
    CASE
        WHEN CURRENT_DATE - p.payment_date <= 7 THEN '0-7 Days'
        WHEN CURRENT_DATE - p.payment_date <= 30 THEN '8-30 Days'
        WHEN CURRENT_DATE - p.payment_date <= 60 THEN '31-60 Days'
        ELSE '60+ Days'
    END AS aging_bucket
FROM payments.payments p
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
LEFT JOIN payments.payment_methods pm ON pm.payment_method_id = p.payment_method_id
WHERE psl.code IN ('PENDING', 'PROCESSING', 'AUTHORIZED')
ORDER BY days_pending DESC;

-- ------------------------------------------------------------
-- Report 8: Gateway Fee Analysis (Monthly, Important)
-- Fees by gateway
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_gateway_fee_analysis AS
SELECT
    DATE_TRUNC('month', p.payment_date)         AS fee_month,
    pg.gateway_code,
    pg.gateway_name,
    pg.processing_fee_percent,
    pg.processing_fee_fixed,
    COUNT(DISTINCT p.payment_id)                AS payment_count,
    SUM(p.amount)                               AS total_amount,
    SUM(COALESCE(p.processing_fee, 0))          AS total_fees,
    SUM(p.net_amount)                           AS net_amount,
    ROUND((SUM(COALESCE(p.processing_fee, 0)) / NULLIF(SUM(p.amount), 0) * 100), 2) AS fee_rate_percent
FROM payments.payments p
JOIN payments.payment_gateways pg ON pg.payment_gateway_id = p.payment_gateway_id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '90 days'
  AND p.payment_status_id IN (SELECT payment_status_id FROM payments.payment_status_lookup WHERE code IN ('COMPLETED', 'SETTLED'))
GROUP BY DATE_TRUNC('month', p.payment_date), pg.gateway_code, pg.gateway_name, pg.processing_fee_percent, pg.processing_fee_fixed
ORDER BY fee_month DESC;

-- ------------------------------------------------------------
-- Report 9: Multi-currency Payments (Monthly, Important)
-- Cross-currency payments
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_multicurrency_payments AS
SELECT
    DATE_TRUNC('month', p.payment_date)         AS payment_month,
    cur.code                                    AS currency_code,
    cur.name                                    AS currency_name,
    COUNT(DISTINCT p.payment_id)                AS payment_count,
    SUM(p.amount)                               AS total_amount,
    AVG(p.exchange_rate)                        AS avg_exchange_rate
FROM payments.payments p
JOIN reference.currency_lookup cur ON cur.currency_id = p.currency_id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', p.payment_date), cur.code, cur.name
ORDER BY payment_month DESC;

-- ------------------------------------------------------------
-- Report 10: Payment Retry Analysis (Weekly, Important)
-- Retry success rates
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_retry_analysis AS
SELECT
    DATE(p.payment_date)                        AS payment_date,
    COUNT(DISTINCT p.payment_id)                AS payments_with_retries,
    SUM(p.retry_count)                          AS total_retries,
    COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END) AS recovered_after_retry,
    ROUND((COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT p.payment_id), 0) * 100), 2) AS recovery_rate_percent
FROM payments.payments p
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
WHERE p.retry_count > 0
  AND p.payment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(p.payment_date)
ORDER BY payment_date DESC;

-- ------------------------------------------------------------
-- Report 11: COD Collection Report (Daily, Critical)
-- COD payment tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_cod_collection AS
SELECT
    DATE(p.payment_date)                        AS collection_date,
    COUNT(DISTINCT p.payment_id)                AS cod_payments,
    SUM(p.amount)                               AS total_cod_amount,
    COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END) AS collected_count,
    SUM(p.amount) FILTER (WHERE psl.code IN ('COMPLETED', 'SETTLED')) AS collected_amount,
    COUNT(DISTINCT CASE WHEN psl.code IN ('PENDING', 'PROCESSING') THEN p.payment_id END) AS pending_count,
    SUM(p.amount) FILTER (WHERE psl.code IN ('PENDING', 'PROCESSING')) AS pending_amount
FROM payments.payments p
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
JOIN payments.payment_methods pm ON pm.payment_method_id = p.payment_method_id
WHERE pm.method_code = 'COD'
  AND p.payment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(p.payment_date)
ORDER BY collection_date DESC;

-- ------------------------------------------------------------
-- Report 12: Payment Split Report (Monthly, Important)
-- Marketplace splits
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_split_report AS
SELECT
    DATE_TRUNC('month', p.payment_date)         AS split_month,
    ps.split_type,
    ps.recipient_type,
    COUNT(DISTINCT ps.payment_split_id)         AS split_count,
    SUM(ps.split_amount)                        AS total_split_amount,
    COUNT(DISTINCT CASE WHEN ps.status = 'SETTLED' THEN ps.payment_split_id END) AS settled_count
FROM payments.payment_splits ps
JOIN payments.payments p ON p.payment_id = ps.payment_id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', p.payment_date), ps.split_type, ps.recipient_type
ORDER BY split_month DESC;

-- ------------------------------------------------------------
-- Report 13: Payment Trend (Monthly, Important)
-- Payment trends over time
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_trend AS
SELECT
    DATE_TRUNC('month', p.payment_date)         AS payment_month,
    COUNT(DISTINCT p.payment_id)                AS payment_count,
    SUM(p.amount)                               AS total_amount,
    AVG(p.amount)                               AS avg_payment_amount,
    COUNT(DISTINCT p.customer_id)               AS unique_customers,
    COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END) AS successful_payments,
    COUNT(DISTINCT CASE WHEN psl.code = 'FAILED' THEN p.payment_id END) AS failed_payments
FROM payments.payments p
JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('month', p.payment_date)
ORDER BY payment_month DESC;

-- ------------------------------------------------------------
-- Report 14: Settlement Report (Weekly, Critical)
-- Settlement tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_settlement_report AS
SELECT
    pset.settlement_batch_id,
    pset.settlement_date,
    pg.gateway_name,
    pset.status                                 AS settlement_status,
    pset.gross_amount,
    pset.processing_fees,
    pset.net_amount,
    pset.transaction_count,
    pset.refund_count,
    pset.settled_at,
    pset.bank_reference
FROM payments.payment_settlements pset
JOIN payments.payment_gateways pg ON pg.payment_gateway_id = pset.payment_gateway_id
WHERE pset.settlement_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY pset.settlement_date DESC;

-- ------------------------------------------------------------
-- Report 15: Payment Health Dashboard (Daily, Critical)
-- Health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_payment_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT payment_id) FROM payments.payments WHERE payment_date >= CURRENT_DATE - INTERVAL '7 days') AS payments_7d,
    (SELECT COUNT(DISTINCT payment_id) FROM payments.payments WHERE payment_status_id = (SELECT payment_status_id FROM payments.payment_status_lookup WHERE code = 'COMPLETED') AND payment_date >= CURRENT_DATE - INTERVAL '7 days') AS completed_7d,
    (SELECT COUNT(DISTINCT payment_id) FROM payments.payments WHERE payment_status_id = (SELECT payment_status_id FROM payments.payment_status_lookup WHERE code = 'FAILED') AND payment_date >= CURRENT_DATE - INTERVAL '7 days') AS failed_7d,
    (SELECT COUNT(DISTINCT payment_id) FROM payments.payments WHERE payment_status_id IN (SELECT payment_status_id FROM payments.payment_status_lookup WHERE code IN ('PENDING', 'PROCESSING'))) AS pending_payments,
    (SELECT COALESCE(SUM(amount), 0) FROM payments.payments WHERE payment_status_id IN (SELECT payment_status_id FROM payments.payment_status_lookup WHERE code IN ('COMPLETED', 'SETTLED')) AND payment_date >= CURRENT_DATE - INTERVAL '7 days') AS collected_7d,
    (SELECT COUNT(DISTINCT payment_refund_id) FROM payments.payment_refunds WHERE refund_date >= CURRENT_DATE - INTERVAL '7 days') AS refunds_7d,
    (SELECT COUNT(DISTINCT payment_reconciliation_id) FROM payments.payment_reconciliations WHERE status IN ('PENDING', 'IN_PROGRESS')) AS pending_reconciliations;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Payment Summary by Period
CREATE OR REPLACE FUNCTION reports.fn_payment_summary(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    payment_date DATE,
    payment_count BIGINT,
    total_amount NUMERIC,
    successful_count BIGINT,
    failed_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.payment_date,
        COUNT(DISTINCT p.payment_id),
        SUM(p.amount),
        COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END),
        COUNT(DISTINCT CASE WHEN psl.code = 'FAILED' THEN p.payment_id END)
    FROM payments.payments p
    JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
    WHERE p.payment_date BETWEEN p_start_date AND p_end_date
    GROUP BY p.payment_date
    ORDER BY p.payment_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Gateway Performance
CREATE OR REPLACE FUNCTION reports.fn_gateway_performance(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    gateway_code VARCHAR,
    gateway_name VARCHAR,
    total_payments BIGINT,
    successful_payments BIGINT,
    success_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pg.gateway_code::VARCHAR,
        pg.gateway_name::VARCHAR,
        COUNT(DISTINCT p.payment_id),
        COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END),
        ROUND((COUNT(DISTINCT CASE WHEN psl.code IN ('COMPLETED', 'SETTLED') THEN p.payment_id END)::NUMERIC /
            NULLIF(COUNT(DISTINCT p.payment_id), 0) * 100), 2)
    FROM payments.payments p
    JOIN payments.payment_gateways pg ON pg.payment_gateway_id = p.payment_gateway_id
    JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
    WHERE p.payment_date BETWEEN p_start_date AND p_end_date
    GROUP BY pg.gateway_code, pg.gateway_name
    ORDER BY success_rate DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Refund Summary
CREATE OR REPLACE FUNCTION reports.fn_refund_summary(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
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
        pr.refund_date,
        COUNT(DISTINCT pr.payment_refund_id),
        SUM(pr.refund_amount),
        AVG(pr.refund_amount)
    FROM payments.payment_refunds pr
    WHERE pr.refund_date BETWEEN p_start_date AND p_end_date
    GROUP BY pr.refund_date
    ORDER BY pr.refund_date;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Payment Aging Summary
CREATE OR REPLACE FUNCTION reports.fn_payment_aging_summary()
RETURNS TABLE (
    aging_bucket VARCHAR,
    payment_count BIGINT,
    total_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN CURRENT_DATE - p.payment_date <= 7 THEN '0-7 Days'
            WHEN CURRENT_DATE - p.payment_date <= 30 THEN '8-30 Days'
            WHEN CURRENT_DATE - p.payment_date <= 60 THEN '31-60 Days'
            ELSE '60+ Days'
        END::VARCHAR,
        COUNT(DISTINCT p.payment_id),
        SUM(p.amount)
    FROM payments.payments p
    JOIN payments.payment_status_lookup psl ON psl.payment_status_id = p.payment_status_id
    WHERE psl.code IN ('PENDING', 'PROCESSING', 'AUTHORIZED')
    GROUP BY 1
    ORDER BY MIN(CURRENT_DATE - p.payment_date);
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Settlement Summary
CREATE OR REPLACE FUNCTION reports.fn_settlement_summary(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    settlement_date DATE,
    settlement_count BIGINT,
    gross_amount NUMERIC,
    net_amount NUMERIC,
    total_fees NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pset.settlement_date,
        COUNT(DISTINCT pset.payment_settlement_id),
        SUM(pset.gross_amount),
        SUM(pset.net_amount),
        SUM(pset.processing_fees)
    FROM payments.payment_settlements pset
    WHERE pset.settlement_date BETWEEN p_start_date AND p_end_date
    GROUP BY pset.settlement_date
    ORDER BY pset.settlement_date;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 09 Payments
-- 15 Views + 5 Functions = 20 Report Objects
-- 15 Reports as per reports02.html catalog
-- ============================================================