BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 18: LOYALTY, REWARDS & CUSTOMER RETENTION REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Loyalty Program Summary Dashboard
CREATE VIEW reports.vw_loyalty_program_summary AS
SELECT 
    lp.program_code,
    lp.program_name,
    lps.code as program_status,
    COUNT(DISTINCT clm.customer_loyalty_membership_id) as total_members,
    COUNT(DISTINCT CASE WHEN clm.membership_status = 'ACTIVE' THEN clm.customer_loyalty_membership_id END) as active_members,
    SUM(clm.total_points_earned) as total_points_issued,
    SUM(clm.total_points_redeemed) as total_points_redeemed,
    SUM(clm.current_points_balance) as total_outstanding_points,
    SUM(clm.lifetime_spend) as total_lifetime_spend
FROM loyalty.loyalty_programs lp
JOIN loyalty.loyalty_program_status_lookup lps ON lps.loyalty_program_status_id = lp.loyalty_program_status_id
LEFT JOIN loyalty.customer_loyalty_memberships clm ON clm.loyalty_program_id = lp.loyalty_program_id
GROUP BY lp.loyalty_program_id, lp.program_code, lp.program_name, lps.code
ORDER BY total_members DESC NULLS LAST;

-- View 2: Member Tier Distribution
CREATE VIEW reports.vw_member_tier_distribution AS
SELECT 
    lp.program_name,
    lt.tier_name,
    lt.tier_level,
    COUNT(DISTINCT clm.customer_loyalty_membership_id) as member_count,
    SUM(clm.current_points_balance) as total_points,
    SUM(clm.lifetime_spend) as total_spend,
    AVG(clm.lifetime_spend) FILTER (WHERE clm.lifetime_spend > 0) as avg_spend_per_member
FROM loyalty.loyalty_tiers lt
JOIN loyalty.loyalty_programs lp ON lp.loyalty_program_id = lt.loyalty_program_id
LEFT JOIN loyalty.customer_loyalty_memberships clm ON clm.current_tier_id = lt.loyalty_tier_id AND clm.membership_status = 'ACTIVE'
WHERE lt.is_active = TRUE
GROUP BY lt.loyalty_tier_id, lp.program_name, lt.tier_name, lt.tier_level
ORDER BY lt.tier_level;

-- View 3: Points Earning Summary
CREATE VIEW reports.vw_points_earning_summary AS
SELECT 
    DATE(pt.created_at) as earning_date,
    pttl.code as transaction_type,
    pttl.name as transaction_type_name,
    COUNT(DISTINCT pt.points_transaction_id) as transaction_count,
    COUNT(DISTINCT pt.customer_loyalty_membership_id) as unique_members,
    SUM(pt.points_amount) FILTER (WHERE pt.points_amount > 0) as points_earned,
    SUM(ABS(pt.points_amount)) FILTER (WHERE pt.points_amount < 0) as points_deducted,
    SUM(pt.points_amount) as net_points_change
FROM loyalty.points_transactions pt
JOIN loyalty.points_transaction_type_lookup pttl ON pttl.points_transaction_type_id = pt.points_transaction_type_id
WHERE pt.is_reversed = FALSE
GROUP BY DATE(pt.created_at), pttl.code, pttl.name
ORDER BY earning_date DESC;

-- View 4: Points Balance by Member (Top 50)
CREATE VIEW reports.vw_member_points_balance AS
SELECT 
    clm.membership_number,
    c.customer_number,
    c.display_name,
    lp.program_name,
    lt.tier_name,
    clm.current_points_balance,
    clm.pending_points,
    clm.total_points_earned,
    clm.total_points_redeemed,
    clm.total_points_expired,
    clm.last_activity_at
FROM loyalty.customer_loyalty_memberships clm
JOIN crm.customers c ON c.customer_id = clm.customer_id
JOIN loyalty.loyalty_programs lp ON lp.loyalty_program_id = clm.loyalty_program_id
LEFT JOIN loyalty.loyalty_tiers lt ON lt.loyalty_tier_id = clm.current_tier_id
WHERE clm.membership_status = 'ACTIVE'
ORDER BY clm.current_points_balance DESC
LIMIT 50;

-- View 5: Points Expiring Soon
CREATE VIEW reports.vw_points_expiring_soon AS
SELECT 
    pbb.points_balance_bucket_id,
    clm.membership_number,
    c.customer_number,
    c.display_name,
    pbb.points_remaining,
    pbb.earned_at,
    pbb.expires_at,
    pbb.expires_at::DATE - CURRENT_DATE as days_until_expiry,
    pbb.source_type,
    pbb.source_reference
FROM loyalty.points_balance_buckets pbb
JOIN loyalty.customer_loyalty_memberships clm ON clm.customer_loyalty_membership_id = pbb.customer_loyalty_membership_id
JOIN crm.customers c ON c.customer_id = clm.customer_id
WHERE pbb.is_expired = FALSE
  AND pbb.points_remaining > 0
  AND pbb.expires_at <= CURRENT_TIMESTAMP + INTERVAL '30 days'
ORDER BY pbb.expires_at ASC;

-- View 6: Redemption Summary
CREATE VIEW reports.vw_redemption_summary AS
SELECT 
    DATE(rr.requested_at) as redemption_date,
    rsl.code as status,
    r.reward_name,
    rtl.code as reward_type,
    COUNT(DISTINCT rr.reward_redemption_id) as redemption_count,
    SUM(rr.points_spent) as total_points_spent,
    SUM(COALESCE(rr.cash_value, 0)) as total_cash_value
FROM loyalty.reward_redemptions rr
JOIN loyalty.redemption_status_lookup rsl ON rsl.redemption_status_id = rr.redemption_status_id
JOIN loyalty.rewards r ON r.reward_id = rr.reward_id
JOIN loyalty.reward_type_lookup rtl ON rtl.reward_type_id = r.reward_type_id
GROUP BY DATE(rr.requested_at), rsl.code, r.reward_name, rtl.code
ORDER BY redemption_date DESC;

-- View 7: Reward Catalog Performance
CREATE VIEW reports.vw_reward_catalog_performance AS
SELECT 
    r.reward_code,
    r.reward_name,
    rtl.name as reward_type,
    r.points_cost,
    r.cash_value,
    r.total_quantity,
    r.remaining_quantity,
    r.max_per_customer,
    r.is_featured,
    COUNT(DISTINCT rr.reward_redemption_id) as total_redemptions,
    COUNT(DISTINCT CASE WHEN rsl.code = 'FULFILLED' THEN rr.reward_redemption_id END) as fulfilled_count,
    SUM(COALESCE(rr.points_spent, 0)) as total_points_consumed
FROM loyalty.rewards r
JOIN loyalty.reward_type_lookup rtl ON rtl.reward_type_id = r.reward_type_id
LEFT JOIN loyalty.reward_redemptions rr ON rr.reward_id = r.reward_id
LEFT JOIN loyalty.redemption_status_lookup rsl ON rsl.redemption_status_id = rr.redemption_status_id
WHERE r.is_active = TRUE
GROUP BY r.reward_id, r.reward_code, r.reward_name, rtl.name, r.points_cost, r.cash_value, 
         r.total_quantity, r.remaining_quantity, r.max_per_customer, r.is_featured
ORDER BY total_redemptions DESC NULLS LAST;

-- View 8: Voucher Status Report
CREATE VIEW reports.vw_voucher_status AS
SELECT 
    v.voucher_code,
    v.voucher_type,
    vsl.code as voucher_status,
    c.customer_number,
    c.display_name,
    v.discount_percentage,
    v.discount_amount,
    v.valid_from,
    v.valid_until,
    v.usage_count,
    v.max_usage,
    v.points_cost,
    v.first_used_at,
    v.redeemed_at
FROM loyalty.vouchers v
JOIN loyalty.voucher_status_lookup vsl ON vsl.voucher_status_id = v.voucher_status_id
JOIN crm.customers c ON c.customer_id = v.customer_id
ORDER BY v.issued_at DESC;

-- View 9: Voucher Expiring Soon
CREATE VIEW reports.vw_voucher_expiring_soon AS
SELECT 
    v.voucher_code,
    v.voucher_type,
    c.customer_number,
    c.display_name,
    v.discount_percentage,
    v.discount_amount,
    v.valid_until,
    v.valid_until::DATE - CURRENT_DATE as days_until_expiry,
    v.max_usage - v.usage_count as remaining_uses
FROM loyalty.vouchers v
JOIN crm.customers c ON c.customer_id = v.customer_id
JOIN loyalty.voucher_status_lookup vsl ON vsl.voucher_status_id = v.voucher_status_id
WHERE vsl.code IN ('ISSUED', 'ACTIVE')
  AND v.is_expired = FALSE
  AND v.valid_until <= CURRENT_TIMESTAMP + INTERVAL '7 days'
ORDER BY v.valid_until ASC;

-- View 10: Cashback Summary
CREATE VIEW reports.vw_cashback_summary AS
SELECT 
    DATE(ct.earned_at) as earning_date,
    ct.status,
    COUNT(DISTINCT ct.cashback_transaction_id) as transaction_count,
    COUNT(DISTINCT ct.customer_id) as unique_customers,
    SUM(ct.cashback_amount) as total_cashback_amount,
    AVG(ct.cashback_amount) as avg_cashback_amount,
    SUM(ct.order_amount) as total_order_amount,
    ROUND((SUM(ct.cashback_amount) / NULLIF(SUM(ct.order_amount), 0) * 100)::numeric, 2) as cashback_rate_percent
FROM loyalty.cashback_transactions ct
GROUP BY DATE(ct.earned_at), ct.status
ORDER BY earning_date DESC;

-- View 11: Cashback by Customer
CREATE VIEW reports.vw_cashback_by_customer AS
SELECT 
    c.customer_number,
    c.display_name,
    COUNT(DISTINCT ct.cashback_transaction_id) as total_cashback_transactions,
    SUM(CASE WHEN ct.status IN ('AVAILABLE', 'CREDITED') THEN ct.cashback_amount ELSE 0 END) as total_cashback_earned,
    SUM(CASE WHEN ct.status = 'CREDITED' THEN ct.cashback_amount ELSE 0 END) as total_cashback_credited,
    SUM(CASE WHEN ct.status = 'PENDING' THEN ct.cashback_amount ELSE 0 END) as pending_cashback,
    SUM(CASE WHEN ct.status = 'EXPIRED' THEN ct.cashback_amount ELSE 0 END) as expired_cashback
FROM loyalty.cashback_transactions ct
JOIN crm.customers c ON c.customer_id = ct.customer_id
GROUP BY c.customer_id, c.customer_number, c.display_name
ORDER BY total_cashback_earned DESC;

-- View 12: Referral Program Performance
CREATE VIEW reports.vw_referral_program_performance AS
SELECT 
    rp.program_name,
    rp.is_active,
    COUNT(DISTINCT rc.referral_code_id) as total_referral_codes,
    SUM(rc.total_referrals) as total_referrals_made,
    SUM(rc.successful_referrals) as total_successful_referrals,
    SUM(rc.pending_referrals) as total_pending_referrals,
    SUM(rc.total_rewards_earned) as total_rewards_earned,
    SUM(rc.total_points_earned) as total_points_earned,
    ROUND((SUM(rc.successful_referrals)::numeric / NULLIF(SUM(rc.total_referrals), 0) * 100), 2) as conversion_rate_percent
FROM loyalty.referral_programs rp
LEFT JOIN loyalty.referral_codes rc ON rc.referral_program_id = rp.referral_program_id AND rc.is_active = TRUE
GROUP BY rp.referral_program_id, rp.program_name, rp.is_active
ORDER BY total_referrals_made DESC NULLS LAST;

-- View 13: Top Referrers
CREATE VIEW reports.vw_top_referrers AS
SELECT 
    c.customer_number,
    c.display_name,
    rc.referral_code,
    rc.total_referrals,
    rc.successful_referrals,
    rc.total_points_earned,
    rc.total_rewards_earned,
    rc.last_referral_at,
    ROUND((rc.successful_referrals::numeric / NULLIF(rc.total_referrals, 0) * 100), 2) as success_rate
FROM loyalty.referral_codes rc
JOIN crm.customers c ON c.customer_id = rc.customer_id
WHERE rc.is_active = TRUE
ORDER BY rc.successful_referrals DESC
LIMIT 50;

-- View 14: Referral Transaction Status
CREATE VIEW reports.vw_referral_transaction_status AS
SELECT 
    rt.status,
    COUNT(DISTINCT rt.referral_transaction_id) as transaction_count,
    SUM(COALESCE(rt.referrer_points_awarded, 0)) as total_referrer_points,
    SUM(COALESCE(rt.referee_points_awarded, 0)) as total_referee_points,
    SUM(COALESCE(rt.referrer_reward_amount, 0)) as total_referrer_rewards,
    SUM(COALESCE(rt.referee_reward_amount, 0)) as total_referee_rewards
FROM loyalty.referral_transactions rt
GROUP BY rt.status
ORDER BY transaction_count DESC;

-- View 15: Milestone Achievements
CREATE VIEW reports.vw_milestone_achievements AS
SELECT 
    pm.milestone_name,
    pm.milestone_type,
    pm.milestone_value,
    pm.reward_type,
    COUNT(DISTINCT ma.milestone_achievement_id) as total_achievements,
    SUM(COALESCE(ma.points_awarded, 0)) as total_points_awarded,
    SUM(COALESCE(ma.cashback_awarded, 0)) as total_cashback_awarded,
    MAX(ma.achieved_at) as last_achievement_at
FROM loyalty.purchase_milestones pm
LEFT JOIN loyalty.milestone_achievements ma ON ma.purchase_milestone_id = pm.purchase_milestone_id
WHERE pm.is_active = TRUE
GROUP BY pm.purchase_milestone_id, pm.milestone_name, pm.milestone_type, pm.milestone_value, pm.reward_type
ORDER BY total_achievements DESC NULLS LAST;

-- View 16: Birthday Rewards History
CREATE VIEW reports.vw_birthday_rewards_history AS
SELECT 
    DATE(brh.birthday_date) as birthday_date,
    c.customer_number,
    c.display_name,
    br.reward_name,
    brh.points_awarded,
    brh.cashback_awarded,
    brh.awarded_at
FROM loyalty.birthday_reward_history brh
JOIN loyalty.birthday_rewards br ON br.birthday_reward_id = brh.birthday_reward_id
JOIN crm.customers c ON c.customer_id = brh.customer_id
ORDER BY brh.birthday_date DESC;

-- View 17: Loyalty Campaign Performance
CREATE VIEW reports.vw_loyalty_campaign_performance AS
SELECT 
    lc.campaign_name,
    lc.campaign_type,
    lc.points_multiplier,
    lc.bonus_points,
    lc.start_date,
    lc.end_date,
    lc.is_active,
    CASE 
        WHEN CURRENT_TIMESTAMP < lc.start_date THEN 'UPCOMING'
        WHEN CURRENT_TIMESTAMP BETWEEN lc.start_date AND lc.end_date THEN 'ACTIVE'
        ELSE 'ENDED'
    END as campaign_status
FROM loyalty.loyalty_campaigns lc
ORDER BY lc.start_date DESC;

-- View 18: Member Activity Summary
CREATE VIEW reports.vw_member_activity_summary AS
SELECT 
    DATE(clm.enrolled_at) as enrollment_date,
    lp.program_name,
    COUNT(DISTINCT clm.customer_loyalty_membership_id) as new_members,
    SUM(CASE WHEN clm.membership_status = 'ACTIVE' THEN 1 ELSE 0 END) as active_members,
    SUM(CASE WHEN clm.membership_status = 'SUSPENDED' THEN 1 ELSE 0 END) as suspended_members,
    SUM(CASE WHEN clm.is_opted_out = TRUE THEN 1 ELSE 0 END) as opted_out_members
FROM loyalty.customer_loyalty_memberships clm
JOIN loyalty.loyalty_programs lp ON lp.loyalty_program_id = clm.loyalty_program_id
GROUP BY DATE(clm.enrolled_at), lp.program_name
ORDER BY enrollment_date DESC;

-- View 19: Retention Analysis
CREATE VIEW reports.vw_retention_analysis AS
SELECT 
    DATE_TRUNC('month', clm.enrolled_at) as enrollment_month,
    COUNT(DISTINCT clm.customer_loyalty_membership_id) as cohort_size,
    COUNT(DISTINCT CASE WHEN clm.membership_status = 'ACTIVE' AND clm.last_activity_at >= CURRENT_TIMESTAMP - INTERVAL '90 days' THEN clm.customer_loyalty_membership_id END) as active_90_days,
    COUNT(DISTINCT CASE WHEN clm.membership_status = 'ACTIVE' AND clm.last_activity_at >= CURRENT_TIMESTAMP - INTERVAL '30 days' THEN clm.customer_loyalty_membership_id END) as active_30_days,
    COUNT(DISTINCT CASE WHEN clm.is_opted_out = TRUE THEN clm.customer_loyalty_membership_id END) as churned,
    ROUND((COUNT(DISTINCT CASE WHEN clm.membership_status = 'ACTIVE' AND clm.last_activity_at >= CURRENT_TIMESTAMP - INTERVAL '90 days' THEN clm.customer_loyalty_membership_id END)::numeric / 
           NULLIF(COUNT(DISTINCT clm.customer_loyalty_membership_id), 0) * 100), 2) as retention_rate_90d
FROM loyalty.customer_loyalty_memberships clm
GROUP BY DATE_TRUNC('month', clm.enrolled_at)
ORDER BY enrollment_month DESC;

-- View 20: Loyalty ROI Analysis
CREATE VIEW reports.vw_loyalty_roi AS
SELECT 
    lp.program_code,
    lp.program_name,
    SUM(clm.total_points_earned) as points_issued,
    SUM(clm.total_points_redeemed) as points_redeemed,
    SUM(clm.lifetime_spend) as total_member_spend,
    SUM(clm.current_points_balance * lp.currency_unit_per_point) as liability_value,
    ROUND((SUM(clm.lifetime_spend) / NULLIF(SUM(clm.total_points_earned * lp.currency_unit_per_point), 0))::numeric, 2) as revenue_per_point_issued
FROM loyalty.loyalty_programs lp
LEFT JOIN loyalty.customer_loyalty_memberships clm ON clm.loyalty_program_id = lp.loyalty_program_id
GROUP BY lp.loyalty_program_id, lp.program_code, lp.program_name, lp.currency_unit_per_point
ORDER BY total_member_spend DESC NULLS LAST;

-- Function 1: Get Member Loyalty Summary
CREATE OR REPLACE FUNCTION reports.get_member_loyalty_summary(
    p_customer_id UUID
)
RETURNS TABLE (
    program_name VARCHAR,
    membership_number VARCHAR,
    tier_name VARCHAR,
    current_balance BIGINT,
    pending_points BIGINT,
    total_earned BIGINT,
    total_redeemed BIGINT,
    lifetime_spend NUMERIC,
    last_activity TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        lp.program_name::VARCHAR,
        clm.membership_number::VARCHAR,
        lt.tier_name::VARCHAR,
        clm.current_points_balance,
        clm.pending_points,
        clm.total_points_earned,
        clm.total_points_redeemed,
        clm.lifetime_spend,
        clm.last_activity_at
    FROM loyalty.customer_loyalty_memberships clm
    JOIN loyalty.loyalty_programs lp ON lp.loyalty_program_id = clm.loyalty_program_id
    LEFT JOIN loyalty.loyalty_tiers lt ON lt.loyalty_tier_id = clm.current_tier_id
    WHERE clm.customer_id = p_customer_id
    ORDER BY clm.enrolled_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Points Ledger for Member
CREATE OR REPLACE FUNCTION reports.get_member_points_ledger(
    p_customer_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    transaction_date TIMESTAMPTZ,
    transaction_type VARCHAR,
    points BIGINT,
    balance_after BIGINT,
    description TEXT,
    order_number VARCHAR,
    expires_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.created_at,
        pttl.code::VARCHAR,
        pt.points_amount,
        pt.points_balance_after,
        pt.description,
        o.order_number::VARCHAR,
        pt.expires_at
    FROM loyalty.points_transactions pt
    JOIN loyalty.points_transaction_type_lookup pttl ON pttl.points_transaction_type_id = pt.points_transaction_type_id
    JOIN loyalty.customer_loyalty_memberships clm ON clm.customer_loyalty_membership_id = pt.customer_loyalty_membership_id
    LEFT JOIN sales.orders o ON o.order_id = pt.order_id
    WHERE clm.customer_id = p_customer_id
      AND (p_start_date IS NULL OR pt.created_at::DATE >= p_start_date)
      AND (p_end_date IS NULL OR pt.created_at::DATE <= p_end_date)
    ORDER BY pt.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;