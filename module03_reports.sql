BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 03: CRM / CUSTOMER RELATIONSHIP MANAGEMENT REPORTING
-- 25 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Customer 360 Profile (On-demand, Critical)
-- Complete customer view
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_360 AS
SELECT
    c.customer_id,
    c.customer_number,
    c.display_name,
    c.email,
    c.phone,
    ctl.code AS customer_type,
    csl.code AS customer_status,
    c.is_vip,
    c.is_active,
    c.created_at AS customer_since,
    COALESCE(cas.total_orders, 0) AS total_orders,
    COALESCE(cas.total_order_amount, 0) AS total_revenue,
    COALESCE(cas.total_paid_amount, 0) AS total_paid,
    COALESCE(cas.outstanding_balance, 0) AS outstanding_balance,
    COALESCE(cas.customer_lifetime_value, 0) AS lifetime_value,
    COALESCE(cas.total_interactions, 0) AS total_interactions,
    COALESCE(cas.total_service_cases, 0) AS total_service_cases,
    COALESCE(cas.last_order_date, c.created_at::DATE) AS last_order_date,
    c.first_acquisition_source_id,
    c.last_acquisition_source_id
FROM crm.customers c
JOIN crm.customer_type_lookup ctl ON ctl.customer_type_id = c.customer_type_id
JOIN crm.customer_status_lookup csl ON csl.customer_status_id = c.customer_status_id
LEFT JOIN crm.customer_account_summary cas ON cas.customer_id = c.customer_id
WHERE c.is_active = TRUE
ORDER BY c.created_at DESC;

-- ------------------------------------------------------------
-- Report 2: Customer Acquisition (Weekly, Critical)
-- New customers by source
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_acquisition AS
SELECT
    DATE(ca.acquisition_date) AS acquisition_date,
    ca.acquisition_channel,
    COUNT(DISTINCT ca.customer_id) AS new_customers,
    SUM(ca.acquisition_cost) AS total_acquisition_cost,
    CASE
        WHEN COUNT(DISTINCT ca.customer_id) > 0
        THEN ROUND((SUM(ca.acquisition_cost) / COUNT(DISTINCT ca.customer_id))::NUMERIC, 2)
        ELSE 0
    END AS cost_per_acquisition
FROM crm.customer_acquisition ca
WHERE ca.acquisition_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ca.acquisition_date), ca.acquisition_channel
ORDER BY acquisition_date DESC;

-- ------------------------------------------------------------
-- Report 3: Customer Segmentation (Monthly, Critical)
-- Customers by segment/group
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_segmentation AS
SELECT
    cg.group_code,
    cg.group_name,
    cg.group_type,
    COUNT(DISTINCT cgm.customer_id) AS member_count,
    COUNT(DISTINCT CASE WHEN cgm.is_active = TRUE THEN cgm.customer_id END) AS active_members,
    AVG(cas.total_order_amount) AS avg_order_amount,
    SUM(cas.total_order_amount) AS total_revenue
FROM crm.customer_groups cg
LEFT JOIN crm.customer_group_members cgm ON cgm.customer_group_id = cg.customer_group_id
LEFT JOIN crm.customer_account_summary cas ON cas.customer_id = cgm.customer_id
GROUP BY cg.customer_group_id, cg.group_code, cg.group_name, cg.group_type
ORDER BY member_count DESC;

-- ------------------------------------------------------------
-- Report 4: Customer Lifetime Value (Monthly, Critical)
-- CLV by customer segment
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_lifetime_value AS
SELECT
    c.customer_id,
    c.customer_number,
    c.display_name,
    ctl.code AS customer_type,
    csl.code AS customer_status,
    c.is_vip,
    COALESCE(cas.total_orders, 0) AS total_orders,
    COALESCE(cas.total_order_amount, 0) AS total_revenue,
    COALESCE(cas.customer_lifetime_value, 0) AS lifetime_value,
    COALESCE(cas.average_order_amount, 0) AS avg_order_amount,
    c.created_at AS customer_since,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.created_at::DATE)) AS years_as_customer
FROM crm.customers c
JOIN crm.customer_type_lookup ctl ON ctl.customer_type_id = c.customer_type_id
JOIN crm.customer_status_lookup csl ON csl.customer_status_id = c.customer_status_id
LEFT JOIN crm.customer_account_summary cas ON cas.customer_id = c.customer_id
WHERE c.is_active = TRUE
ORDER BY lifetime_value DESC
LIMIT 100;

-- ------------------------------------------------------------
-- Report 5: Customer Growth (Monthly, Critical)
-- Customer growth trends
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_growth AS
SELECT
    DATE_TRUNC('month', c.created_at) AS growth_month,
    COUNT(DISTINCT c.customer_id) AS new_customers,
    COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.customer_id END) AS active_customers,
    COUNT(DISTINCT CASE WHEN c.is_vip = TRUE THEN c.customer_id END) AS vip_customers
FROM crm.customers c
WHERE c.created_at >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('month', c.created_at)
ORDER BY growth_month DESC;

-- ------------------------------------------------------------
-- Report 6: Customer Activity (Daily, Important)
-- Recent customer activities
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_activity AS
SELECT
    c.customer_number,
    c.display_name,
    ci.interaction_subject,
    ci.interaction_channel,
    ci.interaction_date,
    ci.direction,
    ci.notes
FROM crm.customer_interactions ci
JOIN crm.customers c ON c.customer_id = ci.customer_id
WHERE ci.interaction_date >= CURRENT_TIMESTAMP - INTERVAL '7 days'
ORDER BY ci.interaction_date DESC;

-- ------------------------------------------------------------
-- Report 7: Customer Documents (Weekly, Important)
-- Document verification status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_documents AS
SELECT
    c.customer_number,
    c.display_name,
    cd.document_title,
    cd.document_number,
    cd.document_type_id,
    cd.is_verified,
    cd.is_current,
    cd.issue_date,
    cd.expiry_date,
    CASE
        WHEN cd.expiry_date IS NOT NULL AND cd.expiry_date < CURRENT_DATE THEN 'EXPIRED'
        WHEN cd.expiry_date IS NOT NULL AND cd.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING_SOON'
        ELSE 'VALID'
    END AS document_status
FROM crm.customer_documents cd
JOIN crm.customers c ON c.customer_id = cd.customer_id
WHERE cd.is_active = TRUE
ORDER BY cd.expiry_date ASC NULLS LAST;

-- ------------------------------------------------------------
-- Report 8: Customer Notes (On-demand, Important)
-- Recent notes by customer
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_notes AS
SELECT
    c.customer_number,
    c.display_name,
    cn.note_type,
    cn.note_text,
    cn.is_internal,
    cn.created_at,
    u.username AS created_by
FROM crm.customer_notes cn
JOIN crm.customers c ON c.customer_id = cn.customer_id
LEFT JOIN identity.users u ON u.user_id = cn.created_by_user_id
ORDER BY cn.created_at DESC
LIMIT 100;

-- ------------------------------------------------------------
-- Report 9: Customer Tags (Monthly, Important)
-- Tag distribution
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_tags AS
SELECT
    ct.tag_name,
    ct.tag_color,
    COUNT(DISTINCT cta.customer_id) AS tagged_customers,
    COUNT(DISTINCT CASE WHEN cta.is_active = TRUE THEN cta.customer_id END) AS active_tagged_customers
FROM crm.customer_tags ct
LEFT JOIN crm.customer_tag_assignments cta ON cta.customer_tag_id = ct.customer_tag_id
GROUP BY ct.customer_tag_id, ct.tag_name, ct.tag_color
ORDER BY tagged_customers DESC;

-- ------------------------------------------------------------
-- Report 10: Customer Interactions (Daily, Important)
-- Interaction history
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_interactions AS
SELECT
    DATE(ci.interaction_date) AS interaction_date,
    ci.interaction_channel,
    ci.direction,
    COUNT(DISTINCT ci.customer_interaction_id) AS interaction_count,
    COUNT(DISTINCT ci.customer_id) AS unique_customers
FROM crm.customer_interactions ci
WHERE ci.interaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(ci.interaction_date), ci.interaction_channel, ci.direction
ORDER BY interaction_date DESC;

-- ------------------------------------------------------------
-- Report 11: Customer Service Cases (Daily, Critical)
-- Open/closed cases
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_service_cases AS
SELECT
    csc.case_number,
    csc.case_subject,
    c.customer_number,
    c.display_name,
    csc.case_status_id,
    csc.case_priority_id,
    csc.created_at,
    csc.resolved_at,
    csc.satisfaction_rating,
    u.username AS assigned_to,
    CASE
        WHEN csc.resolved_at IS NOT NULL THEN 'RESOLVED'
        ELSE 'OPEN'
    END AS case_status
FROM crm.customer_service_cases csc
JOIN crm.customers c ON c.customer_id = csc.customer_id
LEFT JOIN identity.users u ON u.user_id = csc.assigned_to_user_id
ORDER BY csc.created_at DESC;

-- ------------------------------------------------------------
-- Report 12: Customer Tasks (Daily, Important)
-- Pending/completed tasks
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_tasks AS
SELECT
    ct.task_subject,
    c.customer_number,
    c.display_name,
    ct.task_status_id,
    ct.due_date,
    ct.completed_at,
    u.username AS assigned_to,
    CASE
        WHEN ct.completed_at IS NOT NULL THEN 'COMPLETED'
        WHEN ct.due_date IS NOT NULL AND ct.due_date < CURRENT_TIMESTAMP THEN 'OVERDUE'
        ELSE 'PENDING'
    END AS task_status
FROM crm.customer_tasks ct
JOIN crm.customers c ON c.customer_id = ct.customer_id
LEFT JOIN identity.users u ON u.user_id = ct.assigned_to_user_id
ORDER BY ct.due_date ASC NULLS LAST;

-- ------------------------------------------------------------
-- Report 13: Customer Scoring (Monthly, Important)
-- Customer scores by segment
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_scoring AS
SELECT
    c.customer_number,
    c.display_name,
    c.is_vip,
    cs.score,
    cs.score_date,
    cs.score_type_id,
    CASE
        WHEN cs.score >= 80 THEN 'HIGH'
        WHEN cs.score >= 50 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS score_level
FROM crm.customer_scores cs
JOIN crm.customers c ON c.customer_id = cs.customer_id
WHERE cs.score_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY cs.score DESC;

-- ------------------------------------------------------------
-- Report 14: Customer Preferences (Monthly, Important)
-- Preference distribution
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_preferences AS
SELECT
    cp.accepts_email,
    cp.accepts_sms,
    cp.accepts_phone,
    cp.accepts_marketing,
    COUNT(DISTINCT cp.customer_id) AS customer_count
FROM crm.customer_preferences cp
GROUP BY cp.accepts_email, cp.accepts_sms, cp.accepts_phone, cp.accepts_marketing
ORDER BY customer_count DESC;

-- ------------------------------------------------------------
-- Report 15: Customer Acquisition Source (Monthly, Critical)
-- Acquisition channel performance
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_acquisition_source AS
SELECT
    ca.acquisition_channel,
    COUNT(DISTINCT ca.customer_id) AS total_customers,
    SUM(ca.acquisition_cost) AS total_cost,
    CASE
        WHEN COUNT(DISTINCT ca.customer_id) > 0
        THEN ROUND((SUM(ca.acquisition_cost) / COUNT(DISTINCT ca.customer_id))::NUMERIC, 2)
        ELSE 0
    END AS cost_per_customer,
    COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN ca.customer_id END) AS active_customers
FROM crm.customer_acquisition ca
LEFT JOIN crm.customers c ON c.customer_id = ca.customer_id
GROUP BY ca.acquisition_channel
ORDER BY total_customers DESC;

-- ------------------------------------------------------------
-- Report 16: Customer Relationships (Monthly, Important)
-- Relationship mapping
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_relationships AS
SELECT
    c1.customer_number AS customer_number,
    c1.display_name AS customer_name,
    c2.customer_number AS related_customer_number,
    c2.display_name AS related_customer_name,
    cr.relationship_direction,
    cr.relationship_notes,
    cr.is_active
FROM crm.customer_relationships cr
JOIN crm.customers c1 ON c1.customer_id = cr.customer_id
JOIN crm.customers c2 ON c2.customer_id = cr.related_customer_id
ORDER BY cr.created_at DESC;

-- ------------------------------------------------------------
-- Report 17: Customer Commercial Profiles (Monthly, Important)
-- Credit profiles
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_commercial_profiles AS
SELECT
    c.customer_number,
    c.display_name,
    ccp.credit_limit,
    ccp.available_credit,
    ccp.payment_terms_days,
    ccp.total_orders,
    ccp.total_order_amount,
    ccp.outstanding_balance,
    ccp.last_order_date,
    ccs.code AS credit_status,
    ccl.code AS credit_risk_level
FROM crm.customer_commercial_profiles ccp
JOIN crm.customers c ON c.customer_id = ccp.customer_id
LEFT JOIN crm.customer_credit_status_lookup ccs ON ccs.customer_credit_status_id = ccp.credit_status_id
LEFT JOIN crm.customer_credit_risk_level_lookup ccl ON ccl.customer_credit_risk_level_id = ccp.credit_risk_level_id
ORDER BY ccp.total_order_amount DESC;

-- ------------------------------------------------------------
-- Report 18: Customer Credit (Monthly, Critical)
-- Credit status and risk
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_credit AS
SELECT
    ccs.code AS credit_status,
    ccl.code AS credit_risk_level,
    COUNT(DISTINCT ccp.customer_id) AS customer_count,
    SUM(ccp.credit_limit) AS total_credit_limit,
    SUM(ccp.available_credit) AS total_available_credit,
    SUM(ccp.outstanding_balance) AS total_outstanding
FROM crm.customer_commercial_profiles ccp
LEFT JOIN crm.customer_credit_status_lookup ccs ON ccs.customer_credit_status_id = ccp.credit_status_id
LEFT JOIN crm.customer_credit_risk_level_lookup ccl ON ccl.customer_credit_risk_level_id = ccp.credit_risk_level_id
GROUP BY ccs.code, ccl.code
ORDER BY total_outstanding DESC;

-- ------------------------------------------------------------
-- Report 19: Customer Referrals (Monthly, Important)
-- Referral performance
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_referrals AS
SELECT
    c1.customer_number AS referrer_number,
    c1.display_name AS referrer_name,
    COUNT(DISTINCT cr.customer_referral_id) AS total_referrals,
    COUNT(DISTINCT CASE WHEN cr.is_converted = TRUE THEN cr.customer_referral_id END) AS converted_referrals,
    SUM(cr.reward_amount) AS total_rewards,
    COUNT(DISTINCT CASE WHEN cr.reward_paid = TRUE THEN cr.customer_referral_id END) AS rewards_paid
FROM crm.customer_referrals cr
JOIN crm.customers c1 ON c1.customer_id = cr.referrer_customer_id
GROUP BY c1.customer_id, c1.customer_number, c1.display_name
ORDER BY converted_referrals DESC
LIMIT 50;

-- ------------------------------------------------------------
-- Report 20: Customer Groups (Monthly, Important)
-- Group membership
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_groups AS
SELECT
    cg.group_code,
    cg.group_name,
    cg.group_type,
    cg.is_active,
    COUNT(DISTINCT cgm.customer_id) AS member_count,
    COUNT(DISTINCT CASE WHEN cgm.is_active = TRUE THEN cgm.customer_id END) AS active_members,
    cg.created_at
FROM crm.customer_groups cg
LEFT JOIN crm.customer_group_members cgm ON cgm.customer_group_id = cg.customer_group_id
GROUP BY cg.customer_group_id, cg.group_code, cg.group_name, cg.group_type, cg.is_active, cg.created_at
ORDER BY member_count DESC;

-- ------------------------------------------------------------
-- Report 21: Customer Account Summary (Daily, Critical)
-- Aggregated account data
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_account_summary AS
SELECT
    c.customer_number,
    c.display_name,
    cas.total_orders,
    cas.total_order_amount,
    cas.total_paid_amount,
    cas.outstanding_balance,
    cas.first_order_date,
    cas.last_order_date,
    cas.average_order_amount,
    cas.total_interactions,
    cas.total_service_cases,
    cas.customer_lifetime_value,
    cas.customer_segment,
    cas.churn_risk_score,
    cas.last_calculated_at
FROM crm.customer_account_summary cas
JOIN crm.customers c ON c.customer_id = cas.customer_id
ORDER BY cas.total_order_amount DESC;

-- ------------------------------------------------------------
-- Report 22: Customer Analytics (Monthly, Critical)
-- Customer analytics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_analytics AS
SELECT
    DATE_TRUNC('month', c.created_at) AS analytics_month,
    COUNT(DISTINCT c.customer_id) AS new_customers,
    COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.customer_id END) AS active_customers,
    COUNT(DISTINCT CASE WHEN c.is_vip = TRUE THEN c.customer_id END) AS vip_customers,
    AVG(cas.total_order_amount) AS avg_order_amount,
    AVG(cas.customer_lifetime_value) AS avg_lifetime_value
FROM crm.customers c
LEFT JOIN crm.customer_account_summary cas ON cas.customer_id = c.customer_id
WHERE c.created_at >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('month', c.created_at)
ORDER BY analytics_month DESC;

-- ------------------------------------------------------------
-- Report 23: Customer Churn (Monthly, Critical)
-- Churn analysis
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_churn AS
SELECT
    DATE_TRUNC('month', c.created_at) AS cohort_month,
    COUNT(DISTINCT c.customer_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.customer_id END) AS active_customers,
    COUNT(DISTINCT CASE WHEN c.is_active = FALSE THEN c.customer_id END) AS churned_customers,
    CASE
        WHEN COUNT(DISTINCT c.customer_id) > 0
        THEN ROUND((COUNT(DISTINCT CASE WHEN c.is_active = FALSE THEN c.customer_id END)::NUMERIC / COUNT(DISTINCT c.customer_id) * 100), 2)
        ELSE 0
    END AS churn_rate_percent
FROM crm.customers c
WHERE c.created_at >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('month', c.created_at)
ORDER BY cohort_month DESC;

-- ------------------------------------------------------------
-- Report 24: Customer Retention (Monthly, Critical)
-- Retention analysis
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_customer_retention AS
SELECT
    DATE_TRUNC('month', c.created_at) AS cohort_month,
    COUNT(DISTINCT c.customer_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.customer_id END) AS retained_customers,
    CASE
        WHEN COUNT(DISTINCT c.customer_id) > 0
        THEN ROUND((COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.customer_id END)::NUMERIC / COUNT(DISTINCT c.customer_id) * 100), 2)
        ELSE 0
    END AS retention_rate_percent
FROM crm.customers c
WHERE c.created_at >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('month', c.created_at)
ORDER BY cohort_month DESC;

-- ------------------------------------------------------------
-- Report 25: CRM Health Dashboard (Daily, Critical)
-- CRM health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_crm_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT customer_id) FROM crm.customers WHERE is_active = TRUE) AS active_customers,
    (SELECT COUNT(DISTINCT customer_id) FROM crm.customers WHERE is_vip = TRUE) AS vip_customers,
    (SELECT COUNT(DISTINCT customer_id) FROM crm.customers WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS new_customers_7d,
    (SELECT COUNT(DISTINCT customer_id) FROM crm.customers WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days') AS new_customers_30d,
    (SELECT COUNT(DISTINCT customer_id) FROM crm.customer_group_members WHERE is_active = TRUE) AS group_members,
    (SELECT COUNT(DISTINCT customer_interaction_id) FROM crm.customer_interactions WHERE interaction_date >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS interactions_7d,
    (SELECT COUNT(DISTINCT customer_service_case_id) FROM crm.customer_service_cases WHERE resolved_at IS NULL) AS open_service_cases,
    (SELECT COUNT(DISTINCT customer_task_id) FROM crm.customer_tasks WHERE completed_at IS NULL AND due_date < CURRENT_TIMESTAMP) AS overdue_tasks,
    (SELECT COUNT(DISTINCT customer_tag_id) FROM crm.customer_tags WHERE is_active = TRUE) AS active_tags,
    (SELECT COUNT(DISTINCT customer_document_id) FROM crm.customer_documents WHERE is_verified = FALSE AND is_active = TRUE) AS unverified_documents;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Customer Summary
CREATE OR REPLACE FUNCTION reports.fn_get_customer_summary(
    p_customer_id UUID
)
RETURNS TABLE (
    customer_number VARCHAR,
    display_name VARCHAR,
    customer_type VARCHAR,
    customer_status VARCHAR,
    total_orders BIGINT,
    total_revenue NUMERIC,
    outstanding_balance NUMERIC,
    lifetime_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.customer_number::VARCHAR,
        c.display_name::VARCHAR,
        ctl.code::VARCHAR,
        csl.code::VARCHAR,
        COALESCE(cas.total_orders, 0)::BIGINT,
        COALESCE(cas.total_order_amount, 0),
        COALESCE(cas.outstanding_balance, 0),
        COALESCE(cas.customer_lifetime_value, 0)
    FROM crm.customers c
    JOIN crm.customer_type_lookup ctl ON ctl.customer_type_id = c.customer_type_id
    JOIN crm.customer_status_lookup csl ON csl.customer_status_id = c.customer_status_id
    LEFT JOIN crm.customer_account_summary cas ON cas.customer_id = c.customer_id
    WHERE c.customer_id = p_customer_id;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Customer by Email
CREATE OR REPLACE FUNCTION reports.fn_get_customer_by_email(
    p_email VARCHAR
)
RETURNS TABLE (
    customer_id UUID,
    customer_number VARCHAR,
    display_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    customer_type VARCHAR,
    customer_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.customer_id,
        c.customer_number::VARCHAR,
        c.display_name::VARCHAR,
        c.email::VARCHAR,
        c.phone::VARCHAR,
        ctl.code::VARCHAR,
        csl.code::VARCHAR
    FROM crm.customers c
    JOIN crm.customer_type_lookup ctl ON ctl.customer_type_id = c.customer_type_id
    JOIN crm.customer_status_lookup csl ON csl.customer_status_id = c.customer_status_id
    WHERE LOWER(c.email) = LOWER(p_email)
      AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Customer Orders
CREATE OR REPLACE FUNCTION reports.fn_get_customer_orders(
    p_customer_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    order_id UUID,
    order_number VARCHAR,
    order_date DATE,
    grand_total NUMERIC,
    order_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.order_id,
        o.order_number::VARCHAR,
        o.order_date,
        o.grand_total,
        osl.code::VARCHAR
    FROM sales.orders o
    JOIN sales.order_status_lookup osl ON osl.order_status_id = o.order_status_id
    WHERE o.customer_id = p_customer_id
    ORDER BY o.order_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Customer Interactions
CREATE OR REPLACE FUNCTION reports.fn_get_customer_interactions(
    p_customer_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    interaction_subject VARCHAR,
    interaction_channel VARCHAR,
    interaction_date TIMESTAMPTZ,
    direction VARCHAR,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ci.interaction_subject::VARCHAR,
        ci.interaction_channel::VARCHAR,
        ci.interaction_date,
        ci.direction::VARCHAR,
        ci.notes
    FROM crm.customer_interactions ci
    WHERE ci.customer_id = p_customer_id
    ORDER BY ci.interaction_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Customer Service Cases
CREATE OR REPLACE FUNCTION reports.fn_get_customer_service_cases(
    p_customer_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    case_number VARCHAR,
    case_subject VARCHAR,
    case_status VARCHAR,
    created_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    satisfaction_rating INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        csc.case_number::VARCHAR,
        csc.case_subject::VARCHAR,
        csc.case_status_id::VARCHAR,
        csc.created_at,
        csc.resolved_at,
        csc.satisfaction_rating
    FROM crm.customer_service_cases csc
    WHERE csc.customer_id = p_customer_id
    ORDER BY csc.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 03 CRM
-- 25 Views + 5 Functions = 30 Report Objects
-- 25 Reports as per reports01.html catalog
-- ============================================================