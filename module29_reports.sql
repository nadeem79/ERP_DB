BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 29 — CART, CHECKOUT & SHOPPING EXPERIENCE REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- 1. Cart Summary
CREATE OR REPLACE VIEW reports.vw_cart_summary AS
SELECT
    DATE(c.created_at) AS cart_date,
    csl.code AS cart_status,
    COUNT(DISTINCT c.cart_id) AS cart_count,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COUNT(DISTINCT c.session_id) AS session_count,
    SUM(c.item_count) AS total_items,
    SUM(c.quantity_total) AS total_quantity,
    SUM(c.subtotal_amount) AS subtotal_amount,
    SUM(c.discount_amount) AS discount_amount,
    SUM(c.tax_amount) AS tax_amount,
    SUM(c.shipping_amount) AS shipping_amount,
    SUM(c.grand_total_amount) AS grand_total_amount
FROM cart.carts c
LEFT JOIN cart.cart_status_lookup csl ON csl.cart_status_id = c.cart_status_id
GROUP BY DATE(c.created_at), csl.code
ORDER BY cart_date DESC;

-- 2. Cart Item Product Summary
CREATE OR REPLACE VIEW reports.vw_cart_item_product_summary AS
SELECT
    p.product_code,
    p.product_name,
    COUNT(DISTINCT ci.cart_item_id) AS cart_item_count,
    COUNT(DISTINCT ci.cart_id) AS cart_count,
    SUM(ci.quantity) AS quantity_total,
    SUM(ci.line_total) AS cart_value,
    AVG(ci.unit_price) AS avg_unit_price
FROM cart.cart_items ci
JOIN catalog.products p ON p.product_id = ci.product_id
WHERE ci.removed_at IS NULL
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY cart_item_count DESC;

-- 3. Checkout Funnel
CREATE OR REPLACE VIEW reports.vw_checkout_funnel AS
SELECT
    DATE(ce.occurred_at) AS event_date,
    cet.code AS event_type,
    COUNT(DISTINCT ce.cart_event_id) AS event_count,
    COUNT(DISTINCT ce.cart_id) AS cart_count,
    COUNT(DISTINCT COALESCE(ce.customer_id::TEXT, ce.session_id)) AS visitor_count
FROM cart.cart_events ce
JOIN cart.cart_event_type_lookup cet ON cet.cart_event_type_id = ce.cart_event_type_id
WHERE cet.code IN (
    'CART_CREATED',
    'ITEM_ADDED',
    'CHECKOUT_STARTED',
    'ADDRESS_SELECTED',
    'SHIPPING_SELECTED',
    'PAYMENT_SELECTED',
    'ORDER_CREATED'
)
GROUP BY DATE(ce.occurred_at), cet.code
ORDER BY event_date DESC, event_type;

-- 4. Abandoned Cart Report
CREATE OR REPLACE VIEW reports.vw_abandoned_cart_report AS
SELECT
    DATE(ac.abandoned_at) AS abandoned_date,
    COUNT(DISTINCT ac.abandoned_cart_id) AS abandoned_carts,
    COUNT(DISTINCT ac.customer_id) AS abandoned_customers,
    SUM(ac.cart_value) AS abandoned_value,
    COUNT(DISTINCT CASE WHEN ac.recovered_at IS NOT NULL THEN ac.abandoned_cart_id END) AS recovered_carts,
    SUM(CASE WHEN ac.recovered_at IS NOT NULL THEN ac.cart_value ELSE 0 END) AS recovered_value,
    ROUND(
        COUNT(DISTINCT CASE WHEN ac.recovered_at IS NOT NULL THEN ac.abandoned_cart_id END)::NUMERIC
        / NULLIF(COUNT(DISTINCT ac.abandoned_cart_id), 0) * 100, 2
    ) AS recovery_rate_percent
FROM cart.abandoned_carts ac
GROUP BY DATE(ac.abandoned_at)
ORDER BY abandoned_date DESC;

-- 5. Recovery Message Performance
CREATE OR REPLACE VIEW reports.vw_abandoned_cart_recovery_performance AS
SELECT
    DATE(acrm.created_at) AS recovery_date,
    acrm.channel,
    COUNT(DISTINCT acrm.recovery_message_id) AS messages_created,
    COUNT(DISTINCT CASE WHEN acrm.sent_at IS NOT NULL THEN acrm.recovery_message_id END) AS sent_count,
    COUNT(DISTINCT CASE WHEN acrm.opened_at IS NOT NULL THEN acrm.recovery_message_id END) AS opened_count,
    COUNT(DISTINCT CASE WHEN acrm.clicked_at IS NOT NULL THEN acrm.recovery_message_id END) AS clicked_count,
    COUNT(DISTINCT CASE WHEN acrm.recovered_at IS NOT NULL THEN acrm.recovery_message_id END) AS recovered_count,
    ROUND(COUNT(DISTINCT CASE WHEN acrm.clicked_at IS NOT NULL THEN acrm.recovery_message_id END)::NUMERIC
          / NULLIF(COUNT(DISTINCT CASE WHEN acrm.sent_at IS NOT NULL THEN acrm.recovery_message_id END), 0) * 100, 2) AS click_rate_percent,
    ROUND(COUNT(DISTINCT CASE WHEN acrm.recovered_at IS NOT NULL THEN acrm.recovery_message_id END)::NUMERIC
          / NULLIF(COUNT(DISTINCT CASE WHEN acrm.sent_at IS NOT NULL THEN acrm.recovery_message_id END), 0) * 100, 2) AS recovery_rate_percent
FROM cart.abandoned_cart_recovery_messages acrm
GROUP BY DATE(acrm.created_at), acrm.channel
ORDER BY recovery_date DESC;

-- 6. Coupon Usage
CREATE OR REPLACE VIEW reports.vw_cart_coupon_usage AS
SELECT
    cc.coupon_code,
    COUNT(DISTINCT cc.cart_coupon_id) AS applied_count,
    COUNT(DISTINCT cc.cart_id) AS carts_affected,
    SUM(cc.discount_amount) AS total_discount,
    COUNT(DISTINCT CASE WHEN cc.is_valid = TRUE THEN cc.cart_coupon_id END) AS valid_count,
    COUNT(DISTINCT CASE WHEN cc.removed_at IS NOT NULL THEN cc.cart_coupon_id END) AS removed_count
FROM cart.cart_coupons cc
GROUP BY cc.coupon_code
ORDER BY applied_count DESC;

-- 7. Shipping Selection
CREATE OR REPLACE VIEW reports.vw_cart_shipping_selection AS
SELECT
    cso.carrier_code,
    cso.service_code,
    cso.service_name,
    COUNT(DISTINCT cso.cart_shipping_option_id) AS quote_count,
    COUNT(DISTINCT CASE WHEN cso.is_selected = TRUE THEN cso.cart_shipping_option_id END) AS selected_count,
    AVG(cso.shipping_amount) AS avg_shipping_amount,
    MIN(cso.shipping_amount) AS min_shipping_amount,
    MAX(cso.shipping_amount) AS max_shipping_amount
FROM cart.cart_shipping_options cso
GROUP BY cso.carrier_code, cso.service_code, cso.service_name
ORDER BY selected_count DESC;

-- 8. Payment Selection
CREATE OR REPLACE VIEW reports.vw_cart_payment_selection AS
SELECT
    cps.payment_provider_code,
    cps.payment_method_code,
    COUNT(DISTINCT cps.cart_payment_selection_id) AS selection_count,
    COUNT(DISTINCT CASE WHEN cps.is_valid = TRUE THEN cps.cart_payment_selection_id END) AS valid_count,
    SUM(cps.amount) AS selected_amount
FROM cart.cart_payment_selections cps
GROUP BY cps.payment_provider_code, cps.payment_method_code
ORDER BY selection_count DESC;

-- 9. Tax Summary
CREATE OR REPLACE VIEW reports.vw_cart_tax_summary AS
SELECT
    ctl.tax_code,
    ctl.tax_name,
    ctl.jurisdiction,
    COUNT(DISTINCT ctl.cart_tax_line_id) AS tax_line_count,
    SUM(ctl.taxable_amount) AS taxable_amount,
    AVG(ctl.tax_rate) AS avg_tax_rate,
    SUM(ctl.tax_amount) AS tax_amount
FROM cart.cart_tax_lines ctl
GROUP BY ctl.tax_code, ctl.tax_name, ctl.jurisdiction
ORDER BY tax_amount DESC;

-- 10. Inventory Reservation Report
CREATE OR REPLACE VIEW reports.vw_cart_inventory_reservations AS
SELECT
    p.product_code,
    p.product_name,
    COUNT(DISTINCT cir.cart_inventory_reservation_id) AS reservation_count,
    SUM(cir.reserved_quantity) AS reserved_quantity,
    COUNT(DISTINCT CASE WHEN cir.is_active = TRUE AND cir.expires_at > CURRENT_TIMESTAMP THEN cir.cart_inventory_reservation_id END) AS active_reservations,
    COUNT(DISTINCT CASE WHEN cir.expires_at <= CURRENT_TIMESTAMP AND cir.released_at IS NULL AND cir.converted_to_order_at IS NULL THEN cir.cart_inventory_reservation_id END) AS expired_unreleased,
    COUNT(DISTINCT CASE WHEN cir.converted_to_order_at IS NOT NULL THEN cir.cart_inventory_reservation_id END) AS converted_to_order
FROM cart.cart_inventory_reservations cir
JOIN catalog.products p ON p.product_id = cir.product_id
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY reserved_quantity DESC;

-- 11. Checkout Validation Failures
CREATE OR REPLACE VIEW reports.vw_checkout_validation_failures AS
SELECT
    cvtl.code AS validation_code,
    cvtl.name AS validation_name,
    cvr.severity,
    COUNT(DISTINCT cvr.checkout_validation_result_id) AS failure_count,
    COUNT(DISTINCT cvr.cart_id) AS carts_affected,
    MAX(cvr.validated_at) AS last_failure_at
FROM cart.checkout_validation_results cvr
JOIN cart.checkout_validation_type_lookup cvtl ON cvtl.checkout_validation_type_id = cvr.checkout_validation_type_id
WHERE cvr.is_passed = FALSE
GROUP BY cvtl.code, cvtl.name, cvr.severity
ORDER BY failure_count DESC;

-- 12. Split Shipment Report
CREATE OR REPLACE VIEW reports.vw_split_shipment_report AS
SELECT
    cs.cart_id,
    COUNT(DISTINCT cs.cart_shipment_id) AS shipment_count,
    COUNT(DISTINCT csi.cart_item_id) AS item_count,
    SUM(cs.shipping_amount) AS total_shipping_amount,
    MIN(cs.created_at) AS first_shipment_created_at,
    MAX(cs.created_at) AS last_shipment_created_at
FROM cart.cart_shipments cs
LEFT JOIN cart.cart_shipment_items csi ON csi.cart_shipment_id = cs.cart_shipment_id
GROUP BY cs.cart_id
HAVING COUNT(DISTINCT cs.cart_shipment_id) > 1
ORDER BY shipment_count DESC;

-- 13. Multi-Currency Cart Report
CREATE OR REPLACE VIEW reports.vw_multicurrency_cart_report AS
SELECT
    cur.code AS currency_code,
    COUNT(DISTINCT c.cart_id) AS cart_count,
    SUM(c.subtotal_amount) AS subtotal_amount,
    SUM(c.discount_amount) AS discount_amount,
    SUM(c.tax_amount) AS tax_amount,
    SUM(c.shipping_amount) AS shipping_amount,
    SUM(c.grand_total_amount) AS grand_total_amount
FROM cart.carts c
JOIN reference.currency_lookup cur ON cur.currency_id = c.currency_id
GROUP BY cur.code
ORDER BY cart_count DESC;

-- 14. Idempotency / Order Attempt Report
CREATE OR REPLACE VIEW reports.vw_checkout_idempotency_report AS
SELECT
    coa.attempt_status,
    COUNT(DISTINCT coa.checkout_order_attempt_id) AS attempt_count,
    COUNT(DISTINCT coa.cart_id) AS cart_count,
    COUNT(DISTINCT coa.order_id) AS order_count,
    COUNT(DISTINCT CASE WHEN coa.attempt_status = 'DUPLICATE' THEN coa.checkout_order_attempt_id END) AS duplicate_attempts,
    MAX(coa.attempted_at) AS last_attempt_at
FROM cart.checkout_order_attempts coa
GROUP BY coa.attempt_status
ORDER BY attempt_count DESC;

-- 15. Guest vs Customer Cart Report
CREATE OR REPLACE VIEW reports.vw_guest_vs_customer_carts AS
SELECT
    CASE WHEN c.customer_id IS NOT NULL THEN 'CUSTOMER' ELSE 'GUEST' END AS cart_owner_type,
    COUNT(DISTINCT c.cart_id) AS cart_count,
    AVG(c.item_count) AS avg_item_count,
    AVG(c.grand_total_amount) AS avg_cart_value,
    COUNT(DISTINCT CASE WHEN c.order_id IS NOT NULL THEN c.cart_id END) AS converted_carts,
    ROUND(COUNT(DISTINCT CASE WHEN c.order_id IS NOT NULL THEN c.cart_id END)::NUMERIC
          / NULLIF(COUNT(DISTINCT c.cart_id), 0) * 100, 2) AS conversion_rate_percent
FROM cart.carts c
GROUP BY CASE WHEN c.customer_id IS NOT NULL THEN 'CUSTOMER' ELSE 'GUEST' END;

-- 16. Device / Channel Cart Report
CREATE OR REPLACE VIEW reports.vw_device_channel_cart_report AS
SELECT
    COALESCE(cd.device_type, 'UNKNOWN') AS device_type,
    c.sales_channel_id,
    COUNT(DISTINCT c.cart_id) AS cart_count,
    COUNT(DISTINCT cd.device_id) AS device_count,
    AVG(c.grand_total_amount) AS avg_cart_value,
    COUNT(DISTINCT CASE WHEN c.order_id IS NOT NULL THEN c.cart_id END) AS converted_carts
FROM cart.carts c
LEFT JOIN cart.cart_devices cd ON cd.cart_id = c.cart_id
GROUP BY COALESCE(cd.device_type, 'UNKNOWN'), c.sales_channel_id
ORDER BY cart_count DESC;

-- 17. Cart Value Distribution
CREATE OR REPLACE VIEW reports.vw_cart_value_distribution AS
SELECT
    CASE
        WHEN grand_total_amount = 0 THEN 'ZERO'
        WHEN grand_total_amount < 1000 THEN 'LOW'
        WHEN grand_total_amount < 5000 THEN 'MEDIUM'
        WHEN grand_total_amount < 20000 THEN 'HIGH'
        ELSE 'VERY_HIGH'
    END AS value_band,
    COUNT(DISTINCT cart_id) AS cart_count,
    AVG(grand_total_amount) AS avg_cart_value,
    MIN(grand_total_amount) AS min_cart_value,
    MAX(grand_total_amount) AS max_cart_value
FROM cart.carts
GROUP BY
    CASE
        WHEN grand_total_amount = 0 THEN 'ZERO'
        WHEN grand_total_amount < 1000 THEN 'LOW'
        WHEN grand_total_amount < 5000 THEN 'MEDIUM'
        WHEN grand_total_amount < 20000 THEN 'HIGH'
        ELSE 'VERY_HIGH'
    END
ORDER BY cart_count DESC;

-- 18. Cart Conversion Report
CREATE OR REPLACE VIEW reports.vw_cart_conversion_report AS
SELECT
    DATE(c.created_at) AS cart_date,
    COUNT(DISTINCT c.cart_id) AS carts_created,
    COUNT(DISTINCT CASE WHEN c.checkout_started_at IS NOT NULL THEN c.cart_id END) AS checkout_started,
    COUNT(DISTINCT CASE WHEN c.order_id IS NOT NULL THEN c.cart_id END) AS orders_created,
    ROUND(COUNT(DISTINCT CASE WHEN c.checkout_started_at IS NOT NULL THEN c.cart_id END)::NUMERIC
          / NULLIF(COUNT(DISTINCT c.cart_id), 0) * 100, 2) AS checkout_start_rate_percent,
    ROUND(COUNT(DISTINCT CASE WHEN c.order_id IS NOT NULL THEN c.cart_id END)::NUMERIC
          / NULLIF(COUNT(DISTINCT c.cart_id), 0) * 100, 2) AS cart_to_order_rate_percent
FROM cart.carts c
GROUP BY DATE(c.created_at)
ORDER BY cart_date DESC;

-- 19. Recent Cart Activity
CREATE OR REPLACE VIEW reports.vw_recent_cart_activity AS
SELECT
    ce.cart_event_id,
    ce.cart_id,
    cet.code AS event_type,
    ce.customer_id,
    ce.session_id,
    p.product_name,
    ce.device_type,
    ce.occurred_at
FROM cart.cart_events ce
JOIN cart.cart_event_type_lookup cet ON cet.cart_event_type_id = ce.cart_event_type_id
LEFT JOIN catalog.products p ON p.product_id = ce.product_id
ORDER BY ce.occurred_at DESC
LIMIT 500;

-- 20. Cart Health Dashboard
CREATE OR REPLACE VIEW reports.vw_cart_health_dashboard AS
SELECT 'Total Carts' AS metric, COUNT(DISTINCT cart_id)::TEXT AS value FROM cart.carts
UNION ALL
SELECT 'Active/Open Carts', COUNT(DISTINCT c.cart_id)::TEXT
FROM cart.carts c JOIN cart.cart_status_lookup s ON s.cart_status_id = c.cart_status_id
WHERE s.is_open = TRUE
UNION ALL
SELECT 'Guest Carts', COUNT(DISTINCT cart_id)::TEXT FROM cart.carts WHERE customer_id IS NULL
UNION ALL
SELECT 'Customer Carts', COUNT(DISTINCT cart_id)::TEXT FROM cart.carts WHERE customer_id IS NOT NULL
UNION ALL
SELECT 'Checkout Started', COUNT(DISTINCT cart_id)::TEXT FROM cart.carts WHERE checkout_started_at IS NOT NULL
UNION ALL
SELECT 'Orders Created', COUNT(DISTINCT cart_id)::TEXT FROM cart.carts WHERE order_id IS NOT NULL
UNION ALL
SELECT 'Abandoned Carts', COUNT(DISTINCT abandoned_cart_id)::TEXT FROM cart.abandoned_carts
UNION ALL
SELECT 'Recovered Carts', COUNT(DISTINCT abandoned_cart_id)::TEXT FROM cart.abandoned_carts WHERE recovered_at IS NOT NULL
UNION ALL
SELECT 'Active Inventory Reservations', COUNT(DISTINCT cart_inventory_reservation_id)::TEXT
FROM cart.cart_inventory_reservations WHERE is_active = TRUE AND expires_at > CURRENT_TIMESTAMP
UNION ALL
SELECT 'Validation Failures', COUNT(DISTINCT checkout_validation_result_id)::TEXT
FROM cart.checkout_validation_results WHERE is_passed = FALSE
UNION ALL
SELECT 'Duplicate Checkout Attempts', COUNT(DISTINCT checkout_order_attempt_id)::TEXT
FROM cart.checkout_order_attempts WHERE attempt_status = 'DUPLICATE';

-- ============================================================
-- REPORT FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION reports.get_cart_analytics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_date DATE,
    carts_created BIGINT,
    checkout_started BIGINT,
    orders_created BIGINT,
    carts_abandoned BIGINT,
    carts_recovered BIGINT,
    gross_cart_value NUMERIC,
    recovered_cart_value NUMERIC,
    checkout_conversion_rate NUMERIC,
    abandonment_rate NUMERIC,
    recovery_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ca.stat_date,
        SUM(ca.carts_created)::BIGINT,
        SUM(ca.checkout_started)::BIGINT,
        SUM(ca.orders_created)::BIGINT,
        SUM(ca.carts_abandoned)::BIGINT,
        SUM(ca.carts_recovered)::BIGINT,
        SUM(ca.gross_cart_value),
        SUM(ca.recovered_cart_value),
        AVG(ca.checkout_conversion_rate),
        AVG(ca.abandonment_rate),
        AVG(ca.recovery_rate)
    FROM cart.cart_analytics ca
    WHERE ca.company_id = p_company_id
      AND ca.stat_date BETWEEN p_start_date AND p_end_date
    GROUP BY ca.stat_date
    ORDER BY ca.stat_date;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION reports.get_cart_detail(
    p_cart_id UUID
)
RETURNS TABLE (
    cart_id UUID,
    cart_status VARCHAR,
    customer_id UUID,
    session_id VARCHAR,
    currency_code VARCHAR,
    item_count INTEGER,
    quantity_total INTEGER,
    subtotal_amount NUMERIC,
    discount_amount NUMERIC,
    tax_amount NUMERIC,
    shipping_amount NUMERIC,
    grand_total_amount NUMERIC,
    checkout_started_at TIMESTAMPTZ,
    order_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.cart_id,
        csl.code::VARCHAR,
        c.customer_id,
        c.session_id::VARCHAR,
        cur.code::VARCHAR,
        c.item_count,
        c.quantity_total,
        c.subtotal_amount,
        c.discount_amount,
        c.tax_amount,
        c.shipping_amount,
        c.grand_total_amount,
        c.checkout_started_at,
        c.order_id
    FROM cart.carts c
    LEFT JOIN cart.cart_status_lookup csl ON csl.cart_status_id = c.cart_status_id
    JOIN reference.currency_lookup cur ON cur.currency_id = c.currency_id
    WHERE c.cart_id = p_cart_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;