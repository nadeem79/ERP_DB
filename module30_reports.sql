BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 30 — SUBSCRIPTIONS, RECURRING BILLING & MEMBERSHIPS
-- 20 Views + 2 Functions
-- ============================================================

CREATE OR REPLACE VIEW reports.vw_subscription_summary AS
SELECT
    DATE(s.created_at) AS created_date,
    ssl.code AS subscription_status,
    sp.plan_name,
    COUNT(DISTINCT s.subscription_id) AS subscription_count,
    COUNT(DISTINCT s.customer_id) AS customer_count,
    SUM(s.total_amount) AS total_subscription_value,
    SUM(s.total_paid) AS total_paid,
    SUM(s.outstanding_amount) AS total_outstanding,
    AVG(s.billing_cycle_count) AS avg_billing_cycles
FROM subscriptions.subscriptions s
JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
GROUP BY DATE(s.created_at), ssl.code, sp.plan_name
ORDER BY created_date DESC;

CREATE OR REPLACE VIEW reports.vw_subscription_status_distribution AS
SELECT
    ssl.code AS status_code,
    ssl.name AS status_name,
    COUNT(DISTINCT s.subscription_id) AS subscription_count,
    SUM(s.total_amount) AS total_value,
    SUM(s.total_paid) AS total_paid,
    ROUND(COUNT(DISTINCT s.subscription_id)::NUMERIC / NULLIF(SUM(COUNT(DISTINCT s.subscription_id)) OVER (), 0) * 100, 2) AS percent_of_total
FROM subscriptions.subscription_status_lookup ssl
LEFT JOIN subscriptions.subscriptions s ON s.subscription_status_id = ssl.subscription_status_id
GROUP BY ssl.subscription_status_id, ssl.code, ssl.name, ssl.sort_order
ORDER BY ssl.sort_order;

CREATE OR REPLACE VIEW reports.vw_plan_performance AS
SELECT
    sp.plan_code,
    sp.plan_name,
    sp.base_price,
    sp.trial_days,
    bf.code AS billing_frequency,
    COUNT(DISTINCT s.subscription_id) AS total_subscriptions,
    COUNT(DISTINCT CASE WHEN ssl.code = 'ACTIVE' THEN s.subscription_id END) AS active_subscriptions,
    COUNT(DISTINCT CASE WHEN ssl.code = 'TRIAL' THEN s.subscription_id END) AS trial_subscriptions,
    COUNT(DISTINCT CASE WHEN ssl.code = 'CANCELLED' THEN s.subscription_id END) AS cancelled_subscriptions,
    SUM(s.total_paid) AS total_revenue,
    ROUND(COUNT(DISTINCT CASE WHEN ssl.code = 'ACTIVE' THEN s.subscription_id END)::NUMERIC /
          NULLIF(COUNT(DISTINCT s.subscription_id), 0) * 100, 2) AS active_rate_percent
FROM subscriptions.subscription_plans sp
JOIN subscriptions.billing_frequency_lookup bf ON bf.billing_frequency_id = sp.billing_frequency_id
LEFT JOIN subscriptions.subscriptions s ON s.subscription_plan_id = sp.subscription_plan_id
LEFT JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
GROUP BY sp.subscription_plan_id, sp.plan_code, sp.plan_name, sp.base_price, sp.trial_days, bf.code
ORDER BY total_subscriptions DESC NULLS LAST;

CREATE OR REPLACE VIEW reports.vw_billing_cycle_report AS
SELECT
    s.subscription_number,
    sp.plan_name,
    bc.cycle_number,
    bc.period_start,
    bc.period_end,
    bc.amount_due,
    bc.amount_paid,
    bcs.code AS cycle_status,
    bc.is_trial,
    bc.is_prorated,
    bc.due_date,
    bc.paid_at,
    bc.failed_at
FROM subscriptions.billing_cycles bc
JOIN subscriptions.subscriptions s ON s.subscription_id = bc.subscription_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
JOIN subscriptions.billing_cycle_status_lookup bcs ON bcs.billing_cycle_status_id = bc.billing_cycle_status_id
ORDER BY bc.due_date DESC NULLS LAST;

CREATE OR REPLACE VIEW reports.vw_revenue_recognition AS
SELECT
    DATE_TRUNC('month', bc.paid_at) AS revenue_month,
    sp.plan_name,
    bf.code AS billing_frequency,
    COUNT(DISTINCT bc.billing_cycle_id) AS paid_cycles,
    SUM(bc.amount_paid) AS recognized_revenue,
    COUNT(DISTINCT s.customer_id) AS paying_customers
FROM subscriptions.billing_cycles bc
JOIN subscriptions.subscriptions s ON s.subscription_id = bc.subscription_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
JOIN subscriptions.billing_frequency_lookup bf ON bf.billing_frequency_id = sp.billing_frequency_id
JOIN subscriptions.billing_cycle_status_lookup bcs ON bcs.billing_cycle_status_id = bc.billing_cycle_status_id
WHERE bcs.code = 'PAID' AND bc.paid_at IS NOT NULL
GROUP BY DATE_TRUNC('month', bc.paid_at), sp.plan_name, bf.code
ORDER BY revenue_month DESC;

CREATE OR REPLACE VIEW reports.vw_failed_payment_report AS
SELECT
    s.subscription_number,
    sp.plan_name,
    c.display_name AS customer_name,
    bc.cycle_number,
    bc.amount_due,
    bc.failed_at,
    ds.current_retry_number,
    ds.max_retries,
    ds.next_retry_at,
    dsl.code AS dunning_status,
    bc.amount_due - bc.amount_paid AS outstanding_amount
FROM subscriptions.billing_cycles bc
JOIN subscriptions.subscriptions s ON s.subscription_id = bc.subscription_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
JOIN crm.customers c ON c.customer_id = s.customer_id
JOIN subscriptions.billing_cycle_status_lookup bcs ON bcs.billing_cycle_status_id = bc.billing_cycle_status_id
LEFT JOIN subscriptions.dunning_schedules ds ON ds.billing_cycle_id = bc.billing_cycle_id
LEFT JOIN subscriptions.dunning_status_lookup dsl ON dsl.dunning_status_id = ds.dunning_status_id
WHERE bcs.code IN ('FAILED', 'OVERDUE')
ORDER BY bc.failed_at DESC NULLS LAST;

CREATE OR REPLACE VIEW reports.vw_dunning_performance AS
SELECT
    dsl.code AS dunning_status,
    dsl.name AS status_name,
    COUNT(DISTINCT ds.dunning_schedule_id) AS schedule_count,
    COUNT(DISTINCT da.dunning_attempt_id) AS total_attempts,
    COUNT(DISTINCT CASE WHEN da.status = 'SUCCESS' THEN da.dunning_attempt_id END) AS successful_attempts,
    ROUND(COUNT(DISTINCT CASE WHEN da.status = 'SUCCESS' THEN da.dunning_attempt_id END)::NUMERIC /
          NULLIF(COUNT(DISTINCT da.dunning_attempt_id), 0) * 100, 2) AS recovery_rate_percent
FROM subscriptions.dunning_status_lookup dsl
LEFT JOIN subscriptions.dunning_schedules ds ON ds.dunning_status_id = dsl.dunning_status_id
LEFT JOIN subscriptions.dunning_attempts da ON da.dunning_schedule_id = ds.dunning_schedule_id
GROUP BY dsl.dunning_status_id, dsl.code, dsl.name, dsl.sort_order
ORDER BY dsl.sort_order;

CREATE OR REPLACE VIEW reports.vw_subscription_changes_report AS
SELECT
    s.subscription_number,
    sp_from.plan_name AS from_plan,
    sp_to.plan_name AS to_plan,
    sct.code AS change_type,
    sc.from_quantity,
    sc.to_quantity,
    sc.proration_credit,
    sc.proration_charge,
    sc.effective_date,
    sc.effective_immediately,
    sc.created_at
FROM subscriptions.subscription_changes sc
JOIN subscriptions.subscriptions s ON s.subscription_id = sc.subscription_id
JOIN subscriptions.subscription_change_type_lookup sct ON sct.subscription_change_type_id = sc.subscription_change_type_id
LEFT JOIN subscriptions.subscription_plans sp_from ON sp_from.subscription_plan_id = sc.from_plan_id
LEFT JOIN subscriptions.subscription_plans sp_to ON sp_to.subscription_plan_id = sc.to_plan_id
ORDER BY sc.created_at DESC;

CREATE OR REPLACE VIEW reports.vw_trial_conversion_report AS
SELECT
    DATE(s.created_at) AS trial_start_date,
    sp.plan_name,
    sp.trial_days,
    COUNT(DISTINCT s.subscription_id) AS trials_started,
    COUNT(DISTINCT CASE WHEN ssl.code IN ('ACTIVE', 'TRIAL') THEN s.subscription_id END) AS still_in_trial_or_active,
    COUNT(DISTINCT CASE WHEN ssl.code = 'ACTIVE' AND s.trial_end_date IS NOT NULL THEN s.subscription_id END) AS converted_from_trial,
    COUNT(DISTINCT CASE WHEN ssl.code = 'CANCELLED' AND s.trial_end_date IS NOT NULL THEN s.subscription_id END) AS cancelled_after_trial,
    ROUND(COUNT(DISTINCT CASE WHEN ssl.code = 'ACTIVE' AND s.trial_end_date IS NOT NULL THEN s.subscription_id END)::NUMERIC /
          NULLIF(COUNT(DISTINCT s.subscription_id), 0) * 100, 2) AS conversion_rate_percent
FROM subscriptions.subscriptions s
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
WHERE sp.trial_days > 0
GROUP BY DATE(s.created_at), sp.plan_name, sp.trial_days
ORDER BY trial_start_date DESC;

CREATE OR REPLACE VIEW reports.vw_churn_report AS
SELECT
    DATE(sc.effective_at) AS cancellation_date,
    sp.plan_name,
    sc.cancellation_reason,
    sc.cancel_immediately,
    COUNT(DISTINCT sc.subscription_cancellation_id) AS cancellation_count,
    SUM(s.total_paid) AS lost_revenue
FROM subscriptions.subscription_cancellations sc
JOIN subscriptions.subscriptions s ON s.subscription_id = sc.subscription_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
GROUP BY DATE(sc.effective_at), sp.plan_name, sc.cancellation_reason, sc.cancel_immediately
ORDER BY cancellation_date DESC NULLS LAST;

CREATE OR REPLACE VIEW reports.vw_membership_report AS
SELECT
    mt.code AS tier_code,
    mt.name AS tier_name,
    COUNT(DISTINCT cm.customer_membership_id) AS membership_count,
    COUNT(DISTINCT CASE WHEN cm.is_active = TRUE THEN cm.customer_membership_id END) AS active_memberships,
    COUNT(DISTINCT cm.customer_id) AS unique_customers,
    COUNT(DISTINCT cm.subscription_id) AS subscription_linked
FROM subscriptions.membership_tier_lookup mt
LEFT JOIN subscriptions.customer_memberships cm ON cm.membership_tier_id = mt.membership_tier_id
GROUP BY mt.membership_tier_id, mt.code, mt.name, mt.sort_order
ORDER BY mt.sort_order;

CREATE OR REPLACE VIEW reports.vw_entitlement_usage AS
SELECT
    mt.name AS tier_name,
    et.name AS entitlement_type,
    mte.entitlement_code,
    mte.entitlement_name,
    mte.entitlement_value,
    mte.entitlement_value_numeric,
    COUNT(DISTINCT ce.customer_entitlement_id) AS granted_count,
    COUNT(DISTINCT CASE WHEN ce.is_active = TRUE THEN ce.customer_entitlement_id END) AS active_grants
FROM subscriptions.membership_tier_entitlements mte
JOIN subscriptions.membership_tier_lookup mt ON mt.membership_tier_id = mte.membership_tier_id
JOIN subscriptions.entitlement_type_lookup et ON et.entitlement_type_id = mte.entitlement_type_id
LEFT JOIN subscriptions.customer_memberships cm ON cm.membership_tier_id = mt.membership_tier_id AND cm.is_active = TRUE
LEFT JOIN subscriptions.customer_entitlements ce ON ce.customer_membership_id = cm.customer_membership_id AND ce.entitlement_code = mte.entitlement_code
GROUP BY mt.name, et.name, mte.entitlement_code, mte.entitlement_name, mte.entitlement_value, mte.entitlement_value_numeric
ORDER BY mt.name, et.name;

CREATE OR REPLACE VIEW reports.vw_subscription_events_report AS
SELECT
    DATE(se.occurred_at) AS event_date,
    se.event_type,
    COUNT(DISTINCT se.subscription_event_id) AS event_count,
    COUNT(DISTINCT se.subscription_id) AS subscriptions_affected
FROM subscriptions.subscription_events se
GROUP BY DATE(se.occurred_at), se.event_type
ORDER BY event_date DESC, event_count DESC;

CREATE OR REPLACE VIEW reports.vw_mrr_report AS
SELECT
    DATE_TRUNC('month', bc.paid_at) AS month,
    SUM(bc.amount_paid) AS monthly_recurring_revenue,
    COUNT(DISTINCT s.subscription_id) AS active_paying_subscriptions,
    COUNT(DISTINCT s.customer_id) AS paying_customers,
    ROUND(SUM(bc.amount_paid) / NULLIF(COUNT(DISTINCT s.subscription_id), 0), 2) AS avg_revenue_per_subscription
FROM subscriptions.billing_cycles bc
JOIN subscriptions.subscriptions s ON s.subscription_id = bc.subscription_id
JOIN subscriptions.billing_cycle_status_lookup bcs ON bcs.billing_cycle_status_id = bc.billing_cycle_status_id
WHERE bcs.code = 'PAID' AND bc.paid_at IS NOT NULL
GROUP BY DATE_TRUNC('month', bc.paid_at)
ORDER BY month DESC;

CREATE OR REPLACE VIEW reports.vw_subscription_health_dashboard AS
SELECT 'Total Subscriptions' AS metric, COUNT(DISTINCT subscription_id)::TEXT AS value FROM subscriptions.subscriptions
UNION ALL
SELECT 'Active Subscriptions', COUNT(DISTINCT s.subscription_id)::TEXT
FROM subscriptions.subscriptions s JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id WHERE ssl.code = 'ACTIVE'
UNION ALL
SELECT 'Trial Subscriptions', COUNT(DISTINCT s.subscription_id)::TEXT
FROM subscriptions.subscriptions s JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id WHERE ssl.code = 'TRIAL'
UNION ALL
SELECT 'Past Due Subscriptions', COUNT(DISTINCT s.subscription_id)::TEXT
FROM subscriptions.subscriptions s JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id WHERE ssl.code = 'PAST_DUE'
UNION ALL
SELECT 'Cancelled Subscriptions', COUNT(DISTINCT s.subscription_id)::TEXT
FROM subscriptions.subscriptions s JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id WHERE ssl.code = 'CANCELLED'
UNION ALL
SELECT 'Total Revenue Collected', ROUND(SUM(total_paid), 2)::TEXT FROM subscriptions.subscriptions
UNION ALL
SELECT 'Outstanding Amount', ROUND(SUM(outstanding_amount), 2)::TEXT FROM subscriptions.subscriptions
UNION ALL
SELECT 'Failed Billing Cycles', COUNT(DISTINCT bc.billing_cycle_id)::TEXT
FROM subscriptions.billing_cycles bc JOIN subscriptions.billing_cycle_status_lookup bcs ON bcs.billing_cycle_status_id = bc.billing_cycle_status_id WHERE bcs.code IN ('FAILED', 'OVERDUE')
UNION ALL
SELECT 'Active Memberships', COUNT(DISTINCT customer_membership_id)::TEXT FROM subscriptions.customer_memberships WHERE is_active = TRUE
UNION ALL
SELECT 'Active Dunning Schedules', COUNT(DISTINCT dunning_schedule_id)::TEXT FROM subscriptions.dunning_schedules WHERE is_resolved = FALSE;

CREATE OR REPLACE VIEW reports.vw_usage_billing_report AS
SELECT
    s.subscription_number,
    sp.plan_name,
    ur.usage_type,
    ur.usage_date,
    SUM(ur.usage_quantity) AS total_usage,
    ur.usage_unit,
    COUNT(DISTINCT CASE WHEN ur.is_billed = TRUE THEN ur.usage_record_id END) AS billed_records,
    COUNT(DISTINCT CASE WHEN ur.is_billed = FALSE THEN ur.usage_record_id END) AS unbilled_records
FROM subscriptions.usage_records ur
JOIN subscriptions.subscriptions s ON s.subscription_id = ur.subscription_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
GROUP BY s.subscription_number, sp.plan_name, ur.usage_type, ur.usage_date, ur.usage_unit
ORDER BY ur.usage_date DESC;

CREATE OR REPLACE VIEW reports.vw_pause_report AS
SELECT
    s.subscription_number,
    sp.plan_name,
    c.display_name AS customer_name,
    sup.pause_reason,
    sup.pause_start_date,
    sup.pause_end_date,
    sup.resumed_at,
    CASE WHEN sup.resumed_at IS NULL THEN 'CURRENTLY_PAUSED' ELSE 'RESUMED' END AS pause_status
FROM subscriptions.subscription_pauses sup
JOIN subscriptions.subscriptions s ON s.subscription_id = sup.subscription_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
JOIN crm.customers c ON c.customer_id = s.customer_id
ORDER BY sup.pause_start_date DESC;

CREATE OR REPLACE VIEW reports.vw_subscription_renewal_forecast AS
SELECT
    s.next_billing_date,
    COUNT(DISTINCT s.subscription_id) AS renewals_due,
    SUM(s.total_amount) AS expected_revenue,
    COUNT(DISTINCT s.customer_id) AS customers_renewing
FROM subscriptions.subscriptions s
JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
WHERE ssl.code IN ('ACTIVE', 'TRIAL')
  AND s.auto_renew = TRUE
  AND s.next_billing_date IS NOT NULL
  AND s.next_billing_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
GROUP BY s.next_billing_date
ORDER BY s.next_billing_date;

CREATE OR REPLACE VIEW reports.vw_customer_subscription_history AS
SELECT
    c.customer_number,
    c.display_name,
    s.subscription_number,
    sp.plan_name,
    ssl.code AS status,
    s.start_date,
    s.current_period_end,
    s.total_paid,
    s.billing_cycle_count,
    s.failed_payment_count
FROM subscriptions.subscriptions s
JOIN crm.customers c ON c.customer_id = s.customer_id
JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
ORDER BY c.customer_number, s.created_at DESC;

CREATE OR REPLACE VIEW reports.vw_subscription_analytics AS
SELECT
    DATE_TRUNC('month', s.created_at) AS cohort_month,
    COUNT(DISTINCT s.subscription_id) AS subscriptions_created,
    COUNT(DISTINCT CASE WHEN ssl.code = 'ACTIVE' THEN s.subscription_id END) AS still_active,
    COUNT(DISTINCT CASE WHEN ssl.code = 'CANCELLED' THEN s.subscription_id END) AS cancelled,
    ROUND(COUNT(DISTINCT CASE WHEN ssl.code = 'CANCELLED' THEN s.subscription_id END)::NUMERIC /
          NULLIF(COUNT(DISTINCT s.subscription_id), 0) * 100, 2) AS churn_rate_percent,
    SUM(s.total_paid) AS cohort_revenue
FROM subscriptions.subscriptions s
JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
GROUP BY DATE_TRUNC('month', s.created_at)
ORDER BY cohort_month DESC;

-- ============================================================
-- REPORT FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION reports.get_subscription_analytics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_month DATE,
    subscriptions_created BIGINT,
    active_subscriptions BIGINT,
    cancelled_subscriptions BIGINT,
    total_revenue NUMERIC,
    mrr NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC('month', s.created_at)::DATE,
        COUNT(DISTINCT s.subscription_id)::BIGINT,
        COUNT(DISTINCT CASE WHEN ssl.code = 'ACTIVE' THEN s.subscription_id END)::BIGINT,
        COUNT(DISTINCT CASE WHEN ssl.code = 'CANCELLED' THEN s.subscription_id END)::BIGINT,
        COALESCE(SUM(s.total_paid), 0),
        COALESCE(SUM(CASE WHEN ssl.code = 'ACTIVE' THEN s.total_amount ELSE 0 END), 0)
    FROM subscriptions.subscriptions s
    JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
    WHERE s.company_id = p_company_id
      AND s.created_at::DATE BETWEEN p_start_date AND p_end_date
    GROUP BY DATE_TRUNC('month', s.created_at)
    ORDER BY DATE_TRUNC('month', s.created_at);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION reports.get_customer_subscription_summary(
    p_customer_id UUID
)
RETURNS TABLE (
    subscription_number VARCHAR,
    plan_name VARCHAR,
    status VARCHAR,
    total_paid NUMERIC,
    outstanding_amount NUMERIC,
    next_billing_date DATE,
    membership_tier VARCHAR,
    active_entitlements BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.subscription_number::VARCHAR,
        sp.plan_name::VARCHAR,
        ssl.code::VARCHAR,
        s.total_paid,
        s.outstanding_amount,
        s.next_billing_date,
        mt.name::VARCHAR,
        COUNT(DISTINCT ce.customer_entitlement_id)::BIGINT
    FROM subscriptions.subscriptions s
    JOIN subscriptions.subscription_plans sp ON sp.subscription_plan_id = s.subscription_plan_id
    JOIN subscriptions.subscription_status_lookup ssl ON ssl.subscription_status_id = s.subscription_status_id
    LEFT JOIN subscriptions.membership_tier_lookup mt ON mt.membership_tier_id = s.membership_tier_id
    LEFT JOIN subscriptions.customer_memberships cm ON cm.subscription_id = s.subscription_id AND cm.is_active = TRUE
    LEFT JOIN subscriptions.customer_entitlements ce ON ce.customer_membership_id = cm.customer_membership_id AND ce.is_active = TRUE
    WHERE s.customer_id = p_customer_id
    GROUP BY s.subscription_id, s.subscription_number, sp.plan_name, ssl.code, s.total_paid, s.outstanding_amount, s.next_billing_date, mt.name
    ORDER BY s.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;