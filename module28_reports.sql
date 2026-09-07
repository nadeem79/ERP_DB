BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 28: WISHLIST / FAVORITES / SAVED ITEMS REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Wishlist Summary Report
CREATE VIEW reports.vw_wishlist_summary AS
SELECT
    DATE(wl.created_at) as wishlist_date,
    wlt.code as wishlist_type,
    wlv.code as visibility,
    COUNT(DISTINCT wl.wishlist_id) as wishlist_count,
    COUNT(DISTINCT wl.customer_id) as unique_customers,
    SUM(wl.total_items) as total_items,
    SUM(wl.total_value) as total_value,
    AVG(wl.total_items) as avg_items_per_wishlist,
    AVG(wl.total_value) as avg_value_per_wishlist
FROM wishlist.wishlists wl
JOIN wishlist.wishlist_type_lookup wlt ON wlt.wishlist_type_id = wl.wishlist_type_id
JOIN wishlist.wishlist_visibility_lookup wlv ON wlv.wishlist_visibility_id = wl.wishlist_visibility_id
WHERE wl.is_active = TRUE
GROUP BY DATE(wl.created_at), wlt.code, wlv.code
ORDER BY wishlist_date DESC;

-- View 2: Wishlist Item Status Report
CREATE VIEW reports.vw_wishlist_item_status AS
SELECT
    wis.code as item_status,
    wis.name as status_name,
    COUNT(DISTINCT wi.wishlist_item_id) as item_count,
    COUNT(DISTINCT wi.wishlist_id) as wishlists_affected,
    COUNT(DISTINCT wi.product_id) as products_affected,
    SUM(wi.quantity) as total_quantity,
    SUM(wi.current_price * wi.quantity) as total_value
FROM wishlist.wishlist_item_status_lookup wis
LEFT JOIN wishlist.wishlist_items wi ON wi.item_status_id = wis.wishlist_item_status_id AND wi.is_active = TRUE
GROUP BY wis.wishlist_item_status_id, wis.code, wis.name, wis.sort_order
ORDER BY wis.sort_order;

-- View 3: Top Wishlisted Products
CREATE VIEW reports.vw_top_wishlisted_products AS
SELECT
    p.product_code,
    p.product_name,
    p.slug,
    COUNT(DISTINCT wi.wishlist_item_id) as times_wishlisted,
    COUNT(DISTINCT wi.wishlist_id) as unique_wishlists,
    COUNT(DISTINCT wl.customer_id) as unique_customers,
    SUM(wi.quantity) as total_quantity_wishlisted,
    COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END) as times_purchased,
    ROUND((COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END)::numeric /
           NULLIF(COUNT(DISTINCT wi.wishlist_item_id), 0) * 100), 2) as wishlist_conversion_rate
FROM catalog.products p
LEFT JOIN wishlist.wishlist_items wi ON wi.product_id = p.product_id AND wi.is_active = TRUE
LEFT JOIN wishlist.wishlists wl ON wl.wishlist_id = wi.wishlist_id
LEFT JOIN wishlist.wishlist_item_status_lookup wis ON wis.wishlist_item_status_id = wi.item_status_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_code, p.product_name, p.slug
ORDER BY times_wishlisted DESC
LIMIT 50;

-- View 4: Guest Wishlist Report
CREATE VIEW reports.vw_guest_wishlist_report AS
SELECT
    DATE(gwl.created_at) as guest_date,
    COUNT(DISTINCT gwl.guest_wishlist_id) as guest_wishlists,
    COUNT(DISTINCT gwl.session_id) as unique_sessions,
    SUM(gwl.total_items) as total_items,
    SUM(gwl.total_value) as total_value,
    COUNT(DISTINCT CASE WHEN gwl.is_merged = TRUE THEN gwl.guest_wishlist_id END) as merged_wishlists,
    ROUND((COUNT(DISTINCT CASE WHEN gwl.is_merged = TRUE THEN gwl.guest_wishlist_id END)::numeric /
           NULLIF(COUNT(DISTINCT gwl.guest_wishlist_id), 0) * 100), 2) as merge_rate_percent
FROM wishlist.guest_wishlists gwl
WHERE gwl.is_active = TRUE
GROUP BY DATE(gwl.created_at)
ORDER BY guest_date DESC;

-- View 5: Wishlist Alerts Report
CREATE VIEW reports.vw_wishlist_alerts AS
SELECT
    atl.code as alert_type,
    atl.name as alert_type_name,
    asl.code as alert_status,
    asl.name as status_name,
    COUNT(DISTINCT wa.wishlist_alert_id) as alert_count,
    COUNT(DISTINCT wa.customer_id) as customers_affected,
    COUNT(DISTINCT wa.product_id) as products_involved,
    COUNT(DISTINCT CASE WHEN asl.code = 'SENT' THEN wa.wishlist_alert_id END) as notifications_sent
FROM wishlist.alert_type_lookup atl
LEFT JOIN wishlist.wishlist_alerts wa ON wa.alert_type_id = atl.alert_type_id
LEFT JOIN wishlist.alert_status_lookup asl ON asl.alert_status_id = wa.alert_status_id
GROUP BY atl.alert_type_id, atl.code, atl.name, asl.alert_status_id, asl.code, asl.name, atl.sort_order
ORDER BY atl.sort_order, alert_count DESC NULLS LAST;

-- View 6: Price Drop Alerts Report
CREATE VIEW reports.vw_price_drop_alerts AS
SELECT
    p.product_code,
    p.product_name,
    wa.target_price,
    wa.price_drop_percent,
    wi.price_at_add,
    wi.current_price,
    wi.price_change_percent,
    asl.code as alert_status,
    wa.created_at,
    wa.triggered_at,
    wa.notification_sent_at
FROM wishlist.wishlist_alerts wa
JOIN catalog.products p ON p.product_id = wa.product_id
JOIN wishlist.alert_type_lookup atl ON atl.alert_type_id = wa.alert_type_id
JOIN wishlist.alert_status_lookup asl ON asl.alert_status_id = wa.alert_status_id
LEFT JOIN wishlist.wishlist_items wi ON wi.wishlist_item_id = wa.wishlist_item_id
WHERE atl.code = 'PRICE_DROP'
ORDER BY wa.created_at DESC;

-- View 7: Recently Viewed Products Report
CREATE VIEW reports.vw_recently_viewed_products AS
SELECT
    p.product_code,
    p.product_name,
    p.slug,
    COUNT(DISTINCT rvp.recently_viewed_id) as view_count,
    COUNT(DISTINCT COALESCE(rvp.customer_id::text, rvp.session_id)) as unique_viewers,
    AVG(rvp.view_duration_seconds) as avg_view_duration,
    MAX(rvp.viewed_at) as last_viewed_at,
    rvs.name as source_name
FROM wishlist.recently_viewed_products rvp
JOIN catalog.products p ON p.product_id = rvp.product_id
LEFT JOIN wishlist.recently_viewed_source_lookup rvs ON rvs.recently_viewed_source_id = rvp.recently_viewed_source_id
GROUP BY p.product_id, p.product_code, p.product_name, p.slug, rvs.name
ORDER BY view_count DESC
LIMIT 100;

-- View 8: Wishlist Conversion Report
CREATE VIEW reports.vw_wishlist_conversion AS
SELECT
    DATE(wi.added_at) as added_date,
    COUNT(DISTINCT wi.wishlist_item_id) as items_added,
    COUNT(DISTINCT CASE WHEN wis.code = 'MOVED_TO_CART' THEN wi.wishlist_item_id END) as moved_to_cart,
    COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END) as purchased,
    ROUND((COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END)::numeric /
           NULLIF(COUNT(DISTINCT wi.wishlist_item_id), 0) * 100), 2) as conversion_rate_percent,
    SUM(CASE WHEN wis.code = 'PURCHASED' THEN wi.current_price * wi.quantity ELSE 0 END) as revenue_from_wishlist
FROM wishlist.wishlist_items wi
LEFT JOIN wishlist.wishlist_item_status_lookup wis ON wis.wishlist_item_status_id = wi.item_status_id
GROUP BY DATE(wi.added_at)
ORDER BY added_date DESC;

-- View 9: Shared Wishlist Report
CREATE VIEW reports.vw_shared_wishlists AS
SELECT
    wl.wishlist_name,
    wl.wishlist_code,
    wlt.code as wishlist_type,
    wlv.code as visibility,
    COUNT(DISTINCT ws.wishlist_share_id) as share_count,
    SUM(ws.access_count) as total_accesses,
    MAX(ws.last_accessed_at) as last_accessed_at,
    wl.created_at,
    wl.is_active
FROM wishlist.wishlists wl
JOIN wishlist.wishlist_type_lookup wlt ON wlt.wishlist_type_id = wl.wishlist_type_id
JOIN wishlist.wishlist_visibility_lookup wlv ON wlv.wishlist_visibility_id = wl.wishlist_visibility_id
LEFT JOIN wishlist.wishlist_shares ws ON ws.wishlist_id = wl.wishlist_id
WHERE wlv.code IN ('SHARED', 'PUBLIC', 'UNLISTED')
GROUP BY wl.wishlist_id, wl.wishlist_name, wl.wishlist_code, wlt.code, wlv.code, wl.created_at, wl.is_active
ORDER BY share_count DESC NULLS LAST;

-- View 10: Gift Registry Report
CREATE VIEW reports.vw_gift_registry_report AS
SELECT
    wl.wishlist_name,
    wl.event_name,
    wl.event_type,
    wl.event_date,
    c.display_name as customer_name,
    wl.total_items,
    wl.total_value,
    COUNT(DISTINCT CASE WHEN wis.code = 'GIFTED' THEN wi.wishlist_item_id END) as gifted_items,
    COUNT(DISTINCT CASE WHEN wis.code = 'RESERVED' THEN wi.wishlist_item_id END) as reserved_items,
    COUNT(DISTINCT CASE WHEN wis.code = 'ACTIVE' THEN wi.wishlist_item_id END) as remaining_items,
    ROUND((COUNT(DISTINCT CASE WHEN wis.code IN ('GIFTED', 'RESERVED') THEN wi.wishlist_item_id END)::numeric /
           NULLIF(COUNT(DISTINCT wi.wishlist_item_id), 0) * 100), 2) as fulfillment_percent
FROM wishlist.wishlists wl
JOIN wishlist.wishlist_type_lookup wlt ON wlt.wishlist_type_id = wl.wishlist_type_id
LEFT JOIN crm.customers c ON c.customer_id = wl.customer_id
LEFT JOIN wishlist.wishlist_items wi ON wi.wishlist_id = wl.wishlist_id AND wi.is_active = TRUE
LEFT JOIN wishlist.wishlist_item_status_lookup wis ON wis.wishlist_item_status_id = wi.item_status_id
WHERE wlt.code = 'GIFT_REGISTRY'
GROUP BY wl.wishlist_id, wl.wishlist_name, wl.event_name, wl.event_type, wl.event_date, c.display_name, wl.total_items, wl.total_value
ORDER BY wl.event_date DESC NULLS LAST;

-- View 11: Save for Later Report
CREATE VIEW reports.vw_save_for_later AS
SELECT
    DATE(sfl.saved_at) as saved_date,
    COUNT(DISTINCT sfl.save_for_later_id) as saved_items,
    COUNT(DISTINCT sfl.customer_id) as unique_customers,
    COUNT(DISTINCT sfl.product_id) as unique_products,
    COUNT(DISTINCT CASE WHEN sfl.moved_back_to_cart_at IS NOT NULL THEN sfl.save_for_later_id END) as moved_back_to_cart,
    COUNT(DISTINCT CASE WHEN sfl.removed_at IS NOT NULL THEN sfl.save_for_later_id END) as removed,
    ROUND((COUNT(DISTINCT CASE WHEN sfl.moved_back_to_cart_at IS NOT NULL THEN sfl.save_for_later_id END)::numeric /
           NULLIF(COUNT(DISTINCT sfl.save_for_later_id), 0) * 100), 2) as cart_return_rate_percent
FROM wishlist.save_for_later_items sfl
WHERE sfl.is_active = TRUE OR sfl.removed_at IS NOT NULL
GROUP BY DATE(sfl.saved_at)
ORDER BY saved_date DESC;

-- View 12: Customer Wishlist Activity
CREATE VIEW reports.vw_customer_wishlist_activity AS
SELECT
    c.customer_number,
    c.display_name,
    COUNT(DISTINCT wl.wishlist_id) as total_wishlists,
    COUNT(DISTINCT wi.wishlist_item_id) as total_items,
    COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END) as purchased_items,
    COUNT(DISTINCT CASE WHEN wis.code = 'MOVED_TO_CART' THEN wi.wishlist_item_id END) as moved_to_cart,
    SUM(wl.total_value) as total_wishlist_value,
    MAX(wl.last_modified_at) as last_activity
FROM crm.customers c
LEFT JOIN wishlist.wishlists wl ON wl.customer_id = c.customer_id AND wl.is_active = TRUE
LEFT JOIN wishlist.wishlist_items wi ON wi.wishlist_id = wl.wishlist_id AND wi.is_active = TRUE
LEFT JOIN wishlist.wishlist_item_status_lookup wis ON wis.wishlist_item_status_id = wi.item_status_id
GROUP BY c.customer_id, c.customer_number, c.display_name
ORDER BY total_wishlist_value DESC NULLS LAST
LIMIT 100;

-- View 13: Wishlist Type Performance
CREATE VIEW reports.vw_wishlist_type_performance AS
SELECT
    wlt.code as wishlist_type,
    wlt.name as type_name,
    COUNT(DISTINCT wl.wishlist_id) as wishlist_count,
    COUNT(DISTINCT wl.customer_id) as customer_count,
    SUM(wl.total_items) as total_items,
    SUM(wl.total_value) as total_value,
    AVG(wl.total_items) as avg_items_per_wishlist,
    AVG(wl.total_value) as avg_value_per_wishlist
FROM wishlist.wishlist_type_lookup wlt
LEFT JOIN wishlist.wishlists wl ON wl.wishlist_type_id = wlt.wishlist_type_id AND wl.is_active = TRUE
GROUP BY wlt.wishlist_type_id, wlt.code, wlt.name, wlt.sort_order
ORDER BY wlt.sort_order;

-- View 14: Wishlist Trend Report
CREATE VIEW reports.vw_wishlist_trend AS
SELECT
    DATE_TRUNC('week', wl.created_at) as week_start,
    COUNT(DISTINCT wl.wishlist_id) as wishlists_created,
    COUNT(DISTINCT wl.customer_id) as unique_customers,
    SUM(wl.total_items) as total_items_added,
    SUM(wl.total_value) as total_value_added
FROM wishlist.wishlists wl
WHERE wl.is_active = TRUE
GROUP BY DATE_TRUNC('week', wl.created_at)
ORDER BY week_start DESC;

-- View 15: Price Change Impact Report
CREATE VIEW reports.vw_price_change_impact AS
SELECT
    CASE
        WHEN wi.price_change_percent > 0 THEN 'PRICE_INCREASED'
        WHEN wi.price_change_percent < 0 THEN 'PRICE_DECREASED'
        ELSE 'NO_CHANGE'
    END as price_change_direction,
    COUNT(DISTINCT wi.wishlist_item_id) as item_count,
    COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END) as purchased_count,
    ROUND(AVG(wi.price_change_percent), 2) as avg_price_change_percent,
    ROUND((COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END)::numeric /
           NULLIF(COUNT(DISTINCT wi.wishlist_item_id), 0) * 100), 2) as conversion_rate_percent
FROM wishlist.wishlist_items wi
LEFT JOIN wishlist.wishlist_item_status_lookup wis ON wis.wishlist_item_status_id = wi.item_status_id
WHERE wi.is_active = TRUE AND wi.price_change_percent IS NOT NULL
GROUP BY CASE
    WHEN wi.price_change_percent > 0 THEN 'PRICE_INCREASED'
    WHEN wi.price_change_percent < 0 THEN 'PRICE_DECREASED'
    ELSE 'NO_CHANGE'
END
ORDER BY item_count DESC;

-- View 16: Wishlist Abandonment Report
CREATE VIEW reports.vw_wishlist_abandonment AS
SELECT
    DATE(wl.created_at) as created_date,
    COUNT(DISTINCT wl.wishlist_id) as wishlists_created,
    COUNT(DISTINCT CASE WHEN wl.last_modified_at < CURRENT_TIMESTAMP - INTERVAL '30 days' THEN wl.wishlist_id END) as inactive_wishlists,
    COUNT(DISTINCT CASE WHEN wl.total_items = 0 THEN wl.wishlist_id END) as empty_wishlists,
    ROUND((COUNT(DISTINCT CASE WHEN wl.last_modified_at < CURRENT_TIMESTAMP - INTERVAL '30 days' THEN wl.wishlist_id END)::numeric /
           NULLIF(COUNT(DISTINCT wl.wishlist_id), 0) * 100), 2) as abandonment_rate_percent
FROM wishlist.wishlists wl
WHERE wl.is_active = TRUE
GROUP BY DATE(wl.created_at)
ORDER BY created_date DESC;

-- View 17: Stock Alert Report
CREATE VIEW reports.vw_stock_alert_report AS
SELECT
    p.product_code,
    p.product_name,
    wa.stock_threshold,
    asl.code as alert_status,
    COUNT(DISTINCT wa.wishlist_alert_id) as alert_count,
    COUNT(DISTINCT wa.customer_id) as customers_waiting,
    wa.created_at,
    wa.triggered_at
FROM wishlist.wishlist_alerts wa
JOIN catalog.products p ON p.product_id = wa.product_id
JOIN wishlist.alert_type_lookup atl ON atl.alert_type_id = wa.alert_type_id
JOIN wishlist.alert_status_lookup asl ON asl.alert_status_id = wa.alert_status_id
WHERE atl.code IN ('BACK_IN_STOCK', 'LOW_STOCK', 'RESTOCK')
ORDER BY wa.created_at DESC;

-- View 18: Wishlist Share Performance
CREATE VIEW reports.vw_wishlist_share_performance AS
SELECT
    DATE(ws.shared_at) as share_date,
    COUNT(DISTINCT ws.wishlist_share_id) as shares_created,
    SUM(ws.access_count) as total_accesses,
    AVG(ws.access_count) as avg_accesses_per_share,
    COUNT(DISTINCT CASE WHEN ws.shared_with_customer_id IS NOT NULL THEN ws.wishlist_share_id END) as shared_with_customers,
    COUNT(DISTINCT CASE WHEN ws.shared_with_email IS NOT NULL THEN ws.wishlist_share_id END) as shared_with_emails
FROM wishlist.wishlist_shares ws
WHERE ws.is_active = TRUE
GROUP BY DATE(ws.shared_at)
ORDER BY share_date DESC;

-- View 19: Wishlist Analytics Summary
CREATE VIEW reports.vw_wishlist_analytics_summary AS
SELECT
    wana.stat_date,
    SUM(wana.total_wishlists) as total_wishlists,
    SUM(wana.total_items) as total_items,
    SUM(wana.total_value) as total_value,
    SUM(wana.items_added) as items_added,
    SUM(wana.items_removed) as items_removed,
    SUM(wana.items_moved_to_cart) as items_moved_to_cart,
    SUM(wana.items_purchased) as items_purchased,
    SUM(wana.price_drops_detected) as price_drops_detected,
    SUM(wana.stock_alerts_triggered) as stock_alerts_triggered,
    AVG(wana.conversion_rate) as avg_conversion_rate
FROM wishlist.wishlist_analytics wana
GROUP BY wana.stat_date
ORDER BY wana.stat_date DESC;

-- View 20: Wishlist Health Dashboard
CREATE VIEW reports.vw_wishlist_health_dashboard AS
SELECT
    'Total Wishlists' as metric,
    COUNT(DISTINCT wl.wishlist_id)::TEXT as value
FROM wishlist.wishlists wl WHERE wl.is_active = TRUE
UNION ALL
SELECT
    'Active Customers with Wishlists' as metric,
    COUNT(DISTINCT wl.customer_id)::TEXT
FROM wishlist.wishlists wl WHERE wl.is_active = TRUE
UNION ALL
SELECT
    'Total Wishlist Items' as metric,
    COUNT(DISTINCT wi.wishlist_item_id)::TEXT
FROM wishlist.wishlist_items wi WHERE wi.is_active = TRUE
UNION ALL
SELECT
    'Total Wishlist Value' as metric,
    ROUND(SUM(wl.total_value), 2)::TEXT
FROM wishlist.wishlists wl WHERE wl.is_active = TRUE
UNION ALL
SELECT
    'Guest Wishlists' as metric,
    COUNT(DISTINCT gwl.guest_wishlist_id)::TEXT
FROM wishlist.guest_wishlists gwl WHERE gwl.is_active = TRUE AND gwl.is_merged = FALSE
UNION ALL
SELECT
    'Merged Guest Wishlists' as metric,
    COUNT(DISTINCT gwl.guest_wishlist_id)::TEXT
FROM wishlist.guest_wishlists gwl WHERE gwl.is_merged = TRUE
UNION ALL
SELECT
    'Active Price Alerts' as metric,
    COUNT(DISTINCT wa.wishlist_alert_id)::TEXT
FROM wishlist.wishlist_alerts wa
JOIN wishlist.alert_status_lookup asl ON asl.alert_status_id = wa.alert_status_id
WHERE wa.is_active = TRUE AND asl.code = 'PENDING'
UNION ALL
SELECT
    'Shared Wishlists' as metric,
    COUNT(DISTINCT ws.wishlist_share_id)::TEXT
FROM wishlist.wishlist_shares ws WHERE ws.is_active = TRUE
UNION ALL
SELECT
    'Gift Registries' as metric,
    COUNT(DISTINCT wl.wishlist_id)::TEXT
FROM wishlist.wishlists wl
JOIN wishlist.wishlist_type_lookup wlt ON wlt.wishlist_type_id = wl.wishlist_type_id
WHERE wlt.code = 'GIFT_REGISTRY' AND wl.is_active = TRUE
UNION ALL
SELECT
    'Save for Later Items' as metric,
    COUNT(DISTINCT sfl.save_for_later_id)::TEXT
FROM wishlist.save_for_later_items sfl WHERE sfl.is_active = TRUE
UNION ALL
SELECT
    'Recently Viewed Products (7 days)' as metric,
    COUNT(DISTINCT rvp.recently_viewed_id)::TEXT
FROM wishlist.recently_viewed_products rvp
WHERE rvp.viewed_at >= CURRENT_TIMESTAMP - INTERVAL '7 days';

-- Function 1: Get Wishlist Analytics by Date Range
CREATE OR REPLACE FUNCTION reports.get_wishlist_analytics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_date DATE,
    total_wishlists BIGINT,
    total_items BIGINT,
    total_value NUMERIC,
    items_added BIGINT,
    items_purchased BIGINT,
    conversion_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        wana.stat_date,
        SUM(wana.total_wishlists)::BIGINT,
        SUM(wana.total_items)::BIGINT,
        SUM(wana.total_value),
        SUM(wana.items_added)::BIGINT,
        SUM(wana.items_purchased)::BIGINT,
        AVG(wana.conversion_rate)
    FROM wishlist.wishlist_analytics wana
    WHERE wana.company_id = p_company_id
      AND wana.stat_date BETWEEN p_start_date AND p_end_date
    GROUP BY wana.stat_date
    ORDER BY wana.stat_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Customer Wishlist Details
CREATE OR REPLACE FUNCTION reports.get_customer_wishlist_details(
    p_customer_id UUID
)
RETURNS TABLE (
    wishlist_name VARCHAR,
    wishlist_type VARCHAR,
    item_count BIGINT,
    total_value NUMERIC,
    last_modified TIMESTAMPTZ,
    purchased_items BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        wl.wishlist_name::VARCHAR,
        wlt.name::VARCHAR,
        COUNT(DISTINCT wi.wishlist_item_id)::BIGINT,
        COALESCE(SUM(wi.current_price * wi.quantity), 0),
        MAX(wl.updated_at),
        COUNT(DISTINCT CASE WHEN wis.code = 'PURCHASED' THEN wi.wishlist_item_id END)::BIGINT
    FROM wishlist.wishlists wl
    JOIN wishlist.wishlist_type_lookup wlt ON wlt.wishlist_type_id = wl.wishlist_type_id
    LEFT JOIN wishlist.wishlist_items wi ON wi.wishlist_id = wl.wishlist_id AND wi.is_active = TRUE
    LEFT JOIN wishlist.wishlist_item_status_lookup wis ON wis.wishlist_item_status_id = wi.item_status_id
    WHERE wl.customer_id = p_customer_id AND wl.is_active = TRUE
    GROUP BY wl.wishlist_id, wl.wishlist_name, wlt.name, wl.updated_at
    ORDER BY wl.is_default DESC, wl.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;