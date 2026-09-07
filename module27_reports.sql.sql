BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 27: RECOMMENDATIONS & PRODUCT DISCOVERY REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Recommendation Summary Report
CREATE VIEW reports.vw_recommendation_summary AS
SELECT
    DATE(re.occurred_at) as event_date,
    rtl.code as recommendation_type,
    retl.code as event_type,
    COUNT(DISTINCT re.recommendation_event_id) as event_count,
    COUNT(DISTINCT re.customer_id) as unique_customers,
    COUNT(DISTINCT re.session_id) as unique_sessions,
    COUNT(DISTINCT re.product_id) as products_involved
FROM recommendations.recommendation_events re
JOIN recommendations.recommendation_type_lookup rtl ON rtl.recommendation_type_id = re.recommendation_rule_id
JOIN recommendations.recommendation_event_type_lookup retl ON retl.recommendation_event_type_id = re.recommendation_event_type_id
GROUP BY DATE(re.occurred_at), rtl.code, retl.code
ORDER BY event_date DESC;

-- View 2: Recommendation Performance by Type
CREATE VIEW reports.vw_recommendation_performance_by_type AS
SELECT
    rtl.code as recommendation_type,
    rtl.name as recommendation_type_name,
    COUNT(DISTINCT rr.recommendation_rule_id) as rule_count,
    COUNT(DISTINCT CASE WHEN rs.code = 'ACTIVE' THEN rr.recommendation_rule_id END) as active_rules,
    AVG(rr.priority) as avg_priority
FROM recommendations.recommendation_type_lookup rtl
LEFT JOIN recommendations.recommendation_rules rr ON rr.recommendation_type_id = rtl.recommendation_type_id
LEFT JOIN recommendations.recommendation_status_lookup rs ON rs.recommendation_status_id = rr.recommendation_status_id
GROUP BY rtl.recommendation_type_id, rtl.code, rtl.name, rtl.sort_order
ORDER BY rtl.sort_order;

-- View 3: Recommendation CTR Report
CREATE VIEW reports.vw_recommendation_ctr AS
SELECT
    DATE(ri.displayed_at) as display_date,
    rp.code as placement,
    COUNT(DISTINCT ri.recommendation_impression_id) as impressions,
    COUNT(DISTINCT rc.recommendation_click_id) as clicks,
    ROUND((COUNT(DISTINCT rc.recommendation_click_id)::numeric / NULLIF(COUNT(DISTINCT ri.recommendation_impression_id), 0) * 100), 2) as ctr_percent
FROM recommendations.recommendation_impressions ri
LEFT JOIN recommendations.recommendation_clicks rc ON rc.recommendation_impression_id = ri.recommendation_impression_id
LEFT JOIN recommendations.recommendation_placement_lookup rp ON rp.recommendation_placement_id = ri.placement_id
GROUP BY DATE(ri.displayed_at), rp.code
ORDER BY display_date DESC;

-- View 4: Recommendation Conversion Report
CREATE VIEW reports.vw_recommendation_conversion AS
SELECT
    DATE(rc.converted_at) as conversion_date,
    rconv.conversion_type,
    COUNT(DISTINCT rconv.recommendation_conversion_id) as conversion_count,
    SUM(rconv.conversion_value) as total_conversion_value,
    AVG(rconv.conversion_value) as avg_conversion_value
FROM recommendations.recommendation_conversions rconv
GROUP BY DATE(rc.converted_at), rconv.conversion_type
ORDER BY conversion_date DESC;

-- View 5: Product Affinity Report
CREATE VIEW reports.vw_product_affinity_report AS
SELECT
    pa.product_a_id,
    pa_a.product_name as product_a_name,
    pa.product_b_id,
    pa_b.product_name as product_b_name,
    pa.co_purchase_count,
    pa.co_view_count,
    pa.co_cart_count,
    pa.purchase_affinity,
    pa.view_affinity,
    pa.cart_affinity,
    pa.overall_affinity,
    pa.support,
    pa.confidence,
    pa.lift,
    pa.last_calculated_at
FROM recommendations.product_affinity pa
JOIN catalog.products pa_a ON pa_a.product_id = pa.product_a_id
JOIN catalog.products pa_b ON pa_b.product_id = pa.product_b_id
ORDER BY pa.overall_affinity DESC
LIMIT 100;

-- View 6: Top Recommended Products
CREATE VIEW reports.vw_top_recommended_products AS
SELECT
    p.product_code,
    p.product_name,
    p.slug,
    COUNT(DISTINCT ri.recommendation_impression_id) as times_recommended,
    COUNT(DISTINCT rc.recommendation_click_id) as times_clicked,
    COUNT(DISTINCT rconv.recommendation_conversion_id) as times_converted,
    ROUND((COUNT(DISTINCT rc.recommendation_click_id)::numeric / NULLIF(COUNT(DISTINCT ri.recommendation_impression_id), 0) * 100), 2) as ctr_percent,
    ROUND((COUNT(DISTINCT rconv.recommendation_conversion_id)::numeric / NULLIF(COUNT(DISTINCT rc.recommendation_click_id), 0) * 100), 2) as conversion_rate_percent
FROM catalog.products p
LEFT JOIN recommendations.recommendation_impressions ri ON ri.product_id = p.product_id
LEFT JOIN recommendations.recommendation_clicks rc ON rc.product_id = p.product_id
LEFT JOIN recommendations.recommendation_conversions rconv ON rconv.product_id = p.product_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_code, p.product_name, p.slug
ORDER BY times_recommended DESC
LIMIT 50;

-- View 7: Campaign Performance Report
CREATE VIEW reports.vw_recommendation_campaign_performance AS
SELECT
    rc.campaign_code,
    rc.campaign_name,
    rc.campaign_type,
    rcs.code as campaign_status,
    rc.start_date,
    rc.end_date,
    rc.total_impressions,
    rc.total_clicks,
    rc.total_conversions,
    rc.conversion_revenue,
    ROUND((rc.total_clicks::numeric / NULLIF(rc.total_impressions, 0) * 100), 2) as ctr_percent,
    ROUND((rc.total_conversions::numeric / NULLIF(rc.total_clicks, 0) * 100), 2) as conversion_rate_percent,
    rc.is_active
FROM recommendations.recommendation_campaigns rc
JOIN recommendations.recommendation_campaign_status_lookup rcs ON rcs.recommendation_campaign_status_id = rc.recommendation_campaign_status_id
ORDER BY rc.total_conversions DESC NULLS LAST;

-- View 8: A/B Test Results Report
CREATE VIEW reports.vw_ab_test_results AS
SELECT
    rc.campaign_code,
    rc.campaign_name,
    rcv.variant_code,
    rcv.variant_name,
    rcv.is_control,
    rcv.is_winner,
    rcv.traffic_percent,
    rcv.impressions,
    rcv.clicks,
    rcv.conversions,
    rcv.conversion_revenue,
    ROUND((rcv.clicks::numeric / NULLIF(rcv.impressions, 0) * 100), 2) as ctr_percent,
    ROUND((rcv.conversions::numeric / NULLIF(rcv.clicks, 0) * 100), 2) as conversion_rate_percent
FROM recommendations.recommendation_campaigns rc
JOIN recommendations.recommendation_campaign_variants rcv ON rcv.recommendation_campaign_id = rc.recommendation_campaign_id
ORDER BY rc.campaign_code, rcv.is_control DESC, rcv.conversions DESC;

-- View 9: Merchandising Performance Report
CREATE VIEW reports.vw_merchandising_performance AS
SELECT
    rm.merchandising_code,
    rm.merchandising_name,
    rp.code as placement,
    rm.display_title,
    rm.start_date,
    rm.end_date,
    rm.is_active,
    COUNT(DISTINCT rmp.product_id) as product_count,
    COUNT(DISTINCT CASE WHEN rmp.is_pinned = TRUE THEN rmp.product_id END) as pinned_products,
    COUNT(DISTINCT CASE WHEN rmp.is_boosted = TRUE THEN rmp.product_id END) as boosted_products
FROM recommendations.recommendation_merchandising rm
JOIN recommendations.recommendation_placement_lookup rp ON rp.recommendation_placement_id = rm.recommendation_placement_id
LEFT JOIN recommendations.recommendation_merchandising_products rmp ON rmp.recommendation_merchandising_id = rm.recommendation_merchandising_id
GROUP BY rm.recommendation_merchandising_id, rm.merchandising_code, rm.merchandising_name, rp.code, rm.display_title, rm.start_date, rm.end_date, rm.is_active
ORDER BY rm.display_order;

-- View 10: Product Relation Report
CREATE VIEW reports.vw_product_relation_report AS
SELECT
    rtl.code as relation_type,
    rtl.name as relation_type_name,
    COUNT(DISTINCT pr.product_relation_id) as relation_count,
    COUNT(DISTINCT CASE WHEN pr.is_manual = TRUE THEN pr.product_relation_id END) as manual_relations,
    COUNT(DISTINCT CASE WHEN pr.is_active = TRUE THEN pr.product_relation_id END) as active_relations,
    AVG(pr.relation_strength) as avg_relation_strength
FROM recommendations.recommendation_type_lookup rtl
LEFT JOIN recommendations.product_relations pr ON pr.recommendation_type_id = rtl.recommendation_type_id
GROUP BY rtl.recommendation_type_id, rtl.code, rtl.name, rtl.sort_order
ORDER BY rtl.sort_order;

-- View 11: Customer Affinity Report
CREATE VIEW reports.vw_customer_affinity_report AS
SELECT
    c.customer_number,
    c.display_name,
    COUNT(DISTINCT ca.product_id) as products_interacted,
    COUNT(DISTINCT ca.category_id) as categories_interacted,
    AVG(ca.affinity_score) as avg_affinity_score,
    MAX(ca.affinity_score) as max_affinity_score,
    MAX(ca.last_interaction_at) as last_interaction_at
FROM recommendations.customer_affinity ca
JOIN crm.customers c ON c.customer_id = ca.customer_id
GROUP BY c.customer_id, c.customer_number, c.display_name
ORDER BY avg_affinity_score DESC
LIMIT 100;

-- View 12: Session-Based Recommendations Report
CREATE VIEW reports.vw_session_recommendations AS
SELECT
    re.session_id,
    COUNT(DISTINCT re.recommendation_event_id) as total_events,
    COUNT(DISTINCT re.product_id) as products_viewed,
    COUNT(DISTINCT CASE WHEN retl.code = 'ADD_TO_CART' THEN re.recommendation_event_id END) as add_to_cart_events,
    COUNT(DISTINCT CASE WHEN retl.code = 'PURCHASE' THEN re.recommendation_event_id END) as purchase_events,
    MIN(re.occurred_at) as session_start,
    MAX(re.occurred_at) as session_end,
    EXTRACT(EPOCH FROM (MAX(re.occurred_at) - MIN(re.occurred_at))) as session_duration_seconds
FROM recommendations.recommendation_events re
JOIN recommendations.recommendation_event_type_lookup retl ON retl.recommendation_event_type_id = re.recommendation_event_type_id
WHERE re.session_id IS NOT NULL
GROUP BY re.session_id
HAVING COUNT(DISTINCT re.recommendation_event_id) > 1
ORDER BY total_events DESC
LIMIT 100;

-- View 13: Placement Performance Report
CREATE VIEW reports.vw_placement_performance AS
SELECT
    rp.code as placement_code,
    rp.name as placement_name,
    COUNT(DISTINCT ri.recommendation_impression_id) as impressions,
    COUNT(DISTINCT rc.recommendation_click_id) as clicks,
    COUNT(DISTINCT rconv.recommendation_conversion_id) as conversions,
    ROUND((COUNT(DISTINCT rc.recommendation_click_id)::numeric / NULLIF(COUNT(DISTINCT ri.recommendation_impression_id), 0) * 100), 2) as ctr_percent,
    ROUND((COUNT(DISTINCT rconv.recommendation_conversion_id)::numeric / NULLIF(COUNT(DISTINCT rc.recommendation_click_id), 0) * 100), 2) as conversion_rate_percent
FROM recommendations.recommendation_placement_lookup rp
LEFT JOIN recommendations.recommendation_impressions ri ON ri.placement_id = rp.recommendation_placement_id
LEFT JOIN recommendations.recommendation_clicks rc ON rc.placement_id = rp.recommendation_placement_id
LEFT JOIN recommendations.recommendation_conversions rconv ON rconv.placement_id = rp.recommendation_placement_id
GROUP BY rp.recommendation_placement_id, rp.code, rp.name, rp.sort_order
ORDER BY rp.sort_order;

-- View 14: Exclusion Report
CREATE VIEW reports.vw_recommendation_exclusions AS
SELECT
    rexc.exclusion_type,
    p.product_name,
    cat.category_name,
    rexc.exclusion_reason,
    rexc.start_date,
    rexc.end_date,
    rexc.is_active,
    rexc.created_at
FROM recommendations.recommendation_exclusions rexc
LEFT JOIN catalog.products p ON p.product_id = rexc.product_id
LEFT JOIN catalog.categories cat ON cat.category_id = rexc.category_id
ORDER BY rexc.created_at DESC;

-- View 15: Recommendation Trend Report
CREATE VIEW reports.vw_recommendation_trend AS
SELECT
    DATE_TRUNC('week', re.occurred_at) as week_start,
    COUNT(DISTINCT re.recommendation_event_id) as total_events,
    COUNT(DISTINCT re.customer_id) as unique_customers,
    COUNT(DISTINCT re.session_id) as unique_sessions,
    COUNT(DISTINCT CASE WHEN retl.code = 'VIEW' THEN re.recommendation_event_id END) as view_events,
    COUNT(DISTINCT CASE WHEN retl.code = 'CLICK' THEN re.recommendation_event_id END) as click_events,
    COUNT(DISTINCT CASE WHEN retl.code = 'PURCHASE' THEN re.recommendation_event_id END) as purchase_events
FROM recommendations.recommendation_events re
JOIN recommendations.recommendation_event_type_lookup retl ON retl.recommendation_event_type_id = re.recommendation_event_type_id
GROUP BY DATE_TRUNC('week', re.occurred_at)
ORDER BY week_start DESC;

-- View 16: Rule Performance Report
CREATE VIEW reports.vw_rule_performance AS
SELECT
    rr.rule_code,
    rr.rule_name,
    rtl.code as recommendation_type,
    rsl.code as rule_status,
    rr.priority,
    rr.max_results,
    COUNT(DISTINCT re.recommendation_event_id) as event_count,
    COUNT(DISTINCT ri.recommendation_impression_id) as impression_count,
    COUNT(DISTINCT rc.recommendation_click_id) as click_count,
    ROUND((COUNT(DISTINCT rc.recommendation_click_id)::numeric / NULLIF(COUNT(DISTINCT ri.recommendation_impression_id), 0) * 100), 2) as ctr_percent
FROM recommendations.recommendation_rules rr
JOIN recommendations.recommendation_type_lookup rtl ON rtl.recommendation_type_id = rr.recommendation_type_id
JOIN recommendations.recommendation_status_lookup rsl ON rsl.recommendation_status_id = rr.recommendation_status_id
LEFT JOIN recommendations.recommendation_events re ON re.recommendation_rule_id = rr.recommendation_rule_id
LEFT JOIN recommendations.recommendation_impressions ri ON ri.recommendation_rule_id = rr.recommendation_rule_id
LEFT JOIN recommendations.recommendation_clicks rc ON rc.recommendation_rule_id = rr.recommendation_rule_id
GROUP BY rr.recommendation_rule_id, rr.rule_code, rr.rule_name, rtl.code, rsl.code, rr.priority, rr.max_results
ORDER BY event_count DESC NULLS LAST;

-- View 17: Anonymous vs Authenticated Recommendations
CREATE VIEW reports.vw_anonymous_vs_authenticated AS
SELECT
    CASE WHEN re.customer_id IS NOT NULL THEN 'AUTHENTICATED' ELSE 'ANONYMOUS' END as visitor_type,
    COUNT(DISTINCT re.recommendation_event_id) as total_events,
    COUNT(DISTINCT COALESCE(re.customer_id::text, re.session_id)) as unique_visitors,
    COUNT(DISTINCT CASE WHEN retl.code = 'CLICK' THEN re.recommendation_event_id END) as click_events,
    COUNT(DISTINCT CASE WHEN retl.code = 'PURCHASE' THEN re.recommendation_event_id END) as purchase_events,
    ROUND((COUNT(DISTINCT CASE WHEN retl.code = 'CLICK' THEN re.recommendation_event_id END)::numeric / NULLIF(COUNT(DISTINCT re.recommendation_event_id), 0) * 100), 2) as engagement_rate_percent
FROM recommendations.recommendation_events re
JOIN recommendations.recommendation_event_type_lookup retl ON retl.recommendation_event_type_id = re.recommendation_event_type_id
GROUP BY CASE WHEN re.customer_id IS NOT NULL THEN 'AUTHENTICATED' ELSE 'ANONYMOUS' END;

-- View 18: Recommendation Revenue Attribution
CREATE VIEW reports.vw_recommendation_revenue_attribution AS
SELECT
    DATE(rconv.converted_at) as conversion_date,
    rtl.code as recommendation_type,
    COUNT(DISTINCT rconv.recommendation_conversion_id) as conversion_count,
    SUM(rconv.conversion_value) as total_revenue,
    AVG(rconv.conversion_value) as avg_revenue_per_conversion,
    ROUND((SUM(rconv.conversion_value) / NULLIF(COUNT(DISTINCT rconv.recommendation_conversion_id), 0)), 2) as revenue_per_conversion
FROM recommendations.recommendation_conversions rconv
LEFT JOIN recommendations.recommendation_rules rr ON rr.recommendation_rule_id = rconv.recommendation_rule_id
LEFT JOIN recommendations.recommendation_type_lookup rtl ON rtl.recommendation_type_id = rr.recommendation_type_id
GROUP BY DATE(rconv.converted_at), rtl.code
ORDER BY conversion_date DESC;

-- View 19: Recently Viewed Products Report
CREATE VIEW reports.vw_recently_viewed_products AS
SELECT
    p.product_code,
    p.product_name,
    p.slug,
    COUNT(DISTINCT re.recommendation_event_id) as view_count,
    COUNT(DISTINCT COALESCE(re.customer_id::text, re.session_id)) as unique_viewers,
    MAX(re.occurred_at) as last_viewed_at
FROM recommendations.recommendation_events re
JOIN recommendations.recommendation_event_type_lookup retl ON retl.recommendation_event_type_id = re.recommendation_event_type_id
JOIN catalog.products p ON p.product_id = re.product_id
WHERE retl.code = 'VIEW'
  AND re.occurred_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY p.product_id, p.product_code, p.product_name, p.slug
ORDER BY view_count DESC
LIMIT 50;

-- View 20: Recommendation Health Dashboard
CREATE VIEW reports.vw_recommendation_health_dashboard AS
SELECT
    'Total Recommendation Rules' as metric,
    COUNT(DISTINCT rr.recommendation_rule_id)::TEXT as value
FROM recommendations.recommendation_rules rr
UNION ALL
SELECT
    'Active Rules' as metric,
    COUNT(DISTINCT rr.recommendation_rule_id)::TEXT
FROM recommendations.recommendation_rules rr
JOIN recommendations.recommendation_status_lookup rs ON rs.recommendation_status_id = rr.recommendation_status_id
WHERE rs.code = 'ACTIVE'
UNION ALL
SELECT
    'Total Product Relations' as metric,
    COUNT(DISTINCT pr.product_relation_id)::TEXT
FROM recommendations.product_relations pr
UNION ALL
SELECT
    'Active Product Relations' as metric,
    COUNT(DISTINCT pr.product_relation_id)::TEXT
FROM recommendations.product_relations pr
WHERE pr.is_active = TRUE
UNION ALL
SELECT
    'Product Affinity Pairs' as metric,
    COUNT(DISTINCT pa.product_affinity_id)::TEXT
FROM recommendations.product_affinity pa
UNION ALL
SELECT
    'Total Recommendation Events' as metric,
    COUNT(DISTINCT re.recommendation_event_id)::TEXT
FROM recommendations.recommendation_events re
UNION ALL
SELECT
    'Total Impressions' as metric,
    COUNT(DISTINCT ri.recommendation_impression_id)::TEXT
FROM recommendations.recommendation_impressions ri
UNION ALL
SELECT
    'Total Clicks' as metric,
    COUNT(DISTINCT rc.recommendation_click_id)::TEXT
FROM recommendations.recommendation_clicks rc
UNION ALL
SELECT
    'Total Conversions' as metric,
    COUNT(DISTINCT rconv.recommendation_conversion_id)::TEXT
FROM recommendations.recommendation_conversions rconv
UNION ALL
SELECT
    'Active Campaigns' as metric,
    COUNT(DISTINCT rc.recommendation_campaign_id)::TEXT
FROM recommendations.recommendation_campaigns rc
JOIN recommendations.recommendation_campaign_status_lookup rcs ON rcs.recommendation_campaign_status_id = rc.recommendation_campaign_status_id
WHERE rcs.code = 'ACTIVE'
UNION ALL
SELECT
    'Active Merchandising' as metric,
    COUNT(DISTINCT rm.recommendation_merchandising_id)::TEXT
FROM recommendations.recommendation_merchandising rm
WHERE rm.is_active = TRUE
UNION ALL
SELECT
    'Active Exclusions' as metric,
    COUNT(DISTINCT rexc.recommendation_exclusion_id)::TEXT
FROM recommendations.recommendation_exclusions rexc
WHERE rexc.is_active = TRUE;

-- Function 1: Get Recommendation Analytics by Date Range
CREATE OR REPLACE FUNCTION reports.get_recommendation_analytics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_date DATE,
    total_impressions BIGINT,
    total_clicks BIGINT,
    total_conversions BIGINT,
    conversion_revenue NUMERIC,
    ctr_percent NUMERIC,
    conversion_rate_percent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rana.stat_date,
        SUM(rana.total_impressions)::BIGINT,
        SUM(rana.total_clicks)::BIGINT,
        SUM(rana.total_conversions)::BIGINT,
        SUM(rana.conversion_revenue),
        ROUND((SUM(rana.total_clicks)::numeric / NULLIF(SUM(rana.total_impressions), 0) * 100), 2),
        ROUND((SUM(rana.total_conversions)::numeric / NULLIF(SUM(rana.total_clicks), 0) * 100), 2)
    FROM recommendations.recommendation_analytics rana
    WHERE rana.company_id = p_company_id
      AND rana.stat_date BETWEEN p_start_date AND p_end_date
    GROUP BY rana.stat_date
    ORDER BY rana.stat_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Product Recommendations for Display
CREATE OR REPLACE FUNCTION reports.get_product_recommendations_for_display(
    p_product_id UUID,
    p_recommendation_type_code VARCHAR,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR,
    product_slug VARCHAR,
    product_image_url VARCHAR,
    relation_strength NUMERIC,
    price NUMERIC,
    currency_code VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.product_id,
        p.product_name::VARCHAR,
        p.slug::VARCHAR,
        p.featured_image_url::VARCHAR,
        pr.relation_strength,
        COALESCE(pricing.get_product_price(p.product_id), 0) as price,
        'PKR'::VARCHAR as currency_code
    FROM recommendations.product_relations pr
    JOIN recommendations.recommendation_type_lookup rtl ON rtl.recommendation_type_id = pr.recommendation_type_id
    JOIN catalog.products p ON p.product_id = pr.target_product_id
    WHERE pr.source_product_id = p_product_id
      AND rtl.code = p_recommendation_type_code
      AND pr.is_active = TRUE
      AND p.is_active = TRUE
    ORDER BY pr.relation_strength DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMIT;