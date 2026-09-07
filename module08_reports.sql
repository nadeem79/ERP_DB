BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 08: SALES ORDERS / ORDER MANAGEMENT REPORTING
-- 17 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Sales Order Summary (Daily, Critical)
-- All orders by status/channel
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_order_summary AS
SELECT
    DATE(o.order_date)                          AS order_date,
    scl.code                                    AS sales_channel,
    scl.name                                    AS channel_name,
    osl.code                                    AS order_status,
    osl.name                                    AS status_name,
    COUNT(DISTINCT o.order_id)                  AS order_count,
    SUM(o.grand_total)                          AS total_amount,
    SUM(o.paid_amount)                          AS total_paid,
    SUM(o.outstanding_amount)                   AS total_outstanding,
    COUNT(DISTINCT o.customer_id)               AS unique_customers
FROM sales.orders o
JOIN sales.sales_channel_lookup scl ON scl.sales_channel_id = o.sales_channel_id
JOIN sales.order_status_lookup osl ON osl.order_status_id = o.order_status_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(o.order_date), scl.code, scl.name, osl.code, osl.name
ORDER BY order_date DESC;

-- ------------------------------------------------------------
-- Report 2: Sales Trends (Daily/Weekly/Monthly, Critical)
-- Sales trends over time
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_trends AS
SELECT
    DATE_TRUNC('day', o.order_date)             AS trend_date,
    DATE_TRUNC('week', o.order_date)            AS trend_week,
    DATE_TRUNC('month', o.order_date)           AS trend_month,
    COUNT(DISTINCT o.order_id)                  AS order_count,
    SUM(o.grand_total)                          AS total_revenue,
    AVG(o.grand_total)                          AS avg_order_value,
    COUNT(DISTINCT o.customer_id)               AS unique_customers,
    COUNT(DISTINCT oi.order_item_id)            AS items_sold
FROM sales.orders o
LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('day', o.order_date), DATE_TRUNC('week', o.order_date), DATE_TRUNC('month', o.order_date)
ORDER BY trend_date DESC;

-- ------------------------------------------------------------
-- Report 3: Sales by Channel (Weekly, Critical)
-- Performance by channel
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_by_channel AS
SELECT
    scl.code                                    AS channel_code,
    scl.name                                    AS channel_name,
    scl.channel_type,
    COUNT(DISTINCT o.order_id)                  AS order_count,
    SUM(o.grand_total)                          AS total_revenue,
    AVG(o.grand_total)                          AS avg_order_value,
    COUNT(DISTINCT o.customer_id)               AS unique_customers,
    ROUND((COUNT(DISTINCT o.order_id)::NUMERIC /
        NULLIF(SUM(COUNT(DISTINCT o.order_id)) OVER (), 0) * 100), 2) AS percent_of_orders
FROM sales.orders o
JOIN sales.sales_channel_lookup scl ON scl.sales_channel_id = o.sales_channel_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY scl.sales_channel_id, scl.code, scl.name, scl.channel_type
ORDER BY total_revenue DESC;

-- ------------------------------------------------------------
-- Report 4: Sales by Customer (Weekly, Critical)
-- Top customers by revenue
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_by_customer AS
SELECT
    c.customer_id,
    c.customer_number,
    c.display_name,
    c.email,
    COUNT(DISTINCT o.order_id)                  AS order_count,
    SUM(o.grand_total)                          AS total_revenue,
    AVG(o.grand_total)                          AS avg_order_value,
    MAX(o.order_date)                           AS last_order_date,
    MIN(o.order_date)                           AS first_order_date
FROM sales.orders o
JOIN crm.customers c ON c.customer_id = o.customer_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.customer_id, c.customer_number, c.display_name, c.email
ORDER BY total_revenue DESC
LIMIT 100;

-- ------------------------------------------------------------
-- Report 5: Sales by Product (Weekly, Critical)
-- Top products by revenue
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_by_product AS
SELECT
    p.product_id,
    p.product_code,
    p.product_name,
    COUNT(DISTINCT oi.order_item_id)            AS times_sold,
    SUM(oi.quantity)                            AS total_quantity_sold,
    SUM(oi.line_total)                          AS total_revenue,
    AVG(oi.unit_price)                          AS avg_selling_price,
    SUM(oi.margin_amount)                       AS total_margin
FROM sales.order_items oi
JOIN catalog.products p ON p.product_id = oi.product_id
JOIN sales.orders o ON o.order_id = oi.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY total_revenue DESC
LIMIT 100;

-- ------------------------------------------------------------
-- Report 6: Sales by Category (Monthly, Important)
-- Revenue by product category
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_by_category AS
SELECT
    cat.category_name,
    COUNT(DISTINCT oi.order_item_id)            AS items_sold,
    SUM(oi.quantity)                            AS total_quantity,
    SUM(oi.line_total)                          AS total_revenue,
    SUM(oi.margin_amount)                       AS total_margin
FROM sales.order_items oi
JOIN catalog.products p ON p.product_id = oi.product_id
LEFT JOIN catalog.categories cat ON cat.category_id = p.category_id
JOIN sales.orders o ON o.order_id = oi.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY cat.category_name
ORDER BY total_revenue DESC;

-- ------------------------------------------------------------
-- Report 7: Order Aging (Weekly, Important)
-- Outstanding orders by age
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_aging AS
SELECT
    o.order_id,
    o.order_number,
    o.order_date,
    o.grand_total,
    o.paid_amount,
    o.outstanding_amount,
    osl.code                                    AS order_status,
    scl.name                                    AS channel_name,
    c.display_name                              AS customer_name,
    CURRENT_DATE - o.order_date                 AS days_pending,
    CASE
        WHEN CURRENT_DATE - o.order_date <= 7 THEN '0-7 Days'
        WHEN CURRENT_DATE - o.order_date <= 30 THEN '8-30 Days'
        WHEN CURRENT_DATE - o.order_date <= 60 THEN '31-60 Days'
        ELSE '60+ Days'
    END AS aging_bucket
FROM sales.orders o
JOIN sales.order_status_lookup osl ON osl.order_status_id = o.order_status_id
JOIN sales.sales_channel_lookup scl ON scl.sales_channel_id = o.sales_channel_id
LEFT JOIN crm.customers c ON c.customer_id = o.customer_id
WHERE osl.code IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'ON_HOLD')
  AND o.outstanding_amount > 0
ORDER BY days_pending DESC;

-- ------------------------------------------------------------
-- Report 8: Order Hold Report (Daily, Critical)
-- Orders on hold with reasons
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_hold_report AS
SELECT
    o.order_id,
    o.order_number,
    o.order_date,
    o.grand_total,
    o.customer_name,
    oh.hold_notes,
    oh.held_at,
    oh.is_active                                AS is_still_on_hold,
    hr.name                                     AS hold_reason,
    hr.requires_approval
FROM sales.order_holds oh
JOIN sales.orders o ON o.order_id = oh.order_id
JOIN sales.order_hold_reason_lookup hr ON hr.order_hold_reason_id = oh.hold_reason_id
WHERE oh.is_active = TRUE
ORDER BY oh.held_at DESC;

-- ------------------------------------------------------------
-- Report 9: Order Cancellation Report (Daily, Critical)
-- Cancelled orders with reasons
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_cancellation_report AS
SELECT
    o.order_id,
    o.order_number,
    o.order_date,
    o.grand_total,
    o.customer_name,
    oc.cancellation_notes,
    oc.is_customer_initiated,
    oc.refund_required,
    oc.refund_amount,
    oc.refund_status,
    crl.name                                    AS cancellation_reason,
    oc.cancelled_at
FROM sales.order_cancellations oc
JOIN sales.orders o ON o.order_id = oc.order_id
JOIN sales.order_cancellation_reason_lookup crl ON crl.order_cancellation_reason_id = oc.cancellation_reason_id
WHERE oc.cancelled_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY oc.cancelled_at DESC;

-- ------------------------------------------------------------
-- Report 10: Order Fulfillment Report (Daily, Critical)
-- Fulfillment status tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_fulfillment_report AS
SELECT
    of_fulfill.order_fulfillment_id,
    of_fulfill.fulfillment_number,
    o.order_number,
    o.order_date,
    o.customer_name,
    of_fulfill.fulfillment_status,
    of_fulfill.fulfilled_at,
    w.warehouse_name,
    COUNT(DISTINCT ofi.order_fulfillment_item_id) AS item_count,
    SUM(ofi.quantity)                           AS total_quantity,
    SUM(ofi.fulfilled_quantity)                 AS fulfilled_quantity
FROM sales.order_fulfillments of_fulfill
JOIN sales.orders o ON o.order_id = of_fulfill.order_id
LEFT JOIN inventory.warehouses w ON w.warehouse_id = of_fulfill.warehouse_id
LEFT JOIN sales.order_fulfillment_items ofi ON ofi.order_fulfillment_id = of_fulfill.order_fulfillment_id
GROUP BY of_fulfill.order_fulfillment_id, of_fulfill.fulfillment_number, o.order_number, o.order_date, o.customer_name, of_fulfill.fulfillment_status, of_fulfill.fulfilled_at, w.warehouse_name
ORDER BY of_fulfill.created_at DESC;

-- ------------------------------------------------------------
-- Report 11: Order Payment Status (Daily, Critical)
-- Payment tracking per order
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_payment_status AS
SELECT
    o.order_id,
    o.order_number,
    o.order_date,
    o.grand_total,
    o.paid_amount,
    o.outstanding_amount,
    o.payment_method,
    o.payment_status,
    o.is_cod,
    c.display_name                              AS customer_name,
    scl.name                                    AS channel_name
FROM sales.orders o
JOIN sales.sales_channel_lookup scl ON scl.sales_channel_id = o.sales_channel_id
LEFT JOIN crm.customers c ON c.customer_id = o.customer_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
  AND o.outstanding_amount > 0
ORDER BY o.outstanding_amount DESC;

-- ------------------------------------------------------------
-- Report 12: Order Priority Report (Daily, Important)
-- Orders by priority level
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_priority_report AS
SELECT
    opl.code                                    AS priority_code,
    opl.name                                    AS priority_name,
    COUNT(DISTINCT o.order_id)                  AS order_count,
    SUM(o.grand_total)                          AS total_amount,
    COUNT(DISTINCT CASE WHEN osl.code IN ('PENDING', 'CONFIRMED', 'PROCESSING') THEN o.order_id END) AS pending_orders,
    COUNT(DISTINCT CASE WHEN osl.code IN ('SHIPPED', 'DELIVERED', 'COMPLETED') THEN o.order_id END) AS completed_orders
FROM sales.orders o
JOIN sales.order_priority_lookup opl ON opl.order_priority_id = o.order_priority_id
JOIN sales.order_status_lookup osl ON osl.order_status_id = o.order_status_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY opl.order_priority_id, opl.code, opl.name
ORDER BY opl.sort_order;

-- ------------------------------------------------------------
-- Report 13: Order Status History (On-demand, Important)
-- Complete status history for an order
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_status_history AS
SELECT
    o.order_number,
    o.order_date,
    osh.changed_at,
    from_sl.code                                AS from_status,
    to_sl.code                                  AS to_status,
    osh.status_notes,
    u.username                                  AS changed_by
FROM sales.order_status_history osh
JOIN sales.orders o ON o.order_id = osh.order_id
LEFT JOIN sales.order_status_lookup from_sl ON from_sl.order_status_id = osh.from_status_id
JOIN sales.order_status_lookup to_sl ON to_sl.order_status_id = osh.to_status_id
LEFT JOIN identity.users u ON u.user_id = osh.changed_by_user_id
ORDER BY osh.changed_at DESC;

-- ------------------------------------------------------------
-- Report 14: Order Documents Report (On-demand, Standard)
-- Documents attached to orders
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_documents_report AS
SELECT
    o.order_number,
    o.order_date,
    od.document_type,
    od.document_title,
    od.file_name,
    od.mime_type,
    od.file_size_bytes,
    od.created_at,
    u.username                                  AS uploaded_by
FROM sales.order_documents od
JOIN sales.orders o ON o.order_id = od.order_id
LEFT JOIN identity.users u ON u.user_id = od.created_by_user_id
ORDER BY od.created_at DESC;

-- ------------------------------------------------------------
-- Report 15: Order Tags Report (On-demand, Standard)
-- Orders with tags
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_tags_report AS
SELECT
    ot.tag_name,
    ot.tag_color,
    COUNT(DISTINCT ota.order_id)                AS tagged_orders,
    SUM(o.grand_total)                          AS total_amount
FROM sales.order_tags ot
LEFT JOIN sales.order_tag_assignments ota ON ota.order_tag_id = ot.order_tag_id
LEFT JOIN sales.orders o ON o.order_id = ota.order_id
WHERE ot.is_active = TRUE
GROUP BY ot.order_tag_id, ot.tag_name, ot.tag_color
ORDER BY tagged_orders DESC;

-- ------------------------------------------------------------
-- Report 16: Order Notes Report (On-demand, Standard)
-- Notes on orders
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_order_notes_report AS
SELECT
    o.order_number,
    o.order_date,
    onote.note_type,
    onote.note_text,
    onote.is_internal,
    onote.is_visible_to_customer,
    onote.created_at,
    u.username                                  AS created_by
FROM sales.order_notes onote
JOIN sales.orders o ON o.order_id = onote.order_id
LEFT JOIN identity.users u ON u.user_id = onote.created_by_user_id
ORDER BY onote.created_at DESC;

-- ------------------------------------------------------------
-- Report 17: Sales Health Dashboard (Daily, Critical)
-- High-level sales health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM sales.orders WHERE order_date >= CURRENT_DATE - INTERVAL '7 days') AS orders_7d,
    (SELECT SUM(grand_total) FROM sales.orders WHERE order_date >= CURRENT_DATE - INTERVAL '7 days') AS revenue_7d,
    (SELECT COUNT(DISTINCT order_id) FROM sales.orders WHERE order_status_id = (SELECT order_status_id FROM sales.order_status_lookup WHERE code = 'PENDING')) AS pending_orders,
    (SELECT COUNT(DISTINCT order_id) FROM sales.orders WHERE is_on_hold = TRUE) AS orders_on_hold,
    (SELECT COUNT(DISTINCT order_id) FROM sales.orders WHERE order_status_id = (SELECT order_status_id FROM sales.order_status_lookup WHERE code = 'CANCELLED') AND order_date >= CURRENT_DATE - INTERVAL '7 days') AS cancelled_7d,
    (SELECT SUM(outstanding_amount) FROM sales.orders WHERE outstanding_amount > 0) AS total_outstanding,
    (SELECT COUNT(DISTINCT order_id) FROM sales.orders WHERE order_status_id IN (SELECT order_status_id FROM sales.order_status_lookup WHERE code IN ('SHIPPED', 'OUT_FOR_DELIVERY'))) AS in_transit_orders;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Sales Summary by Period
CREATE OR REPLACE FUNCTION reports.fn_sales_summary(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    order_date DATE,
    order_count BIGINT,
    total_revenue NUMERIC,
    avg_order_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.order_date,
        COUNT(DISTINCT o.order_id),
        SUM(o.grand_total),
        AVG(o.grand_total)
    FROM sales.orders o
    WHERE o.order_date BETWEEN p_start_date AND p_end_date
    GROUP BY o.order_date
    ORDER BY o.order_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Top Products by Period
CREATE OR REPLACE FUNCTION reports.fn_top_products(
    p_start_date DATE,
    p_end_date DATE,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    product_code VARCHAR,
    product_name VARCHAR,
    total_quantity NUMERIC,
    total_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.product_code::VARCHAR,
        p.product_name::VARCHAR,
        SUM(oi.quantity),
        SUM(oi.line_total)
    FROM sales.order_items oi
    JOIN catalog.products p ON p.product_id = oi.product_id
    JOIN sales.orders o ON o.order_id = oi.order_id
    WHERE o.order_date BETWEEN p_start_date AND p_end_date
    GROUP BY p.product_code, p.product_name
    ORDER BY total_revenue DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Order Aging Summary
CREATE OR REPLACE FUNCTION reports.fn_order_aging_summary()
RETURNS TABLE (
    aging_bucket VARCHAR,
    order_count BIGINT,
    total_outstanding NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN CURRENT_DATE - o.order_date <= 7 THEN '0-7 Days'
            WHEN CURRENT_DATE - o.order_date <= 30 THEN '8-30 Days'
            WHEN CURRENT_DATE - o.order_date <= 60 THEN '31-60 Days'
            ELSE '60+ Days'
        END::VARCHAR,
        COUNT(DISTINCT o.order_id),
        SUM(o.outstanding_amount)
    FROM sales.orders o
    JOIN sales.order_status_lookup osl ON osl.order_status_id = o.order_status_id
    WHERE osl.code IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'ON_HOLD')
      AND o.outstanding_amount > 0
    GROUP BY 1
    ORDER BY MIN(CURRENT_DATE - o.order_date);
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Channel Performance
CREATE OR REPLACE FUNCTION reports.fn_channel_performance(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    channel_code VARCHAR,
    channel_name VARCHAR,
    order_count BIGINT,
    total_revenue NUMERIC,
    avg_order_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        scl.code::VARCHAR,
        scl.name::VARCHAR,
        COUNT(DISTINCT o.order_id),
        SUM(o.grand_total),
        AVG(o.grand_total)
    FROM sales.orders o
    JOIN sales.sales_channel_lookup scl ON scl.sales_channel_id = o.sales_channel_id
    WHERE o.order_date BETWEEN p_start_date AND p_end_date
    GROUP BY scl.code, scl.name
    ORDER BY total_revenue DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Order Details
CREATE OR REPLACE FUNCTION reports.fn_order_details(
    p_order_id UUID
)
RETURNS TABLE (
    order_number VARCHAR,
    order_date DATE,
    customer_name VARCHAR,
    order_status VARCHAR,
    channel_name VARCHAR,
    grand_total NUMERIC,
    paid_amount NUMERIC,
    outstanding_amount NUMERIC,
    item_count BIGINT,
    total_items NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.order_number::VARCHAR,
        o.order_date,
        o.customer_name::VARCHAR,
        osl.code::VARCHAR,
        scl.name::VARCHAR,
        o.grand_total,
        o.paid_amount,
        o.outstanding_amount,
        COUNT(DISTINCT oi.order_item_id),
        SUM(oi.quantity)
    FROM sales.orders o
    JOIN sales.order_status_lookup osl ON osl.order_status_id = o.order_status_id
    JOIN sales.sales_channel_lookup scl ON scl.sales_channel_id = o.sales_channel_id
    LEFT JOIN sales.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_id = p_order_id
    GROUP BY o.order_id, o.order_number, o.order_date, o.customer_name, osl.code, scl.name, o.grand_total, o.paid_amount, o.outstanding_amount;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 08 Sales Orders
-- 17 Views + 5 Functions = 22 Report Objects
-- 17 Reports as per reports02.html catalog
-- ============================================================