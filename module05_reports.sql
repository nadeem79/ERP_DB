BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 05: PRICING, CURRENCY, TAX & PROMOTIONS REPORTING
-- 15 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Price List Report (Monthly, Critical)
-- All price lists with items
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_price_list_report AS
SELECT
    pl.price_list_id,
    pl.price_list_code,
    pl.price_list_name,
    pl.price_list_type,
    cur.code AS currency_code,
    cur.symbol AS currency_symbol,
    pl.is_default,
    pl.is_active,
    pl.effective_from,
    pl.effective_to,
    COUNT(DISTINCT pli.price_list_item_id) AS item_count,
    AVG(pli.unit_price) AS avg_unit_price,
    MIN(pli.unit_price) AS min_price,
    MAX(pli.unit_price) AS max_price
FROM pricing.price_lists pl
JOIN pricing.currencies cur ON cur.currency_id = pl.currency_id
LEFT JOIN pricing.price_list_items pli ON pli.price_list_id = pl.price_list_id AND pli.is_active = TRUE
GROUP BY pl.price_list_id, pl.price_list_code, pl.price_list_name, pl.price_list_type,
         cur.code, cur.symbol, pl.is_default, pl.is_active, pl.effective_from, pl.effective_to
ORDER BY pl.is_default DESC, pl.price_list_code;

-- ------------------------------------------------------------
-- Report 2: Price Change History (Daily, Critical)
-- Price changes over time
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_price_change_history AS
SELECT
    pch.price_change_history_id,
    p.product_code,
    p.product_name,
    pv.sku,
    pl.price_list_name,
    cur.code AS currency_code,
    pch.old_price,
    pch.new_price,
    pch.change_amount,
    pch.change_percent,
    pch.change_reason,
    u.username AS changed_by,
    pch.changed_at
FROM pricing.price_change_history pch
JOIN catalog.products p ON p.product_id = pch.product_id
JOIN catalog.product_variants pv ON pv.variant_id = pch.product_variant_id
LEFT JOIN pricing.price_lists pl ON pl.price_list_id = pch.price_list_id
JOIN pricing.currencies cur ON cur.currency_id = pch.currency_id
LEFT JOIN identity.users u ON u.user_id = pch.changed_by_user_id
WHERE pch.changed_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY pch.changed_at DESC;

-- ------------------------------------------------------------
-- Report 3: Tax Summary (Monthly, Critical)
-- Tax rates by category
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_tax_summary AS
SELECT
    tc.code AS tax_category_code,
    tc.name AS tax_category_name,
    tc.is_taxable,
    tr.rate,
    tr.rate_type,
    tr.is_inclusive,
    tr.is_compound,
    tr.effective_from,
    tr.effective_to,
    tr.is_active,
    cl.name AS country_name
FROM pricing.tax_categories tc
LEFT JOIN pricing.tax_rates tr ON tr.tax_category_id = tc.tax_category_id AND tr.is_active = TRUE
LEFT JOIN reference.country_lookup cl ON cl.country_id = tr.country_id
WHERE tc.is_active = TRUE
ORDER BY tc.code, tr.rate;

-- ------------------------------------------------------------
-- Report 4: Tax Collection Report (Monthly, Critical)
-- Tax collected by period
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_tax_collection AS
SELECT
    DATE_TRUNC('month', o.order_date) AS tax_month,
    tc.code AS tax_category_code,
    tc.name AS tax_category_name,
    COUNT(DISTINCT oi.order_item_id) AS taxed_items,
    SUM(oi.tax_amount) AS total_tax_collected,
    SUM(oi.line_subtotal) AS total_taxable_amount,
    CASE
        WHEN SUM(oi.line_subtotal) > 0
        THEN ROUND((SUM(oi.tax_amount) / SUM(oi.line_subtotal) * 100)::NUMERIC, 2)
        ELSE 0
    END AS effective_tax_rate
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
LEFT JOIN catalog.product_variants pv ON pv.variant_id = oi.product_variant_id
LEFT JOIN catalog.products p ON p.product_id = pv.product_id
LEFT JOIN pricing.tax_categories tc ON tc.tax_category_id = p.tax_category_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('month', o.order_date), tc.code, tc.name
ORDER BY tax_month DESC, total_tax_collected DESC;

-- ------------------------------------------------------------
-- Report 5: Promotion Performance (Daily, Critical)
-- Active promotions performance
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_promotion_performance AS
SELECT
    promo.promotion_id,
    promo.promotion_code,
    promo.promotion_name,
    promo.promotion_type,
    promo.discount_type,
    promo.discount_value,
    promo.min_order_amount,
    promo.max_discount_amount,
    promo.usage_limit,
    promo.usage_count,
    promo.start_date,
    promo.end_date,
    promo.is_active,
    promo.is_stackable,
    CASE
        WHEN promo.end_date IS NOT NULL AND promo.end_date < CURRENT_TIMESTAMP THEN 'EXPIRED'
        WHEN promo.start_date > CURRENT_TIMESTAMP THEN 'UPCOMING'
        WHEN promo.is_active = TRUE THEN 'ACTIVE'
        ELSE 'INACTIVE'
    END AS promo_status,
    CASE
        WHEN promo.usage_limit IS NOT NULL AND promo.usage_limit > 0
        THEN ROUND((promo.usage_count::NUMERIC / promo.usage_limit * 100), 2)
        ELSE NULL
    END AS usage_percent
FROM pricing.promotions promo
ORDER BY promo.is_active DESC, promo.start_date DESC;

-- ------------------------------------------------------------
-- Report 6: Coupon Usage Report (Daily, Critical)
-- Coupon redemption tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_coupon_usage AS
SELECT
    cp.coupon_id,
    cp.coupon_code,
    cp.coupon_type,
    cp.discount_type,
    cp.discount_value,
    cp.min_order_amount,
    cp.max_discount_amount,
    cp.usage_limit,
    cp.usage_count,
    cp.start_date,
    cp.end_date,
    cp.is_active,
    COUNT(DISTINCT cu.coupon_usage_id) AS times_used,
    SUM(cu.discount_amount) AS total_discount_given,
    COUNT(DISTINCT cu.customer_id) AS unique_customers,
    CASE
        WHEN cp.usage_limit IS NOT NULL AND cp.usage_limit > 0
        THEN ROUND((cp.usage_count::NUMERIC / cp.usage_limit * 100), 2)
        ELSE NULL
    END AS usage_percent,
    CASE
        WHEN cp.end_date IS NOT NULL AND cp.end_date < CURRENT_TIMESTAMP THEN 'EXPIRED'
        WHEN cp.start_date > CURRENT_TIMESTAMP THEN 'UPCOMING'
        WHEN cp.is_active = TRUE THEN 'ACTIVE'
        ELSE 'INACTIVE'
    END AS coupon_status
FROM pricing.coupons cp
LEFT JOIN pricing.coupon_usages cu ON cu.coupon_id = cp.coupon_id
GROUP BY cp.coupon_id, cp.coupon_code, cp.coupon_type, cp.discount_type, cp.discount_value,
         cp.min_order_amount, cp.max_discount_amount, cp.usage_limit, cp.usage_count,
         cp.start_date, cp.end_date, cp.is_active
ORDER BY times_used DESC;

-- ------------------------------------------------------------
-- Report 7: Discount Analysis (Weekly, Important)
-- Discounts applied by type
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_discount_analysis AS
SELECT
    DATE(o.order_date) AS discount_date,
    COUNT(DISTINCT o.order_id) AS orders_with_discount,
    SUM(o.discount_amount) AS total_discount_amount,
    AVG(o.discount_amount) AS avg_discount_amount,
    SUM(o.grand_total) AS total_revenue,
    CASE
        WHEN SUM(o.grand_total + o.discount_amount) > 0
        THEN ROUND((SUM(o.discount_amount) / (SUM(o.grand_total) + SUM(o.discount_amount)) * 100)::NUMERIC, 2)
        ELSE 0
    END AS discount_percent_of_revenue
FROM sales.orders o
WHERE o.discount_amount > 0
  AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(o.order_date)
ORDER BY discount_date DESC;

-- ------------------------------------------------------------
-- Report 8: Price Comparison (Monthly, Important)
-- Price comparison across channels
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_price_comparison AS
SELECT
    p.product_code,
    p.product_name,
    pv.sku,
    pl.price_list_code,
    pl.price_list_name,
    cur.code AS currency_code,
    pli.unit_price,
    pli.list_price,
    pli.cost_price,
    CASE
        WHEN pli.list_price > 0
        THEN ROUND(((pli.list_price - pli.unit_price) / pli.list_price * 100)::NUMERIC, 2)
        ELSE NULL
    END AS discount_percent,
    CASE
        WHEN pli.cost_price > 0
        THEN ROUND(((pli.unit_price - pli.cost_price) / pli.cost_price * 100)::NUMERIC, 2)
        ELSE NULL
    END AS margin_percent
FROM pricing.price_list_items pli
JOIN pricing.price_lists pl ON pl.price_list_id = pli.price_list_id
JOIN pricing.currencies cur ON cur.currency_id = pl.currency_id
JOIN catalog.product_variants pv ON pv.variant_id = pli.product_variant_id
JOIN catalog.products p ON p.product_id = pli.product_id
WHERE pli.is_active = TRUE
ORDER BY p.product_code, pl.price_list_code;

-- ------------------------------------------------------------
-- Report 9: Margin Analysis (Monthly, Critical)
-- Product margins
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_margin_analysis AS
SELECT
    p.product_code,
    p.product_name,
    pv.sku,
    AVG(pp.unit_price) AS avg_selling_price,
    AVG(pp.cost_price) AS avg_cost_price,
    AVG(pp.unit_price - COALESCE(pp.cost_price, 0)) AS avg_margin_amount,
    CASE
        WHEN AVG(pp.unit_price) > 0
        THEN ROUND((AVG(pp.unit_price - COALESCE(pp.cost_price, 0)) / AVG(pp.unit_price) * 100)::NUMERIC, 2)
        ELSE 0
    END AS avg_margin_percent,
    COUNT(DISTINCT pp.product_price_id) AS price_count
FROM pricing.product_prices pp
JOIN catalog.product_variants pv ON pv.variant_id = pp.product_variant_id
JOIN catalog.products p ON p.product_id = pp.product_id
WHERE pp.is_active = TRUE
GROUP BY p.product_code, p.product_name, pv.sku
ORDER BY avg_margin_percent DESC;

-- ------------------------------------------------------------
-- Report 10: Price List Coverage (Weekly, Important)
-- Products without prices
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_price_list_coverage AS
SELECT
    pl.price_list_code,
    pl.price_list_name,
    pl.price_list_type,
    cur.code AS currency_code,
    COUNT(DISTINCT pv.variant_id) AS total_variants,
    COUNT(DISTINCT pli.product_variant_id) AS priced_variants,
    COUNT(DISTINCT pv.variant_id) - COUNT(DISTINCT pli.product_variant_id) AS unpriced_variants,
    CASE
        WHEN COUNT(DISTINCT pv.variant_id) > 0
        THEN ROUND((COUNT(DISTINCT pli.product_variant_id)::NUMERIC / COUNT(DISTINCT pv.variant_id) * 100), 2)
        ELSE 0
    END AS coverage_percent
FROM pricing.price_lists pl
JOIN pricing.currencies cur ON cur.currency_id = pl.currency_id
CROSS JOIN catalog.product_variants pv
LEFT JOIN pricing.price_list_items pli ON pli.price_list_id = pl.price_list_id AND pli.product_variant_id = pv.variant_id AND pli.is_active = TRUE
WHERE pl.is_active = TRUE
GROUP BY pl.price_list_id, pl.price_list_code, pl.price_list_name, pl.price_list_type, cur.code
ORDER BY coverage_percent ASC;

-- ------------------------------------------------------------
-- Report 11: Tax Exemption Report (Monthly, Important)
-- Tax exempt transactions
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_tax_exemption_report AS
SELECT
    te.tax_exemption_id,
    te.exemption_type,
    tc.code AS tax_category_code,
    tc.name AS tax_category_name,
    COALESCE(c.customer_number, 'N/A') AS customer_number,
    COALESCE(c.display_name, 'N/A') AS customer_name,
    te.exemption_reason,
    te.exemption_certificate_number,
    te.effective_from,
    te.effective_to,
    te.is_active
FROM pricing.tax_exemptions te
JOIN pricing.tax_categories tc ON tc.tax_category_id = te.tax_category_id
LEFT JOIN crm.customers c ON c.customer_id = te.customer_id
WHERE te.is_active = TRUE
ORDER BY te.created_at DESC;

-- ------------------------------------------------------------
-- Report 12: Promotion ROI (Monthly, Critical)
-- Promotion return on investment
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_promotion_roi AS
SELECT
    promo.promotion_code,
    promo.promotion_name,
    promo.promotion_type,
    promo.discount_type,
    promo.discount_value,
    promo.usage_count,
    SUM(cu.discount_amount) AS total_discount_given,
    COUNT(DISTINCT cu.order_id) AS orders_with_promo,
    SUM(o.grand_total) AS total_revenue_from_promo,
    CASE
        WHEN SUM(cu.discount_amount) > 0
        THEN ROUND(((SUM(o.grand_total) - SUM(cu.discount_amount)) / SUM(cu.discount_amount) * 100)::NUMERIC, 2)
        ELSE NULL
    END AS roi_percent
FROM pricing.promotions promo
LEFT JOIN pricing.coupons cp ON cp.promotion_id = promo.promotion_id
LEFT JOIN pricing.coupon_usages cu ON cu.coupon_id = cp.coupon_id
LEFT JOIN sales.orders o ON o.order_id = cu.order_id
GROUP BY promo.promotion_id, promo.promotion_code, promo.promotion_name, promo.promotion_type,
         promo.discount_type, promo.discount_value, promo.usage_count
ORDER BY total_revenue_from_promo DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 13: Customer Segment Pricing (Monthly, Important)
-- Segment-specific pricing
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_segment_pricing AS
SELECT
    cseg.segment_code,
    cseg.segment_name,
    cseg.segment_type,
    COUNT(DISTINCT csm.customer_id) AS member_count,
    COUNT(DISTINCT csm.customer_id) FILTER (WHERE csm.is_active = TRUE) AS active_members,
    cseg.is_active AS segment_active
FROM pricing.customer_segments cseg
LEFT JOIN pricing.customer_segment_members csm ON csm.customer_segment_id = cseg.customer_segment_id
GROUP BY cseg.customer_segment_id, cseg.segment_code, cseg.segment_name, cseg.segment_type, cseg.is_active
ORDER BY member_count DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 14: Price Elasticity (Quarterly, Important)
-- Price sensitivity analysis
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_price_elasticity AS
SELECT
    p.product_code,
    p.product_name,
    pv.sku,
    DATE_TRUNC('month', pch.changed_at) AS price_change_month,
    COUNT(DISTINCT pch.price_change_history_id) AS price_changes,
    AVG(pch.change_percent) AS avg_price_change_percent,
    COUNT(DISTINCT oi.order_item_id) AS items_sold_in_period,
    SUM(oi.quantity) AS total_quantity_sold
FROM pricing.price_change_history pch
JOIN catalog.products p ON p.product_id = pch.product_id
JOIN catalog.product_variants pv ON pv.variant_id = pch.product_variant_id
LEFT JOIN sales.order_items oi ON oi.product_variant_id = pch.product_variant_id
    AND oi.created_at >= pch.changed_at - INTERVAL '30 days'
    AND oi.created_at <= pch.changed_at + INTERVAL '30 days'
WHERE pch.changed_at >= CURRENT_TIMESTAMP - INTERVAL '180 days'
GROUP BY p.product_code, p.product_name, pv.sku, DATE_TRUNC('month', pch.changed_at)
ORDER BY price_change_month DESC, price_changes DESC;

-- ------------------------------------------------------------
-- Report 15: Pricing Health Dashboard (Daily, Critical)
-- Pricing health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_pricing_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT price_list_id) FROM pricing.price_lists WHERE is_active = TRUE) AS active_price_lists,
    (SELECT COUNT(DISTINCT price_list_item_id) FROM pricing.price_list_items WHERE is_active = TRUE) AS active_price_items,
    (SELECT COUNT(DISTINCT product_price_id) FROM pricing.product_prices WHERE is_active = TRUE) AS active_product_prices,
    (SELECT COUNT(DISTINCT promotion_id) FROM pricing.promotions WHERE is_active = TRUE AND end_date >= CURRENT_TIMESTAMP) AS active_promotions,
    (SELECT COUNT(DISTINCT coupon_id) FROM pricing.coupons WHERE is_active = TRUE AND end_date >= CURRENT_TIMESTAMP) AS active_coupons,
    (SELECT COUNT(DISTINCT tax_rate_id) FROM pricing.tax_rates WHERE is_active = TRUE) AS active_tax_rates,
    (SELECT COUNT(DISTINCT currency_id) FROM pricing.currencies WHERE is_active = TRUE) AS active_currencies,
    (SELECT COUNT(DISTINCT exchange_rate_id) FROM pricing.exchange_rates WHERE is_active = TRUE) AS active_exchange_rates,
    (SELECT COUNT(DISTINCT price_change_history_id) FROM pricing.price_change_history WHERE changed_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS price_changes_7d,
    (SELECT COUNT(DISTINCT coupon_usage_id) FROM pricing.coupon_usages WHERE used_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS coupon_usages_7d,
    (SELECT COALESCE(SUM(discount_amount), 0) FROM pricing.coupon_usages WHERE used_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS total_discounts_7d,
    (SELECT COUNT(DISTINCT customer_segment_id) FROM pricing.customer_segments WHERE is_active = TRUE) AS active_segments;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Price for Product Variant
CREATE OR REPLACE FUNCTION reports.fn_get_product_price(
    p_product_variant_id UUID,
    p_currency_id UUID DEFAULT NULL,
    p_price_list_id UUID DEFAULT NULL,
    p_quantity NUMERIC DEFAULT 1
)
RETURNS TABLE (
    product_price_id UUID,
    unit_price NUMERIC,
    list_price NUMERIC,
    cost_price NUMERIC,
    currency_code VARCHAR,
    price_list_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pp.product_price_id,
        pp.unit_price,
        pp.list_price,
        pp.cost_price,
        cur.code::VARCHAR,
        pl.price_list_name::VARCHAR
    FROM pricing.product_prices pp
    JOIN pricing.currencies cur ON cur.currency_id = pp.currency_id
    LEFT JOIN pricing.price_lists pl ON pl.price_list_id = pp.price_list_id
    WHERE pp.product_variant_id = p_product_variant_id
      AND pp.is_active = TRUE
      AND (p_currency_id IS NULL OR pp.currency_id = p_currency_id)
      AND (p_price_list_id IS NULL OR pp.price_list_id = p_price_list_id)
      AND (pp.min_quantity IS NULL OR pp.min_quantity <= p_quantity)
      AND (pp.effective_from IS NULL OR pp.effective_from <= CURRENT_DATE)
      AND (pp.effective_to IS NULL OR pp.effective_to >= CURRENT_DATE)
    ORDER BY pp.unit_price ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Calculate Tax
CREATE OR REPLACE FUNCTION reports.fn_calculate_tax(
    p_amount NUMERIC,
    p_tax_category_id UUID,
    p_country_id UUID DEFAULT NULL
)
RETURNS TABLE (
    tax_rate NUMERIC,
    tax_amount NUMERIC,
    is_inclusive BOOLEAN,
    total_with_tax NUMERIC
) AS $$
DECLARE
    v_rate NUMERIC;
    v_is_inclusive BOOLEAN;
BEGIN
    SELECT tr.rate, tr.is_inclusive INTO v_rate, v_is_inclusive
    FROM pricing.tax_rates tr
    WHERE tr.tax_category_id = p_tax_category_id
      AND tr.is_active = TRUE
      AND (p_country_id IS NULL OR tr.country_id = p_country_id)
      AND (tr.effective_from IS NULL OR tr.effective_from <= CURRENT_DATE)
      AND (tr.effective_to IS NULL OR tr.effective_to >= CURRENT_DATE)
    ORDER BY tr.tax_order ASC
    LIMIT 1;

    IF v_rate IS NULL THEN
        v_rate := 0;
        v_is_inclusive := FALSE;
    END IF;

    RETURN QUERY
    SELECT
        v_rate,
        CASE WHEN v_is_inclusive THEN p_amount - (p_amount / (1 + v_rate / 100)) ELSE p_amount * v_rate / 100 END,
        v_is_inclusive,
        CASE WHEN v_is_inclusive THEN p_amount ELSE p_amount + (p_amount * v_rate / 100) END;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Apply Discount
CREATE OR REPLACE FUNCTION reports.fn_apply_discount(
    p_amount NUMERIC,
    p_discount_type VARCHAR,
    p_discount_value NUMERIC,
    p_max_discount NUMERIC DEFAULT NULL
)
RETURNS TABLE (
    discount_amount NUMERIC,
    discounted_amount NUMERIC
) AS $$
DECLARE
    v_discount NUMERIC;
BEGIN
    IF p_discount_type = 'PERCENTAGE' THEN
        v_discount := p_amount * p_discount_value / 100;
    ELSIF p_discount_type = 'FIXED' THEN
        v_discount := p_discount_value;
    ELSIF p_discount_type = 'FREE' THEN
        v_discount := p_amount;
    ELSE
        v_discount := 0;
    END IF;

    IF p_max_discount IS NOT NULL AND v_discount > p_max_discount THEN
        v_discount := p_max_discount;
    END IF;

    IF v_discount > p_amount THEN
        v_discount := p_amount;
    END IF;

    RETURN QUERY SELECT v_discount, p_amount - v_discount;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Convert Currency
CREATE OR REPLACE FUNCTION reports.fn_convert_currency(
    p_amount NUMERIC,
    p_from_currency_id UUID,
    p_to_currency_id UUID,
    p_company_id UUID
)
RETURNS TABLE (
    converted_amount NUMERIC,
    exchange_rate NUMERIC,
    from_currency VARCHAR,
    to_currency VARCHAR
) AS $$
DECLARE
    v_rate NUMERIC;
BEGIN
    IF p_from_currency_id = p_to_currency_id THEN
        RETURN QUERY SELECT p_amount, 1.0::NUMERIC, 'SAME'::VARCHAR, 'SAME'::VARCHAR;
        RETURN;
    END IF;

    SELECT er.rate INTO v_rate
    FROM pricing.exchange_rates er
    WHERE er.company_id = p_company_id
      AND er.from_currency_id = p_from_currency_id
      AND er.to_currency_id = p_to_currency_id
      AND er.is_active = TRUE
      AND (er.effective_from IS NULL OR er.effective_from <= CURRENT_DATE)
      AND (er.effective_to IS NULL OR er.effective_to >= CURRENT_DATE)
    ORDER BY er.effective_from DESC
    LIMIT 1;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'Exchange rate not found for currency conversion';
    END IF;

    RETURN QUERY
    SELECT
        p_amount * v_rate,
        v_rate,
        fc.code::VARCHAR,
        tc.code::VARCHAR
    FROM pricing.currencies fc, pricing.currencies tc
    WHERE fc.currency_id = p_from_currency_id AND tc.currency_id = p_to_currency_id;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Active Promotions for Order
CREATE OR REPLACE FUNCTION reports.fn_get_active_promotions(
    p_company_id UUID,
    p_order_amount NUMERIC DEFAULT NULL,
    p_product_id UUID DEFAULT NULL
)
RETURNS TABLE (
    promotion_id UUID,
    promotion_code VARCHAR,
    promotion_name VARCHAR,
    promotion_type VARCHAR,
    discount_type VARCHAR,
    discount_value NUMERIC,
    min_order_amount NUMERIC,
    max_discount_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        promo.promotion_id,
        promo.promotion_code::VARCHAR,
        promo.promotion_name::VARCHAR,
        promo.promotion_type::VARCHAR,
        promo.discount_type::VARCHAR,
        promo.discount_value,
        promo.min_order_amount,
        promo.max_discount_amount
    FROM pricing.promotions promo
    WHERE promo.company_id = p_company_id
      AND promo.is_active = TRUE
      AND (promo.start_date IS NULL OR promo.start_date <= CURRENT_TIMESTAMP)
      AND (promo.end_date IS NULL OR promo.end_date >= CURRENT_TIMESTAMP)
      AND (p_order_amount IS NULL OR promo.min_order_amount IS NULL OR promo.min_order_amount <= p_order_amount)
      AND (p_product_id IS NULL OR promo.product_id IS NULL OR promo.product_id = p_product_id
           OR promo.applies_to IN ('ORDER', 'CATEGORY', 'BRAND', 'COLLECTION'))
    ORDER BY promo.discount_value DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 05 Pricing, Currency, Tax & Promotions
-- 15 Views + 5 Functions = 20 Report Objects
-- 15 Reports as per reports02.html catalog
-- ============================================================