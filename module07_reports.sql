BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 07: PURCHASING & SUPPLIER MANAGEMENT REPORTING
-- 16 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Purchase Order Summary (Daily, Critical)
-- All POs by status/supplier
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_purchase_order_summary AS
SELECT
    DATE(po.po_date)                          AS po_date,
    s.supplier_code,
    s.supplier_name,
    psl.code                                  AS po_status,
    psl.name                                  AS status_name,
    COUNT(DISTINCT po.purchase_order_id)      AS po_count,
    SUM(po.grand_total)                       AS total_amount,
    SUM(po.paid_amount)                       AS total_paid,
    SUM(po.outstanding_amount)                AS total_outstanding,
    COUNT(DISTINCT poi.purchase_order_item_id) AS item_count
FROM purchasing.purchase_orders po
JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
JOIN purchasing.po_status_lookup psl ON psl.po_status_id = po.po_status_id
LEFT JOIN purchasing.purchase_order_items poi ON poi.purchase_order_id = po.purchase_order_id
WHERE po.po_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(po.po_date), s.supplier_code, s.supplier_name, psl.code, psl.name
ORDER BY po_date DESC;

-- ------------------------------------------------------------
-- Report 2: Supplier Performance (Monthly, Critical)
-- Delivery, quality, pricing metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_supplier_performance AS
SELECT
    s.supplier_id,
    s.supplier_code,
    s.supplier_name,
    s.rating,
    COUNT(DISTINCT po.purchase_order_id)      AS total_orders,
    SUM(po.grand_total)                       AS total_amount,
    AVG(po.grand_total)                       AS avg_order_value,
    COUNT(DISTINCT CASE WHEN psl.code IN ('RECEIVED', 'PAID', 'CLOSED') THEN po.purchase_order_id END) AS completed_orders,
    COUNT(DISTINCT CASE WHEN psl.code = 'CANCELLED' THEN po.purchase_order_id END) AS cancelled_orders,
    s.on_time_delivery_rate,
    s.quality_score,
    AVG(sr.overall_score)                     AS avg_rating
FROM purchasing.suppliers s
LEFT JOIN purchasing.purchase_orders po ON po.supplier_id = s.supplier_id
LEFT JOIN purchasing.po_status_lookup psl ON psl.po_status_id = po.po_status_id
LEFT JOIN purchasing.supplier_ratings sr ON sr.supplier_id = s.supplier_id
WHERE s.is_active = TRUE
GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.rating, s.on_time_delivery_rate, s.quality_score
ORDER BY total_amount DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 3: Goods Receipt Report (Daily, Critical)
-- Received goods and inspection
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_goods_receipt_report AS
SELECT
    gr.goods_receipt_id,
    gr.receipt_number,
    gr.receipt_date,
    po.po_number,
    s.supplier_name,
    rsl.code                                  AS receipt_status,
    gr.total_items,
    gr.total_quantity,
    gr.accepted_quantity,
    gr.rejected_quantity,
    gr.inspection_required,
    gr.inspection_completed,
    gr.inspection_notes,
    w.warehouse_name
FROM purchasing.goods_receipts gr
JOIN purchasing.purchase_orders po ON po.purchase_order_id = gr.purchase_order_id
JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
JOIN purchasing.receipt_status_lookup rsl ON rsl.receipt_status_id = gr.receipt_status_id
LEFT JOIN inventory.warehouses w ON w.warehouse_id = gr.warehouse_id
WHERE gr.receipt_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY gr.receipt_date DESC;

-- ------------------------------------------------------------
-- Report 4: Purchase Order Aging (Weekly, Important)
-- Outstanding POs by age
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_po_aging AS
SELECT
    po.purchase_order_id,
    po.po_number,
    po.po_date,
    po.grand_total,
    po.outstanding_amount,
    s.supplier_name,
    psl.code                                  AS po_status,
    CURRENT_DATE - po.po_date                 AS days_pending,
    CASE
        WHEN CURRENT_DATE - po.po_date <= 7 THEN '0-7 Days'
        WHEN CURRENT_DATE - po.po_date <= 30 THEN '8-30 Days'
        WHEN CURRENT_DATE - po.po_date <= 60 THEN '31-60 Days'
        ELSE '60+ Days'
    END AS aging_bucket
FROM purchasing.purchase_orders po
JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
JOIN purchasing.po_status_lookup psl ON psl.po_status_id = po.po_status_id
WHERE psl.code IN ('APPROVED', 'SENT', 'PARTIALLY_RECEIVED', 'RECEIVED', 'PARTIALLY_INVOICED', 'INVOICED')
  AND po.outstanding_amount > 0
ORDER BY days_pending DESC;

-- ------------------------------------------------------------
-- Report 5: Supplier Invoice Report (Weekly, Critical)
-- Unpaid invoices by age
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_supplier_invoice_report AS
SELECT
    si.supplier_invoice_id,
    si.invoice_number,
    si.invoice_date,
    si.due_date,
    si.grand_total,
    si.paid_amount,
    si.outstanding_amount,
    s.supplier_name,
    sil.code                                  AS invoice_status,
    po.po_number,
    si.po_matched,
    si.receipt_matched,
    si.match_completed,
    CURRENT_DATE - si.invoice_date            AS days_pending,
    CASE
        WHEN CURRENT_DATE <= si.due_date THEN 'Current'
        WHEN CURRENT_DATE - si.due_date <= 30 THEN '1-30 Days Overdue'
        WHEN CURRENT_DATE - si.due_date <= 60 THEN '31-60 Days Overdue'
        ELSE '60+ Days Overdue'
    END AS aging_bucket
FROM purchasing.supplier_invoices si
JOIN purchasing.suppliers s ON s.supplier_id = si.supplier_id
JOIN purchasing.supplier_invoice_status_lookup sil ON sil.supplier_invoice_status_id = si.supplier_invoice_status_id
LEFT JOIN purchasing.purchase_orders po ON po.purchase_order_id = si.purchase_order_id
WHERE sil.code IN ('RECEIVED', 'MATCHED', 'APPROVED', 'PARTIALLY_PAID')
  AND si.outstanding_amount > 0
ORDER BY si.due_date ASC;

-- ------------------------------------------------------------
-- Report 6: Accounts Payable (Monthly, Critical)
-- Total payables by bucket
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_accounts_payable AS
SELECT
    CASE
        WHEN CURRENT_DATE <= si.due_date THEN 'Current'
        WHEN CURRENT_DATE - si.due_date <= 30 THEN '1-30 Days'
        WHEN CURRENT_DATE - si.due_date <= 60 THEN '31-60 Days'
        WHEN CURRENT_DATE - si.due_date <= 90 THEN '61-90 Days'
        ELSE '90+ Days'
    END AS aging_bucket,
    COUNT(DISTINCT si.supplier_invoice_id)    AS invoice_count,
    SUM(si.outstanding_amount)                AS total_outstanding,
    COUNT(DISTINCT si.supplier_id)            AS supplier_count
FROM purchasing.supplier_invoices si
JOIN purchasing.supplier_invoice_status_lookup sil ON sil.supplier_invoice_status_id = si.supplier_invoice_status_id
WHERE sil.code IN ('RECEIVED', 'MATCHED', 'APPROVED', 'PARTIALLY_PAID')
  AND si.outstanding_amount > 0
GROUP BY 1
ORDER BY MIN(si.due_date);

-- ------------------------------------------------------------
-- Report 7: Purchase Return Report (Monthly, Important)
-- Returned goods to suppliers
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_purchase_return_report AS
SELECT
    pr.purchase_return_id,
    pr.return_number,
    pr.return_date,
    po.po_number,
    s.supplier_name,
    pr.return_type,
    pr.return_reason,
    pr.total_amount,
    pr.status,
    pr.shipped_to_supplier,
    pr.credit_note_received,
    pr.credit_note_amount
FROM purchasing.purchase_returns pr
JOIN purchasing.purchase_orders po ON po.purchase_order_id = pr.purchase_order_id
JOIN purchasing.suppliers s ON s.supplier_id = pr.supplier_id
WHERE pr.return_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY pr.return_date DESC;

-- ------------------------------------------------------------
-- Report 8: Supplier Comparison (Quarterly, Important)
-- Compare on multiple criteria
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_supplier_comparison AS
SELECT
    s.supplier_code,
    s.supplier_name,
    s.rating,
    s.on_time_delivery_rate,
    s.quality_score,
    COUNT(DISTINCT po.purchase_order_id)      AS total_orders,
    SUM(po.grand_total)                       AS total_amount,
    AVG(po.grand_total)                       AS avg_order_value,
    COUNT(DISTINCT sp.product_id)             AS products_supplied,
    AVG(sr.overall_score)                     AS avg_rating_score
FROM purchasing.suppliers s
LEFT JOIN purchasing.purchase_orders po ON po.supplier_id = s.supplier_id
LEFT JOIN purchasing.supplier_products sp ON sp.supplier_id = s.supplier_id
LEFT JOIN purchasing.supplier_ratings sr ON sr.supplier_id = s.supplier_id
WHERE s.is_active = TRUE
GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.rating, s.on_time_delivery_rate, s.quality_score
ORDER BY s.rating DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 9: Landed Cost Analysis (Monthly, Critical)
-- Total cost including freight
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_landed_cost_analysis AS
SELECT
    po.po_number,
    po.po_date,
    s.supplier_name,
    poi.product_name,
    poi.quantity,
    poi.unit_price,
    poi.line_total,
    poi.freight_cost,
    poi.duty_cost,
    poi.other_costs,
    poi.landed_unit_cost,
    (poi.line_total + COALESCE(poi.freight_cost, 0) + COALESCE(poi.duty_cost, 0) + COALESCE(poi.other_costs, 0)) AS total_landed_cost,
    CASE
        WHEN poi.line_total > 0
        THEN ROUND(((COALESCE(poi.freight_cost, 0) + COALESCE(poi.duty_cost, 0) + COALESCE(poi.other_costs, 0)) / poi.line_total * 100)::NUMERIC, 2)
        ELSE 0
    END AS landed_cost_percent
FROM purchasing.purchase_order_items poi
JOIN purchasing.purchase_orders po ON po.purchase_order_id = poi.purchase_order_id
JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
WHERE po.po_date >= CURRENT_DATE - INTERVAL '30 days'
  AND poi.landed_unit_cost IS NOT NULL
ORDER BY po.po_date DESC;

-- ------------------------------------------------------------
-- Report 10: Purchase Price Variance (Monthly, Critical)
-- Actual vs standard cost
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_purchase_price_variance AS
SELECT
    po.po_number,
    po.po_date,
    s.supplier_name,
    poi.product_name,
    poi.unit_price                            AS actual_price,
    sp.price                                  AS standard_price,
    (poi.unit_price - COALESCE(sp.price, poi.unit_price)) AS price_variance,
    CASE
        WHEN COALESCE(sp.price, 0) > 0
        THEN ROUND(((poi.unit_price - sp.price) / sp.price * 100)::NUMERIC, 2)
        ELSE 0
    END AS variance_percent
FROM purchasing.purchase_order_items poi
JOIN purchasing.purchase_orders po ON po.purchase_order_id = poi.purchase_order_id
JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
LEFT JOIN purchasing.supplier_products sp ON sp.supplier_id = s.supplier_id AND sp.product_id = poi.product_id
LEFT JOIN purchasing.supplier_prices spr ON spr.supplier_product_id = sp.supplier_product_id AND spr.is_active = TRUE
WHERE po.po_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY po.po_date DESC;

-- ------------------------------------------------------------
-- Report 11: Supplier Rating Report (Quarterly, Important)
-- Overall ratings and reviews
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_supplier_rating_report AS
SELECT
    s.supplier_code,
    s.supplier_name,
    sr.rating_date,
    sr.delivery_score,
    sr.quality_score,
    sr.pricing_score,
    sr.communication_score,
    sr.overall_score,
    sr.comments,
    u.username                                AS rated_by
FROM purchasing.supplier_ratings sr
JOIN purchasing.suppliers s ON s.supplier_id = sr.supplier_id
LEFT JOIN identity.users u ON u.user_id = sr.rated_by_user_id
WHERE sr.rating_date >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY sr.rating_date DESC;

-- ------------------------------------------------------------
-- Report 12: Purchase Requisition Status (Daily, Important)
-- Approval workflow status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_requisition_status AS
SELECT
    pr.purchase_requisition_id,
    pr.requisition_number,
    pr.requisition_date,
    pr.required_by_date,
    pr.total_amount,
    rsl.code                                  AS requisition_status,
    pr.priority,
    pr.purpose,
    d.department_name,
    u.username                                AS requested_by,
    pr.approved_at,
    pr.converted_at
FROM purchasing.purchase_requisitions pr
JOIN purchasing.requisition_status_lookup rsl ON rsl.requisition_status_id = pr.requisition_status_id
LEFT JOIN organization.departments d ON d.department_id = pr.department_id
LEFT JOIN identity.users u ON u.user_id = pr.requested_by_user_id
WHERE pr.requisition_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY pr.requisition_date DESC;

-- ------------------------------------------------------------
-- Report 13: Outstanding Purchase Orders (Daily, Critical)
-- Open POs awaiting delivery
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_outstanding_pos AS
SELECT
    po.purchase_order_id,
    po.po_number,
    po.po_date,
    po.expected_delivery_date,
    po.grand_total,
    s.supplier_name,
    psl.code                                  AS po_status,
    CURRENT_DATE - po.expected_delivery_date  AS days_overdue,
    CASE
        WHEN po.expected_delivery_date IS NULL THEN 'No ETA'
        WHEN CURRENT_DATE <= po.expected_delivery_date THEN 'On Track'
        WHEN CURRENT_DATE - po.expected_delivery_date <= 7 THEN '1-7 Days Late'
        ELSE '7+ Days Late'
    END AS delivery_status
FROM purchasing.purchase_orders po
JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
JOIN purchasing.po_status_lookup psl ON psl.po_status_id = po.po_status_id
WHERE psl.code IN ('APPROVED', 'SENT', 'PARTIALLY_RECEIVED')
ORDER BY po.expected_delivery_date ASC NULLS LAST;

-- ------------------------------------------------------------
-- Report 14: Supplier Payment Schedule (Weekly, Critical)
-- Upcoming payment due dates
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_supplier_payment_schedule AS
SELECT
    si.supplier_invoice_id,
    si.invoice_number,
    si.invoice_date,
    si.due_date,
    si.outstanding_amount,
    s.supplier_name,
    pt.terms_name,
    pt.days_to_pay,
    CASE
        WHEN si.due_date IS NULL THEN 'No Due Date'
        WHEN CURRENT_DATE <= si.due_date THEN 'Upcoming'
        ELSE 'Overdue'
    END AS payment_status,
    si.due_date - CURRENT_DATE                AS days_until_due
FROM purchasing.supplier_invoices si
JOIN purchasing.suppliers s ON s.supplier_id = si.supplier_id
LEFT JOIN purchasing.payment_terms pt ON pt.payment_terms_id = s.payment_terms_id
WHERE si.outstanding_amount > 0
  AND si.supplier_invoice_status_id IN (
    SELECT supplier_invoice_status_id FROM purchasing.supplier_invoice_status_lookup WHERE code IN ('RECEIVED', 'MATCHED', 'APPROVED', 'PARTIALLY_PAID')
  )
ORDER BY si.due_date ASC NULLS LAST;

-- ------------------------------------------------------------
-- Report 15: Three-Way Match Exceptions (Daily, Critical)
-- PO/Receipt/Invoice mismatches
-- ------------------------------------------------------------
CREATE VIEW reports.vw_three_way_match_exceptions AS
SELECT
    twme.three_way_match_exception_id,
    si.invoice_number,
    po.po_number,
    gr.receipt_number,
    twme.exception_type,
    twme.description,
    twme.po_amount,
    twme.receipt_amount,
    twme.invoice_amount,
    twme.variance_amount,
    twme.status,
    twme.created_at,
    twme.resolved_at
FROM purchasing.three_way_match_exceptions twme
LEFT JOIN purchasing.supplier_invoices si ON si.supplier_invoice_id = twme.supplier_invoice_id
LEFT JOIN purchasing.purchase_orders po ON po.purchase_order_id = twme.purchase_order_id
LEFT JOIN purchasing.goods_receipts gr ON gr.goods_receipt_id = twme.goods_receipt_id
WHERE twme.status IN ('OPEN', 'INVESTIGATING', 'DISPUTED')
ORDER BY twme.created_at DESC;

-- ------------------------------------------------------------
-- Report 16: Purchase Budget vs Actual (Monthly, Critical)
-- Budget compliance
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_purchase_budget_vs_actual AS
SELECT
    DATE_TRUNC('month', po.po_date)           AS budget_month,
    s.supplier_name,
    COUNT(DISTINCT po.purchase_order_id)      AS po_count,
    SUM(po.grand_total)                       AS actual_amount,
    SUM(po.paid_amount)                       AS paid_amount,
    SUM(po.outstanding_amount)                AS outstanding_amount
FROM purchasing.purchase_orders po
JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
WHERE po.po_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', po.po_date), s.supplier_name
ORDER BY budget_month DESC;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get PO Summary by Period
CREATE OR REPLACE FUNCTION reports.fn_po_summary(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    po_date DATE,
    po_count BIGINT,
    total_amount NUMERIC,
    avg_po_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        po.po_date,
        COUNT(DISTINCT po.purchase_order_id),
        SUM(po.grand_total),
        AVG(po.grand_total)
    FROM purchasing.purchase_orders po
    WHERE po.po_date BETWEEN p_start_date AND p_end_date
    GROUP BY po.po_date
    ORDER BY po.po_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Supplier Performance
CREATE OR REPLACE FUNCTION reports.fn_supplier_performance(
    p_supplier_id UUID
)
RETURNS TABLE (
    supplier_code VARCHAR,
    supplier_name VARCHAR,
    total_orders BIGINT,
    total_amount NUMERIC,
    avg_order_value NUMERIC,
    avg_rating NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.supplier_code::VARCHAR,
        s.supplier_name::VARCHAR,
        COUNT(DISTINCT po.purchase_order_id),
        COALESCE(SUM(po.grand_total), 0),
        COALESCE(AVG(po.grand_total), 0),
        COALESCE(AVG(sr.overall_score), 0)
    FROM purchasing.suppliers s
    LEFT JOIN purchasing.purchase_orders po ON po.supplier_id = s.supplier_id
    LEFT JOIN purchasing.supplier_ratings sr ON sr.supplier_id = s.supplier_id
    WHERE s.supplier_id = p_supplier_id
    GROUP BY s.supplier_code, s.supplier_name;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get AP Aging Summary
CREATE OR REPLACE FUNCTION reports.fn_ap_aging_summary()
RETURNS TABLE (
    aging_bucket VARCHAR,
    invoice_count BIGINT,
    total_outstanding NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN CURRENT_DATE <= si.due_date THEN 'Current'
            WHEN CURRENT_DATE - si.due_date <= 30 THEN '1-30 Days'
            WHEN CURRENT_DATE - si.due_date <= 60 THEN '31-60 Days'
            WHEN CURRENT_DATE - si.due_date <= 90 THEN '61-90 Days'
            ELSE '90+ Days'
        END::VARCHAR,
        COUNT(DISTINCT si.supplier_invoice_id),
        COALESCE(SUM(si.outstanding_amount), 0)
    FROM purchasing.supplier_invoices si
    JOIN purchasing.supplier_invoice_status_lookup sil ON sil.supplier_invoice_status_id = si.supplier_invoice_status_id
    WHERE sil.code IN ('RECEIVED', 'MATCHED', 'APPROVED', 'PARTIALLY_PAID')
      AND si.outstanding_amount > 0
    GROUP BY 1
    ORDER BY MIN(si.due_date);
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Outstanding POs
CREATE OR REPLACE FUNCTION reports.fn_outstanding_pos(
    p_supplier_id UUID DEFAULT NULL
)
RETURNS TABLE (
    po_number VARCHAR,
    po_date DATE,
    expected_delivery_date DATE,
    grand_total NUMERIC,
    supplier_name VARCHAR,
    days_overdue INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        po.po_number::VARCHAR,
        po.po_date,
        po.expected_delivery_date,
        po.grand_total,
        s.supplier_name::VARCHAR,
        CASE WHEN po.expected_delivery_date IS NOT NULL THEN CURRENT_DATE - po.expected_delivery_date ELSE NULL END
    FROM purchasing.purchase_orders po
    JOIN purchasing.suppliers s ON s.supplier_id = po.supplier_id
    JOIN purchasing.po_status_lookup psl ON psl.po_status_id = po.po_status_id
    WHERE psl.code IN ('APPROVED', 'SENT', 'PARTIALLY_RECEIVED')
      AND (p_supplier_id IS NULL OR po.supplier_id = p_supplier_id)
    ORDER BY po.expected_delivery_date ASC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Three-Way Match Status
CREATE OR REPLACE FUNCTION reports.fn_three_way_match_status(
    p_supplier_invoice_id UUID
)
RETURNS TABLE (
    invoice_number VARCHAR,
    po_number VARCHAR,
    receipt_number VARCHAR,
    po_matched BOOLEAN,
    receipt_matched BOOLEAN,
    match_completed BOOLEAN,
    exception_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        si.invoice_number::VARCHAR,
        po.po_number::VARCHAR,
        gr.receipt_number::VARCHAR,
        si.po_matched,
        si.receipt_matched,
        si.match_completed,
        COUNT(DISTINCT twme.three_way_match_exception_id)
    FROM purchasing.supplier_invoices si
    LEFT JOIN purchasing.purchase_orders po ON po.purchase_order_id = si.purchase_order_id
    LEFT JOIN purchasing.goods_receipts gr ON gr.purchase_order_id = si.purchase_order_id
    LEFT JOIN purchasing.three_way_match_exceptions twme ON twme.supplier_invoice_id = si.supplier_invoice_id AND twme.status = 'OPEN'
    WHERE si.supplier_invoice_id = p_supplier_invoice_id
    GROUP BY si.supplier_invoice_id, si.invoice_number, po.po_number, gr.receipt_number, si.po_matched, si.receipt_matched, si.match_completed;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 07 Purchasing & Suppliers
-- 16 Views + 5 Functions = 21 Report Objects
-- 16 Reports as per reports02.html catalog
-- ============================================================