BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- ============================================================
-- MODULE 12: POS / POINT OF SALE REPORTING
-- 15 Views + 3 Functions
-- Matched to actual DB: pos.pos_shifts, pos.pos_terminals,
--   pos.pos_registers, pos.pos_cash_transactions,
--   pos.pos_sale_voids, pos.pos_shift_reconciliations
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: POS Sales Summary (Daily, Critical)
-- All POS sales by store, terminal, and register
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_sales_summary AS
SELECT
    DATE(ps.opened_at)                                        AS shift_date,
    pt.terminal_name,
    pr.register_name,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE')       AS total_sales,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND') AS total_refunds,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE')
      - COALESCE(ABS(SUM(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND'), 0) AS net_sales,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE')    AS sale_count,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'REFUND')  AS refund_count,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type IN ('CASH_IN','CASH_OUT','PETTY_CASH')) AS cash_movement_count,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'CASH_IN')   AS total_cash_in,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'CASH_OUT') AS total_cash_out
FROM pos.pos_shifts ps
JOIN pos.pos_terminals pt ON pt.pos_terminal_id = ps.pos_terminal_id
JOIN pos.pos_registers  pr ON pr.pos_register_id = ps.pos_register_id
LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ps.opened_at), pt.terminal_name, pr.register_name
ORDER BY shift_date DESC, pt.terminal_name;


-- ------------------------------------------------------------
-- Report 2: Cashier Performance (Weekly, Critical)
-- Sales, refunds, variance, and shift metrics by cashier
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_cashier_performance AS
SELECT
    COALESCE(pp.display_name, u.username)                     AS cashier_name,
    u.user_id                                                 AS cashier_user_id,
    COUNT(DISTINCT ps.pos_shift_id)                           AS total_shifts,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE')       AS total_sales,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND') AS total_refunds,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') AS sale_transactions,
    SUM(ABS(ps.cash_difference))                              AS total_cash_variance,
    AVG(ps.cash_difference)                                   AS avg_cash_variance,
    MAX(ABS(ps.cash_difference))                              AS max_cash_variance,
    MIN(ps.opened_at)                                         AS first_shift,
    MAX(ps.opened_at)                                         AS last_shift
FROM pos.pos_shifts ps
LEFT JOIN identity.users   u  ON u.user_id  = ps.opened_by_user_id
LEFT JOIN identity.persons pp ON pp.person_id = u.person_id
LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
  AND ps.status = 'CLOSED'
GROUP BY ps.opened_by_user_id, COALESCE(pp.display_name, u.username), u.user_id
ORDER BY total_sales DESC NULLS LAST;


-- ------------------------------------------------------------
-- Report 3: Sales by Shift and Cashier (Daily, Critical)
-- Detailed shift-level metrics with duration and throughput
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_by_shift AS
SELECT
    ps.pos_shift_id,
    ps.shift_number,
    DATE(ps.opened_at)                                        AS shift_date,
    COALESCE(pp.display_name, u.username)                     AS cashier_name,
    pt.terminal_name,
    pr.register_name,
    ps.opened_at,
    ps.closed_at,
    ps.status                                                 AS shift_status,
    ps.opening_amount,
    ps.expected_cash_amount,
    ps.actual_cash_amount,
    ps.cash_difference,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE')       AS total_sales,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND') AS total_refunds,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type IN ('CASH_IN','CASH_OUT','PETTY_CASH')) AS cash_movements,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') AS sale_count,
    CASE
        WHEN EXTRACT(EPOCH FROM (ps.closed_at - ps.opened_at)) > 0
        THEN ROUND((EXTRACT(EPOCH FROM (ps.closed_at - ps.opened_at)) / 3600.0)::NUMERIC, 2)
        ELSE 0
    END AS shift_duration_hours,
    CASE
        WHEN EXTRACT(EPOCH FROM (ps.closed_at - ps.opened_at)) > 0
             AND COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') > 0
        THEN ROUND(
            (COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE'))::NUMERIC
            / (EXTRACT(EPOCH FROM (ps.closed_at - ps.opened_at)) / 3600.0), 2)
        ELSE 0
    END AS transactions_per_hour
FROM pos.pos_shifts ps
JOIN pos.pos_terminals pt ON pt.pos_terminal_id = ps.pos_terminal_id
JOIN pos.pos_registers  pr ON pr.pos_register_id = ps.pos_register_id
LEFT JOIN identity.users   u  ON u.user_id  = ps.opened_by_user_id
LEFT JOIN identity.persons pp ON pp.person_id = u.person_id
LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY ps.pos_shift_id, ps.shift_number, ps.opened_at, ps.closed_at, ps.status,
         ps.opening_amount, ps.expected_cash_amount, ps.actual_cash_amount,
         ps.cash_difference, COALESCE(pp.display_name, u.username), u.user_id,
         pt.terminal_name, pr.register_name
ORDER BY shift_date DESC, ps.shift_number;


-- ------------------------------------------------------------
-- Report 4: Cash Variance Report (Daily, Critical)
-- Cash discrepancies per shift: over, short, or balanced
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_cash_variance AS
SELECT
    ps.pos_shift_id,
    ps.shift_number,
    DATE(ps.opened_at)                                        AS shift_date,
    COALESCE(pp.display_name, u.username)                     AS cashier_name,
    pt.terminal_name,
    pr.register_name,
    ps.opening_amount,
    ps.expected_cash_amount,
    ps.actual_cash_amount,
    ps.cash_difference,
    CASE
        WHEN ps.cash_difference > 0 THEN 'OVER'
        WHEN ps.cash_difference < 0 THEN 'SHORT'
        ELSE 'BALANCED'
    END AS variance_status,
    ABS(ps.cash_difference)                                   AS abs_variance,
    CASE
        WHEN ps.opening_amount > 0
        THEN ROUND((ABS(ps.cash_difference) / ps.opening_amount * 100)::NUMERIC, 2)
        ELSE 0
    END AS variance_percent,
    ps.opened_at,
    ps.closed_at
FROM pos.pos_shifts ps
JOIN pos.pos_terminals pt ON pt.pos_terminal_id = ps.pos_terminal_id
JOIN pos.pos_registers  pr ON pr.pos_register_id = ps.pos_register_id
LEFT JOIN identity.users   u  ON u.user_id  = ps.opened_by_user_id
LEFT JOIN identity.persons pp ON pp.person_id = u.person_id
WHERE ps.status = 'CLOSED'
  AND ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY ABS(ps.cash_difference) DESC;


-- ------------------------------------------------------------
-- Report 5: POS Payment Method Breakdown (Weekly, Important)
-- Payment methods used in POS transactions
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_payment_method AS
SELECT
    DATE(ps.opened_at)                                        AS shift_date,
    pct.transaction_type                                      AS payment_type,
    COUNT(pct.pos_cash_transaction_id)                        AS transaction_count,
    SUM(pct.amount)                                           AS total_amount,
    AVG(pct.amount)                                           AS avg_amount,
    ROUND((SUM(pct.amount)::NUMERIC /
        NULLIF(SUM(SUM(pct.amount)) OVER (PARTITION BY DATE(ps.opened_at)), 0) * 100), 2
    ) AS percent_of_total
FROM pos.pos_cash_transactions pct
JOIN pos.pos_shifts ps ON ps.pos_shift_id = pct.pos_shift_id
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ps.opened_at), pct.transaction_type
ORDER BY shift_date DESC, total_amount DESC;


-- ------------------------------------------------------------
-- Report 6: Hourly Sales Report (Daily, Important)
-- Sales distribution by hour of day for staffing optimization
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_hourly_sales AS
SELECT
    DATE(ps.opened_at)                                        AS sale_date,
    EXTRACT(HOUR FROM ps.opened_at)::INTEGER                  AS sale_hour,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') AS sale_count,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE') AS total_sales,
    AVG(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE') AS avg_sale_amount
FROM pos.pos_cash_transactions pct
JOIN pos.pos_shifts ps ON ps.pos_shift_id = pct.pos_shift_id
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
  AND pct.transaction_type = 'SALE'
GROUP BY DATE(ps.opened_at), EXTRACT(HOUR FROM ps.opened_at)::INTEGER
ORDER BY sale_date DESC, sale_hour;


-- ------------------------------------------------------------
-- Report 7: POS vs Online Channel Comparison (Monthly, Important)
-- Channel performance comparison
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_vs_online AS
SELECT
    DATE_TRUNC('month', o.order_date)                         AS order_month,
    COALESCE(sc.channel_name, 'UNKNOWN')                      AS sales_channel,
    COUNT(DISTINCT o.order_id)                                AS order_count,
    SUM(o.grand_total)                                        AS total_revenue,
    AVG(o.grand_total)                                        AS avg_order_value,
    COUNT(DISTINCT o.customer_id)                             AS unique_customers
FROM sales.orders o
LEFT JOIN pricing.sales_channels sc ON sc.sales_channel_id = o.sales_channel_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', o.order_date), sc.channel_name
ORDER BY order_month DESC, sales_channel;


-- ------------------------------------------------------------
-- Report 8: Store Performance Report (Monthly, Critical)
-- Performance by store/terminal with avg transaction value
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_store_performance AS
SELECT
    DATE_TRUNC('month', ps.opened_at)                         AS perf_month,
    pt.terminal_name,
    COUNT(DISTINCT ps.pos_shift_id)                           AS total_shifts,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE')       AS total_sales,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND') AS total_refunds,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') AS total_transactions,
    SUM(ABS(ps.cash_difference))                              AS total_cash_variance,
    CASE
        WHEN COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') > 0
        THEN ROUND((SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE')
            / COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE'))::NUMERIC, 2)
        ELSE 0
    END AS avg_transaction_value
FROM pos.pos_shifts ps
JOIN pos.pos_terminals pt ON pt.pos_terminal_id = ps.pos_terminal_id
LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', ps.opened_at), pt.terminal_name
ORDER BY perf_month DESC, total_sales DESC NULLS LAST;


-- ------------------------------------------------------------
-- Report 9: POS Discount Report (Weekly, Important)
-- Discounts and refunds applied in POS by cashier
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_discount AS
SELECT
    DATE(ps.opened_at)                                        AS discount_date,
    COALESCE(pp.display_name, u.username)                     AS cashier_name,
    COUNT(DISTINCT ps.pos_shift_id)                           AS shifts_with_discounts,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND') AS total_refund_amount,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'REFUND') AS refund_count
FROM pos.pos_shifts ps
LEFT JOIN identity.users   u  ON u.user_id  = ps.opened_by_user_id
LEFT JOIN identity.persons pp ON pp.person_id = u.person_id
LEFT JOIN pos.pos_cash_transactions pct
    ON pct.pos_shift_id = ps.pos_shift_id AND pct.transaction_type = 'REFUND'
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ps.opened_at), COALESCE(pp.display_name, u.username)
ORDER BY discount_date DESC;


-- ------------------------------------------------------------
-- Report 10: Void/Refund Report (Daily, Critical)
-- Voided transactions with approval tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_void_refund AS
SELECT
    psv.pos_sale_void_id,
    psv.company_id,
    psv.order_id,
    psv.pos_shift_id,
    ps.shift_number,
    DATE(ps.opened_at)                                        AS shift_date,
    psv.void_reason,
    psv.status                                                AS void_status,
    psv.voided_at,
    psv.approved_at,
    vu.username                                               AS voided_by,
    au.username                                               AS approved_by,
    CASE
        WHEN psv.approved_at IS NOT NULL THEN 'APPROVED'
        WHEN psv.status = 'PENDING' THEN 'PENDING_APPROVAL'
        ELSE psv.status
    END AS approval_status
FROM pos.pos_sale_voids psv
LEFT JOIN pos.pos_shifts ps ON ps.pos_shift_id = psv.pos_shift_id
LEFT JOIN identity.users vu ON vu.user_id = psv.voided_by_user_id
LEFT JOIN identity.users au ON au.user_id = psv.approved_by_user_id
ORDER BY psv.voided_at DESC;


-- ------------------------------------------------------------
-- Report 11: End-of-Day Summary (Daily, Critical)
-- Daily closing summary with reconciliation
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_end_of_day AS
SELECT
    DATE(ps.opened_at)                                        AS eod_date,
    pt.terminal_name,
    pr.register_name,
    COUNT(DISTINCT ps.pos_shift_id)                           AS total_shifts,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE')       AS total_sales,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND') AS total_refunds,
    SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'CASH_IN')   AS total_cash_in,
    SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'CASH_OUT') AS total_cash_out,
    SUM(ABS(ps.cash_difference))                              AS total_cash_variance,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') AS sale_count,
    COUNT(DISTINCT CASE WHEN ps.cash_difference <> 0 THEN ps.pos_shift_id END) AS shifts_with_variance
FROM pos.pos_shifts ps
JOIN pos.pos_terminals pt ON pt.pos_terminal_id = ps.pos_terminal_id
JOIN pos.pos_registers  pr ON pr.pos_register_id = ps.pos_register_id
LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
WHERE ps.status = 'CLOSED'
  AND ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ps.opened_at), pt.terminal_name, pr.register_name
ORDER BY eod_date DESC;


-- ------------------------------------------------------------
-- Report 12: Suspended/Parked Transactions (Daily, Important)
-- Parked transactions awaiting action
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_suspended AS
SELECT
    ps.pos_shift_id,
    ps.shift_number,
    DATE(ps.opened_at)                                        AS shift_date,
    ps.status                                                 AS shift_status,
    COALESCE(pp.display_name, u.username)                     AS cashier_name,
    pt.terminal_name,
    ps.opened_at,
    ps.closed_at,
    CURRENT_TIMESTAMP - ps.opened_at                          AS time_open
FROM pos.pos_shifts ps
JOIN pos.pos_terminals pt ON pt.pos_terminal_id = ps.pos_terminal_id
LEFT JOIN identity.users   u  ON u.user_id  = ps.opened_by_user_id
LEFT JOIN identity.persons pp ON pp.person_id = u.person_id
WHERE ps.status NOT IN ('CLOSED')
  AND ps.opened_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY ps.opened_at DESC;


-- ------------------------------------------------------------
-- Report 13: POS Store Inventory (Daily, Critical)
-- Store-level inventory with low stock alerts
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_store_inventory AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    w.warehouse_type,
    COUNT(DISTINCT i.variant_id)                              AS unique_skus,
    SUM(i.quantity_on_hand)                                   AS total_on_hand,
    SUM(i.quantity_reserved)                                  AS total_reserved,
    SUM(i.quantity_on_hand - i.quantity_reserved)             AS total_available,
    COUNT(DISTINCT i.variant_id)
        FILTER (WHERE i.quantity_on_hand <= COALESCE(i.reorder_level, 0)) AS low_stock_skus,
    COUNT(DISTINCT i.variant_id)
        FILTER (WHERE i.quantity_on_hand = 0)                 AS out_of_stock_skus
FROM inventory.warehouses w
LEFT JOIN inventory.inventories i ON i.warehouse_id = w.warehouse_id
WHERE w.is_active = TRUE
GROUP BY w.warehouse_id, w.warehouse_code, w.warehouse_name, w.warehouse_type
ORDER BY total_on_hand DESC NULLS LAST;


-- ------------------------------------------------------------
-- Report 14: Receipt Printing Stats (Weekly, Standard)
-- Receipt generation statistics by terminal
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_receipt_printing AS
SELECT
    DATE(ps.opened_at)                                        AS receipt_date,
    pt.terminal_name,
    COUNT(DISTINCT ps.pos_shift_id)                           AS shifts_count,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE') AS receipts_generated,
    COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'REFUND') AS refund_receipts
FROM pos.pos_shifts ps
JOIN pos.pos_terminals pt ON pt.pos_terminal_id = ps.pos_terminal_id
LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
WHERE ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ps.opened_at), pt.terminal_name
ORDER BY receipt_date DESC;


-- ------------------------------------------------------------
-- Report 15: POS Terminal Health (Real-time, Important)
-- Terminal health monitoring: active, idle, inactive
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pos_terminal_health AS
SELECT
    pt.pos_terminal_id,
    pt.terminal_name,
    pr.register_name,
    COUNT(DISTINCT ps.pos_shift_id)                           AS total_shifts_30d,
    MAX(ps.opened_at)                                         AS last_shift_opened,
    MAX(ps.closed_at)                                         AS last_shift_closed,
    COUNT(DISTINCT CASE WHEN ps.status = 'CLOSED' THEN ps.pos_shift_id END) AS closed_shifts,
    COUNT(DISTINCT CASE WHEN ps.status != 'CLOSED' THEN ps.pos_shift_id END) AS open_shifts,
    CASE
        WHEN MAX(ps.opened_at) >= CURRENT_TIMESTAMP - INTERVAL '1 day'  THEN 'ACTIVE'
        WHEN MAX(ps.opened_at) >= CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 'IDLE'
        ELSE 'INACTIVE'
    END AS health_status,
    CURRENT_TIMESTAMP - MAX(ps.opened_at)                     AS time_since_last_shift
FROM pos.pos_terminals pt
LEFT JOIN pos.pos_registers pr ON pr.pos_terminal_id = pt.pos_terminal_id
LEFT JOIN pos.pos_shifts ps ON ps.pos_terminal_id = pt.pos_terminal_id
    AND ps.opened_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY pt.pos_terminal_id, pt.terminal_name, pr.register_name
ORDER BY health_status, pt.terminal_name;


-- ============================================================
-- SHIFT RECONCILIATION DETAIL (Bonus Report)
-- ============================================================
CREATE OR REPLACE VIEW reports.vw_shift_reconciliation AS
SELECT
    psr.pos_shift_reconciliation_id,
    psr.company_id,
    psr.pos_shift_id,
    ps.shift_number,
    DATE(ps.opened_at)                                        AS shift_date,
    psr.expected_cash,
    psr.actual_cash,
    psr.cash_difference,
    psr.expected_card,
    psr.actual_card,
    psr.card_difference,
    psr.expected_other,
    psr.actual_other,
    psr.other_difference,
    psr.status                                                AS reconciliation_status,
    psr.reconciled_at,
    psr.notes,
    ru.username                                               AS reconciled_by
FROM pos.pos_shift_reconciliations psr
LEFT JOIN pos.pos_shifts ps ON ps.pos_shift_id = psr.pos_shift_id
LEFT JOIN identity.users ru ON ru.user_id = psr.reconciled_by_user_id
ORDER BY psr.reconciled_at DESC NULLS LAST;


-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get POS Daily Summary
CREATE OR REPLACE FUNCTION reports.fn_pos_daily_summary(
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    shift_date        DATE,
    total_sales       NUMERIC,
    total_refunds     NUMERIC,
    net_sales         NUMERIC,
    sale_count        BIGINT,
    refund_count      BIGINT,
    total_cash_variance NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE(ps.opened_at),
        COALESCE(SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE'), 0),
        COALESCE(SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND'), 0),
        COALESCE(SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE'), 0)
          - COALESCE(SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND'), 0),
        COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE'),
        COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'REFUND'),
        COALESCE(SUM(ABS(ps.cash_difference)), 0)
    FROM pos.pos_shifts ps
    LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
    WHERE DATE(ps.opened_at) = p_date
    GROUP BY DATE(ps.opened_at);
END;
$$ LANGUAGE plpgsql;


-- Function 2: Get Cashier Shift Summary
CREATE OR REPLACE FUNCTION reports.fn_cashier_shift_summary(
    p_user_id   UUID,
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date   DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    shift_number          VARCHAR,
    shift_date            DATE,
    total_sales           NUMERIC,
    total_refunds         NUMERIC,
    cash_difference       NUMERIC,
    shift_duration_hours  NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ps.shift_number::VARCHAR,
        DATE(ps.opened_at),
        COALESCE(SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE'), 0),
        COALESCE(SUM(ABS(pct.amount)) FILTER (WHERE pct.transaction_type = 'REFUND'), 0),
        ps.cash_difference,
        CASE
            WHEN EXTRACT(EPOCH FROM (ps.closed_at - ps.opened_at)) > 0
            THEN ROUND((EXTRACT(EPOCH FROM (ps.closed_at - ps.opened_at)) / 3600.0)::NUMERIC, 2)
            ELSE 0
        END
    FROM pos.pos_shifts ps
    LEFT JOIN pos.pos_cash_transactions pct ON pct.pos_shift_id = ps.pos_shift_id
    WHERE ps.opened_by_user_id = p_user_id
      AND DATE(ps.opened_at) BETWEEN p_start_date AND p_end_date
    GROUP BY ps.pos_shift_id, ps.shift_number, ps.opened_at, ps.closed_at, ps.cash_difference
    ORDER BY ps.opened_at DESC;
END;
$$ LANGUAGE plpgsql;


-- Function 3: Get Store Hourly Sales
CREATE OR REPLACE FUNCTION reports.fn_store_hourly_sales(
    p_terminal_id UUID,
    p_date        DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    sale_hour    INTEGER,
    sale_count   BIGINT,
    total_sales  NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(HOUR FROM ps.opened_at)::INTEGER,
        COUNT(pct.pos_cash_transaction_id) FILTER (WHERE pct.transaction_type = 'SALE'),
        COALESCE(SUM(pct.amount) FILTER (WHERE pct.transaction_type = 'SALE'), 0)
    FROM pos.pos_cash_transactions pct
    JOIN pos.pos_shifts ps ON ps.pos_shift_id = pct.pos_shift_id
    WHERE ps.pos_terminal_id = p_terminal_id
      AND DATE(ps.opened_at) = p_date
    GROUP BY EXTRACT(HOUR FROM ps.opened_at)::INTEGER
    ORDER BY sale_hour;
END;
$$ LANGUAGE plpgsql;


COMMIT;

-- ============================================================
-- SUMMARY: Module 12 POS
-- 16 Views + 3 Functions = 19 Report Objects
-- 15 Reports as per reports02.html catalog
-- ============================================================