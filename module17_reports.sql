BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 17: AFFILIATE MARKETING REPORTING
-- 18 Views + 2 Functions
-- ============================================================

-- View 1: Affiliate Summary Dashboard
CREATE VIEW reports.vw_affiliate_summary AS
SELECT 
    DATE(a.created_at) as registration_date,
    atl.code as affiliate_type,
    asl.code as status,
    tier.code as tier,
    COUNT(DISTINCT a.affiliate_id) as affiliate_count,
    SUM(a.total_clicks) as total_clicks,
    SUM(a.total_orders) as total_orders,
    SUM(a.total_commission) as total_commission,
    SUM(a.total_paid) as total_paid,
    SUM(a.current_balance) as total_balance
FROM affiliate.affiliates a
JOIN affiliate.affiliate_type_lookup atl ON atl.affiliate_type_id = a.affiliate_type_id
JOIN affiliate.affiliate_status_lookup asl ON asl.affiliate_status_id = a.affiliate_status_id
LEFT JOIN affiliate.affiliate_tier_lookup tier ON tier.affiliate_tier_id = a.affiliate_tier_id
WHERE a.is_active = TRUE
GROUP BY DATE(a.created_at), atl.code, asl.code, tier.code
ORDER BY registration_date DESC;

-- View 2: Affiliate Performance Ranking
CREATE VIEW reports.vw_affiliate_performance_ranking AS
SELECT 
    a.affiliate_id,
    a.affiliate_code,
    a.display_name,
    a.email,
    atl.name as affiliate_type,
    tier.name as tier,
    a.total_clicks,
    a.total_orders,
    a.total_revenue,
    a.total_commission,
    a.conversion_rate,
    a.average_order_value,
    a.current_balance,
    RANK() OVER (ORDER BY a.total_commission DESC) as commission_rank,
    RANK() OVER (ORDER BY a.total_revenue DESC) as revenue_rank
FROM affiliate.affiliates a
JOIN affiliate.affiliate_type_lookup atl ON atl.affiliate_type_id = a.affiliate_type_id
LEFT JOIN affiliate.affiliate_tier_lookup tier ON tier.affiliate_tier_id = a.affiliate_tier_id
JOIN affiliate.affiliate_status_lookup asl ON asl.affiliate_status_id = a.affiliate_status_id
WHERE asl.code IN ('ACTIVE', 'APPROVED')
ORDER BY a.total_commission DESC;

-- View 3: Commission Summary
CREATE VIEW reports.vw_commission_summary AS
SELECT 
    DATE(c.calculated_at) as commission_date,
    csl.code as status,
    COUNT(DISTINCT c.commission_id) as commission_count,
    SUM(c.order_amount) as total_order_amount,
    SUM(c.commission_amount) as total_commission_amount,
    SUM(c.adjustment_amount) as total_adjustments,
    SUM(c.final_amount) as total_final_amount
FROM affiliate.commissions c
JOIN affiliate.commission_status_lookup csl ON csl.commission_status_id = c.commission_status_id
GROUP BY DATE(c.calculated_at), csl.code
ORDER BY commission_date DESC;

-- View 4: Commission by Affiliate
CREATE VIEW reports.vw_commission_by_affiliate AS
SELECT 
    a.affiliate_code,
    a.display_name,
    csl.code as commission_status,
    COUNT(DISTINCT c.commission_id) as commission_count,
    SUM(c.order_amount) as total_orders_value,
    SUM(c.commission_amount) as total_commission,
    SUM(c.final_amount) as total_final,
    AVG(c.commission_rate) as avg_commission_rate
FROM affiliate.commissions c
JOIN affiliate.affiliates a ON a.affiliate_id = c.affiliate_id
JOIN affiliate.commission_status_lookup csl ON csl.commission_status_id = c.commission_status_id
GROUP BY a.affiliate_code, a.display_name, csl.code
ORDER BY total_commission DESC;

-- View 5: Pending Commissions (Awaiting Return Window)
CREATE VIEW reports.vw_pending_commissions AS
SELECT 
    c.commission_id,
    c.commission_number,
    a.affiliate_code,
    a.display_name as affiliate_name,
    o.order_number,
    c.order_amount,
    c.commission_amount,
    c.final_amount,
    c.return_window_ends_at,
    CURRENT_DATE - c.return_window_ends_at::DATE as days_until_lock,
    csl.code as status
FROM affiliate.commissions c
JOIN affiliate.affiliates a ON a.affiliate_id = c.affiliate_id
LEFT JOIN sales.orders o ON o.order_id = c.order_id
JOIN affiliate.commission_status_lookup csl ON csl.commission_status_id = c.commission_status_id
WHERE csl.code = 'PENDING'
  AND c.return_window_ends_at > CURRENT_TIMESTAMP
ORDER BY c.return_window_ends_at ASC;

-- View 6: Payout Summary
CREATE VIEW reports.vw_payout_summary AS
SELECT 
    DATE(pr.requested_at) as request_date,
    psl.code as status,
    pm.code as method,
    COUNT(DISTINCT pr.payout_request_id) as payout_count,
    SUM(pr.requested_amount) as total_requested,
    SUM(COALESCE(pr.approved_amount, 0)) as total_approved,
    SUM(COALESCE(pr.paid_amount, 0)) as total_paid
FROM affiliate.payout_requests pr
JOIN affiliate.payout_status_lookup psl ON psl.payout_status_id = pr.payout_status_id
JOIN affiliate.payout_method_lookup pm ON pm.payout_method_id = pr.payout_method_id
GROUP BY DATE(pr.requested_at), psl.code, pm.code
ORDER BY request_date DESC;

-- View 7: Payout Queue (Pending Approval)
CREATE VIEW reports.vw_payout_queue AS
SELECT 
    pr.payout_request_id,
    pr.payout_number,
    a.affiliate_code,
    a.display_name as affiliate_name,
    pm.name as payout_method,
    pr.requested_amount,
    pr.requested_at,
    CURRENT_DATE - pr.requested_at::DATE as days_pending,
    pr.bank_account_title,
    pr.wallet_number
FROM affiliate.payout_requests pr
JOIN affiliate.affiliates a ON a.affiliate_id = pr.affiliate_id
JOIN affiliate.payout_method_lookup pm ON pm.payout_method_id = pr.payout_method_id
JOIN affiliate.payout_status_lookup psl ON psl.payout_status_id = pr.payout_status_id
WHERE psl.code IN ('REQUESTED', 'ON_HOLD')
ORDER BY pr.requested_at ASC;

-- View 8: Click Performance by Affiliate
CREATE VIEW reports.vw_click_performance AS
SELECT 
    a.affiliate_code,
    a.display_name,
    COUNT(DISTINCT ac.affiliate_click_id) as total_clicks,
    COUNT(DISTINCT CASE WHEN ac.is_unique = TRUE THEN ac.affiliate_click_id END) as unique_clicks,
    COUNT(DISTINCT CASE WHEN ac.converted = TRUE THEN ac.affiliate_click_id END) as converted_clicks,
    ROUND((COUNT(DISTINCT CASE WHEN ac.converted = TRUE THEN ac.affiliate_click_id END)::numeric / 
           NULLIF(COUNT(DISTINCT ac.affiliate_click_id), 0) * 100), 2) as conversion_rate_percent
FROM affiliate.affiliate_clicks ac
JOIN affiliate.affiliates a ON a.affiliate_id = ac.affiliate_id
GROUP BY a.affiliate_code, a.display_name
ORDER BY total_clicks DESC;

-- View 9: Link Performance
CREATE VIEW reports.vw_link_performance AS
SELECT 
    al.link_code,
    al.link_name,
    a.affiliate_code,
    a.display_name as affiliate_name,
    al.destination_url,
    al.total_clicks,
    al.total_conversions,
    al.conversion_rate,
    al.is_active
FROM affiliate.affiliate_links al
JOIN affiliate.affiliates a ON a.affiliate_id = al.affiliate_id
ORDER BY al.total_clicks DESC;

-- View 10: Coupon Performance by Affiliate
CREATE VIEW reports.vw_coupon_performance AS
SELECT 
    a.affiliate_code,
    a.display_name as affiliate_name,
    pc.code as coupon_code,
    ac.is_exclusive,
    ac.total_usage_count,
    ac.total_revenue_generated,
    ac.total_commission_generated
FROM affiliate.affiliate_coupons ac
JOIN affiliate.affiliates a ON a.affiliate_id = ac.affiliate_id
JOIN pricing.coupons pc ON pc.coupon_id = ac.coupon_id
ORDER BY ac.total_revenue_generated DESC;

-- View 11: Fraud Flags Report
CREATE VIEW reports.vw_fraud_flags AS
SELECT 
    ff.fraud_flag_id,
    a.affiliate_code,
    a.display_name as affiliate_name,
    fftl.code as flag_type,
    fftl.name as flag_name,
    ff.severity,
    ff.description,
    ff.detected_at,
    ff.status,
    ff.reviewed_at
FROM affiliate.fraud_flags ff
JOIN affiliate.affiliates a ON a.affiliate_id = ff.affiliate_id
JOIN affiliate.fraud_flag_type_lookup fftl ON fftl.fraud_flag_type_id = ff.fraud_flag_type_id
ORDER BY ff.severity DESC, ff.detected_at DESC;

-- View 12: Affiliate Tier Distribution
CREATE VIEW reports.vw_affiliate_tier_distribution AS
SELECT 
    tier.code as tier_code,
    tier.name as tier_name,
    COUNT(DISTINCT a.affiliate_id) as affiliate_count,
    SUM(a.total_orders) as total_orders,
    SUM(a.total_commission) as total_commission,
    AVG(a.conversion_rate) as avg_conversion_rate
FROM affiliate.affiliate_tier_lookup tier
LEFT JOIN affiliate.affiliates a ON a.affiliate_tier_id = tier.affiliate_tier_id AND a.is_active = TRUE
GROUP BY tier.affiliate_tier_id, tier.code, tier.name, tier.sort_order
ORDER BY tier.sort_order;

-- View 13: Monthly Affiliate Revenue
CREATE VIEW reports.vw_monthly_affiliate_revenue AS
SELECT 
    DATE_TRUNC('month', c.calculated_at) as month,
    COUNT(DISTINCT c.affiliate_id) as active_affiliates,
    COUNT(DISTINCT c.order_id) as orders_attributed,
    SUM(c.order_amount) as total_order_value,
    SUM(c.commission_amount) as total_commission_earned,
    SUM(c.final_amount) as total_final_commission
FROM affiliate.commissions c
GROUP BY DATE_TRUNC('month', c.calculated_at)
ORDER BY month DESC;

-- View 14: Attribution Analysis
CREATE VIEW reports.vw_attribution_analysis AS
SELECT 
    aml.code as attribution_model,
    aml.name as model_name,
    COUNT(DISTINCT attr.attribution_id) as total_attributions,
    SUM(attr.attributed_amount) as total_attributed_value,
    COUNT(DISTINCT attr.affiliate_id) as affiliates_with_attributions
FROM affiliate.attributions attr
JOIN affiliate.attribution_model_lookup aml ON aml.attribution_model_id = attr.attribution_model_id
WHERE attr.is_valid = TRUE
GROUP BY aml.attribution_model_id, aml.code, aml.name
ORDER BY total_attributed_value DESC;

-- View 15: Application Pipeline
CREATE VIEW reports.vw_application_pipeline AS
SELECT 
    aa.status,
    aa.applicant_type,
    COUNT(DISTINCT aa.affiliate_application_id) as application_count,
    COUNT(DISTINCT CASE WHEN aa.affiliate_id IS NOT NULL THEN aa.affiliate_application_id END) as converted_count
FROM affiliate.affiliate_applications aa
GROUP BY aa.status, aa.applicant_type
ORDER BY application_count DESC;

-- View 16: Commission Reversals (Returns)
CREATE VIEW reports.vw_commission_reversals AS
SELECT 
    ca.adjustment_type,
    c.commission_number,
    a.affiliate_code,
    a.display_name as affiliate_name,
    o.order_number,
    ca.adjustment_amount,
    ca.reason,
    ca.adjusted_at
FROM affiliate.commission_adjustments ca
JOIN affiliate.commissions c ON c.commission_id = ca.commission_id
JOIN affiliate.affiliates a ON a.affiliate_id = c.affiliate_id
LEFT JOIN sales.orders o ON o.order_id = c.order_id
WHERE ca.adjustment_amount < 0
ORDER BY ca.adjusted_at DESC;

-- View 17: Affiliate Balance Statement
CREATE VIEW reports.vw_affiliate_balance_statement AS
SELECT 
    abt.balance_transaction_id,
    a.affiliate_code,
    a.display_name as affiliate_name,
    abt.transaction_type,
    abt.amount,
    abt.balance_before,
    abt.balance_after,
    abt.description,
    abt.created_at
FROM affiliate.affiliate_balance_transactions abt
JOIN affiliate.affiliates a ON a.affiliate_id = abt.affiliate_id
ORDER BY a.affiliate_code, abt.created_at DESC;

-- View 18: Affiliate ROI Report
CREATE VIEW reports.vw_affiliate_roi AS
SELECT 
    a.affiliate_code,
    a.display_name,
    a.total_revenue as revenue_generated,
    a.total_commission as commission_cost,
    a.total_revenue - a.total_commission as net_revenue,
    CASE 
        WHEN a.total_commission > 0 
        THEN ROUND(((a.total_revenue - a.total_commission) / a.total_commission * 100)::numeric, 2)
        ELSE NULL 
    END as roi_percent,
    a.total_clicks,
    a.total_orders,
    a.conversion_rate
FROM affiliate.affiliates a
JOIN affiliate.affiliate_status_lookup asl ON asl.affiliate_status_id = a.affiliate_status_id
WHERE asl.code IN ('ACTIVE', 'APPROVED')
ORDER BY a.total_revenue DESC;

-- Function 1: Get Affiliate Performance by Date Range
CREATE OR REPLACE FUNCTION reports.get_affiliate_performance(
    p_affiliate_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    total_clicks BIGINT,
    total_conversions BIGINT,
    conversion_rate NUMERIC,
    total_revenue NUMERIC,
    total_commission NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT ac.affiliate_click_id),
        COUNT(DISTINCT CASE WHEN ac.converted = TRUE THEN ac.affiliate_click_id END),
        ROUND((COUNT(DISTINCT CASE WHEN ac.converted = TRUE THEN ac.affiliate_click_id END)::numeric / 
               NULLIF(COUNT(DISTINCT ac.affiliate_click_id), 0) * 100), 2),
        COALESCE(SUM(c.order_amount), 0),
        COALESCE(SUM(c.final_amount), 0)
    FROM affiliate.affiliate_clicks ac
    LEFT JOIN affiliate.commissions c ON c.order_id = ac.order_id AND c.affiliate_id = p_affiliate_id
    WHERE ac.affiliate_id = p_affiliate_id
      AND ac.click_date::DATE BETWEEN p_start_date AND p_end_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Commission History for Affiliate
CREATE OR REPLACE FUNCTION reports.get_affiliate_commission_history(
    p_affiliate_id UUID
)
RETURNS TABLE (
    commission_number VARCHAR,
    order_number VARCHAR,
    order_amount NUMERIC,
    commission_amount NUMERIC,
    status VARCHAR,
    calculated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.commission_number::VARCHAR,
        o.order_number::VARCHAR,
        c.order_amount,
        c.final_amount,
        csl.code::VARCHAR,
        c.calculated_at
    FROM affiliate.commissions c
    LEFT JOIN sales.orders o ON o.order_id = c.order_id
    JOIN affiliate.commission_status_lookup csl ON csl.commission_status_id = c.commission_status_id
    WHERE c.affiliate_id = p_affiliate_id
    ORDER BY c.calculated_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;