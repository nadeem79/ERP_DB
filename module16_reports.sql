BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 16: MARKETING & CAMPAIGN REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Campaign Summary Dashboard
CREATE VIEW reports.vw_campaign_summary AS
SELECT 
    DATE(c.created_at) as created_date,
    ct.code as campaign_type,
    ct.name as campaign_type_name,
    cs.code as campaign_status,
    mc.code as channel,
    COUNT(DISTINCT c.campaign_id) as campaign_count,
    SUM(c.total_recipients) as total_recipients,
    SUM(c.total_sent) as total_sent,
    SUM(c.total_delivered) as total_delivered,
    SUM(c.total_opened) as total_opened,
    SUM(c.total_clicked) as total_clicked,
    SUM(c.total_converted) as total_converted,
    SUM(c.actual_revenue) as total_revenue
FROM marketing.campaigns c
JOIN marketing.campaign_type_lookup ct ON ct.campaign_type_id = c.campaign_type_id
JOIN marketing.campaign_status_lookup cs ON cs.campaign_status_id = c.campaign_status_id
JOIN marketing.marketing_channel_lookup mc ON mc.marketing_channel_id = c.marketing_channel_id
WHERE c.is_active = TRUE
GROUP BY DATE(c.created_at), ct.code, ct.name, cs.code, mc.code
ORDER BY created_date DESC;

-- View 2: Campaign Performance by Channel
CREATE VIEW reports.vw_campaign_performance_by_channel AS
SELECT 
    mc.code as channel_code,
    mc.name as channel_name,
    COUNT(DISTINCT c.campaign_id) as campaign_count,
    SUM(c.total_sent) as total_sent,
    SUM(c.total_delivered) as total_delivered,
    SUM(c.total_opened) as total_opened,
    SUM(c.total_clicked) as total_clicked,
    SUM(c.total_converted) as total_converted,
    ROUND((SUM(c.total_delivered)::numeric / NULLIF(SUM(c.total_sent), 0) * 100), 2) as delivery_rate_percent,
    ROUND((SUM(c.total_opened)::numeric / NULLIF(SUM(c.total_delivered), 0) * 100), 2) as open_rate_percent,
    ROUND((SUM(c.total_clicked)::numeric / NULLIF(SUM(c.total_delivered), 0) * 100), 2) as click_rate_percent,
    ROUND((SUM(c.total_converted)::numeric / NULLIF(SUM(c.total_clicked), 0) * 100), 2) as conversion_rate_percent
FROM marketing.marketing_channel_lookup mc
LEFT JOIN marketing.campaigns c ON c.marketing_channel_id = mc.marketing_channel_id AND c.is_active = TRUE
GROUP BY mc.marketing_channel_id, mc.code, mc.name
ORDER BY total_converted DESC NULLS LAST;

-- View 3: Campaign ROI Analysis
CREATE VIEW reports.vw_campaign_roi AS
SELECT 
    c.campaign_id,
    c.campaign_code,
    c.campaign_name,
    ct.name as campaign_type,
    cs.code as status,
    c.actual_revenue,
    COALESCE(SUM(cb.spent_amount), 0) as total_spent,
    COALESCE(SUM(ce.amount), 0) as total_expenses,
    COALESCE(SUM(cb.spent_amount), 0) + COALESCE(SUM(ce.amount), 0) as total_cost,
    c.actual_revenue - (COALESCE(SUM(cb.spent_amount), 0) + COALESCE(SUM(ce.amount), 0)) as net_profit,
    CASE 
        WHEN COALESCE(SUM(cb.spent_amount), 0) + COALESCE(SUM(ce.amount), 0) > 0 
        THEN ROUND(((c.actual_revenue - (COALESCE(SUM(cb.spent_amount), 0) + COALESCE(SUM(ce.amount), 0))) / 
             (COALESCE(SUM(cb.spent_amount), 0) + COALESCE(SUM(ce.amount), 0)) * 100)::numeric, 2)
        ELSE NULL 
    END as roi_percent
FROM marketing.campaigns c
JOIN marketing.campaign_type_lookup ct ON ct.campaign_type_id = c.campaign_type_id
JOIN marketing.campaign_status_lookup cs ON cs.campaign_status_id = c.campaign_status_id
LEFT JOIN marketing.campaign_budgets cb ON cb.campaign_id = c.campaign_id
LEFT JOIN marketing.campaign_expenses ce ON ce.campaign_id = c.campaign_id
WHERE c.is_active = TRUE
GROUP BY c.campaign_id, c.campaign_code, c.campaign_name, ct.name, cs.code, c.actual_revenue
ORDER BY roi_percent DESC NULLS LAST;

-- View 4: Email/SMS Engagement Rates
CREATE VIEW reports.vw_campaign_engagement_rates AS
SELECT 
    c.campaign_id,
    c.campaign_code,
    c.campaign_name,
    mc.name as channel,
    c.total_sent,
    c.total_delivered,
    c.total_opened,
    c.total_clicked,
    c.total_converted,
    c.total_unsubscribed,
    c.total_bounced,
    ROUND((c.total_delivered::numeric / NULLIF(c.total_sent, 0) * 100), 2) as delivery_rate,
    ROUND((c.total_opened::numeric / NULLIF(c.total_delivered, 0) * 100), 2) as open_rate,
    ROUND((c.total_clicked::numeric / NULLIF(c.total_delivered, 0) * 100), 2) as click_rate,
    ROUND((c.total_converted::numeric / NULLIF(c.total_clicked, 0) * 100), 2) as conversion_rate,
    ROUND((c.total_unsubscribed::numeric / NULLIF(c.total_delivered, 0) * 100), 2) as unsubscribe_rate,
    ROUND((c.total_bounced::numeric / NULLIF(c.total_sent, 0) * 100), 2) as bounce_rate
FROM marketing.campaigns c
JOIN marketing.marketing_channel_lookup mc ON mc.marketing_channel_id = c.marketing_channel_id
WHERE c.is_active = TRUE AND c.total_sent > 0
ORDER BY c.created_at DESC;

-- View 5: Campaign Conversion Funnel
CREATE VIEW reports.vw_campaign_conversion_funnel AS
SELECT 
    c.campaign_id,
    c.campaign_code,
    c.campaign_name,
    c.total_recipients as stage_1_targeted,
    c.total_sent as stage_2_sent,
    c.total_delivered as stage_3_delivered,
    c.total_opened as stage_4_opened,
    c.total_clicked as stage_5_clicked,
    c.total_converted as stage_6_converted,
    ROUND((c.total_sent::numeric / NULLIF(c.total_recipients, 0) * 100), 2) as send_rate,
    ROUND((c.total_delivered::numeric / NULLIF(c.total_sent, 0) * 100), 2) as delivery_rate,
    ROUND((c.total_opened::numeric / NULLIF(c.total_delivered, 0) * 100), 2) as open_rate,
    ROUND((c.total_clicked::numeric / NULLIF(c.total_opened, 0) * 100), 2) as click_rate,
    ROUND((c.total_converted::numeric / NULLIF(c.total_clicked, 0) * 100), 2) as conversion_rate
FROM marketing.campaigns c
WHERE c.is_active = TRUE AND c.total_recipients > 0
ORDER BY c.total_converted DESC;

-- View 6: Audience Engagement Analysis
CREATE VIEW reports.vw_audience_engagement AS
SELECT 
    at.code as audience_type,
    at.name as audience_type_name,
    COUNT(DISTINCT c.campaign_id) as campaigns,
    SUM(c.total_recipients) as total_targeted,
    SUM(c.total_converted) as total_converted,
    ROUND((SUM(c.total_converted)::numeric / NULLIF(SUM(c.total_recipients), 0) * 100), 2) as overall_conversion_rate
FROM marketing.audience_type_lookup at
LEFT JOIN marketing.campaigns c ON c.audience_type_id = at.audience_type_id AND c.is_active = TRUE
GROUP BY at.audience_type_id, at.code, at.name
ORDER BY total_converted DESC NULLS LAST;

-- View 7: Abandoned Cart Recovery Report
CREATE VIEW reports.vw_abandoned_cart_recovery AS
SELECT 
    acr.rule_name,
    acr.abandon_after_minutes,
    acr.max_reminders,
    acr.channel,
    acr.is_active,
    COUNT(DISTINCT ae.automation_execution_id) as total_triggered,
    COUNT(DISTINCT CASE WHEN ae.action_result = 'SUCCESS' THEN ae.automation_execution_id END) as successful_sends
FROM marketing.abandoned_cart_rules acr
LEFT JOIN marketing.automation_rules ar ON ar.rule_name LIKE '%' || acr.rule_name || '%'
LEFT JOIN marketing.automation_executions ae ON ae.automation_rule_id = ar.automation_rule_id
GROUP BY acr.abandoned_cart_rule_id, acr.rule_name, acr.abandon_after_minutes, acr.max_reminders, acr.channel, acr.is_active
ORDER BY total_triggered DESC NULLS LAST;

-- View 8: Customer Journey Progress Report
CREATE VIEW reports.vw_journey_progress AS
SELECT 
    cj.journey_name,
    cj.is_active,
    COUNT(DISTINCT jp.journey_participant_id) as total_participants,
    COUNT(DISTINCT CASE WHEN jp.status = 'ACTIVE' THEN jp.journey_participant_id END) as active_participants,
    COUNT(DISTINCT CASE WHEN jp.status = 'COMPLETED' THEN jp.journey_participant_id END) as completed_participants,
    COUNT(DISTINCT CASE WHEN jp.status = 'EXITED' THEN jp.journey_participant_id END) as exited_participants,
    ROUND((COUNT(DISTINCT CASE WHEN jp.status = 'COMPLETED' THEN jp.journey_participant_id END)::numeric / 
           NULLIF(COUNT(DISTINCT jp.journey_participant_id), 0) * 100), 2) as completion_rate
FROM marketing.customer_journeys cj
LEFT JOIN marketing.journey_participants jp ON jp.customer_journey_id = cj.customer_journey_id
GROUP BY cj.customer_journey_id, cj.journey_name, cj.is_active
ORDER BY total_participants DESC NULLS LAST;

-- View 9: Attribution Analysis by UTM Source
CREATE VIEW reports.vw_attribution_by_source AS
SELECT 
    utm_source,
    utm_medium,
    COUNT(DISTINCT cc.campaign_conversion_id) as total_conversions,
    SUM(cc.conversion_value) as total_conversion_value,
    COUNT(DISTINCT cc.customer_id) as unique_customers
FROM marketing.campaign_conversions cc
WHERE cc.utm_source IS NOT NULL
GROUP BY cc.utm_source, cc.utm_medium
ORDER BY total_conversion_value DESC NULLS LAST;

-- View 10: UTM Campaign Performance
CREATE VIEW reports.vw_utm_campaign_performance AS
SELECT 
    cc.utm_source,
    cc.utm_medium,
    cc.utm_campaign,
    COUNT(DISTINCT cc.campaign_conversion_id) as conversions,
    SUM(cc.conversion_value) as revenue,
    COUNT(DISTINCT cc.order_id) as orders,
    COUNT(DISTINCT cc.customer_id) as unique_customers
FROM marketing.campaign_conversions cc
WHERE cc.utm_campaign IS NOT NULL
GROUP BY cc.utm_source, cc.utm_medium, cc.utm_campaign
ORDER BY revenue DESC NULLS LAST;

-- View 11: Campaign Budget vs Actual
CREATE VIEW reports.vw_campaign_budget_vs_actual AS
SELECT 
    c.campaign_code,
    c.campaign_name,
    cs.code as status,
    cb.budget_type,
    cb.allocated_amount as budget,
    cb.spent_amount as actual_spent,
    cb.allocated_amount - cb.spent_amount as remaining,
    ROUND((cb.spent_amount / NULLIF(cb.allocated_amount, 0) * 100), 2) as utilization_percent
FROM marketing.campaigns c
JOIN marketing.campaign_status_lookup cs ON cs.campaign_status_id = c.campaign_status_id
LEFT JOIN marketing.campaign_budgets cb ON cb.campaign_id = c.campaign_id
WHERE c.is_active = TRUE
ORDER BY c.campaign_code;

-- View 12: Coupon Usage by Campaign
CREATE VIEW reports.vw_coupon_usage_by_campaign AS
SELECT 
    c.campaign_code,
    c.campaign_name,
    pc.code as coupon_code,
    pc.usage_limit,
    pc.usage_count,
    ROUND((pc.usage_count::numeric / NULLIF(pc.usage_limit, 0) * 100), 2) as usage_rate_percent,
    pc.start_date,
    pc.end_date,
    pc.is_active
FROM marketing.campaign_coupons cc
JOIN marketing.campaigns c ON c.campaign_id = cc.campaign_id
JOIN pricing.coupons pc ON pc.coupon_id = cc.coupon_id
ORDER BY c.campaign_code, pc.code;

-- View 13: Marketing Automation Performance
CREATE VIEW reports.vw_automation_performance AS
SELECT 
    ar.rule_name,
    atl.name as trigger_name,
    ar.is_active,
    ar.execution_count,
    ar.last_executed_at,
    COUNT(DISTINCT ae.automation_execution_id) as total_executions,
    COUNT(DISTINCT CASE WHEN ae.action_result = 'SUCCESS' THEN ae.automation_execution_id END) as successful,
    COUNT(DISTINCT CASE WHEN ae.action_result = 'FAILED' THEN ae.automation_execution_id END) as failed,
    ROUND((COUNT(DISTINCT CASE WHEN ae.action_result = 'SUCCESS' THEN ae.automation_execution_id END)::numeric / 
           NULLIF(COUNT(DISTINCT ae.automation_execution_id), 0) * 100), 2) as success_rate
FROM marketing.automation_rules ar
JOIN marketing.automation_trigger_lookup atl ON atl.automation_trigger_id = ar.automation_trigger_id
LEFT JOIN marketing.automation_executions ae ON ae.automation_rule_id = ar.automation_rule_id
GROUP BY ar.automation_rule_id, ar.rule_name, atl.name, ar.is_active, ar.execution_count, ar.last_executed_at
ORDER BY total_executions DESC NULLS LAST;

-- View 14: Channel Comparison Report
CREATE VIEW reports.vw_channel_comparison AS
SELECT 
    mc.code as channel,
    mc.name as channel_name,
    COUNT(DISTINCT c.campaign_id) as campaigns,
    SUM(c.total_recipients) as total_reach,
    SUM(c.total_converted) as total_conversions,
    SUM(c.actual_revenue) as total_revenue,
    SUM(COALESCE(cb.spent_amount, 0)) as total_spend,
    CASE 
        WHEN SUM(COALESCE(cb.spent_amount, 0)) > 0 
        THEN ROUND((SUM(c.actual_revenue) / SUM(COALESCE(cb.spent_amount, 0)))::numeric, 2)
        ELSE NULL 
    END as revenue_per_spend
FROM marketing.marketing_channel_lookup mc
LEFT JOIN marketing.campaigns c ON c.marketing_channel_id = mc.marketing_channel_id AND c.is_active = TRUE
LEFT JOIN marketing.campaign_budgets cb ON cb.campaign_id = c.campaign_id
GROUP BY mc.marketing_channel_id, mc.code, mc.name
ORDER BY total_revenue DESC NULLS LAST;

-- View 15: Monthly Marketing Dashboard
CREATE VIEW reports.vw_monthly_marketing_dashboard AS
SELECT 
    DATE_TRUNC('month', c.created_at) as month,
    COUNT(DISTINCT c.campaign_id) as campaigns_launched,
    SUM(c.total_recipients) as total_reach,
    SUM(c.total_converted) as total_conversions,
    SUM(c.actual_revenue) as total_revenue,
    SUM(COALESCE(cb.spent_amount, 0)) as total_spend,
    ROUND((SUM(c.total_converted)::numeric / NULLIF(SUM(c.total_recipients), 0) * 100), 2) as conversion_rate
FROM marketing.campaigns c
LEFT JOIN marketing.campaign_budgets cb ON cb.campaign_id = c.campaign_id
WHERE c.is_active = TRUE
GROUP BY DATE_TRUNC('month', c.created_at)
ORDER BY month DESC;

-- View 16: Campaign Expense Analysis
CREATE VIEW reports.vw_campaign_expense_analysis AS
SELECT 
    c.campaign_code,
    c.campaign_name,
    ce.expense_category,
    COUNT(DISTINCT ce.campaign_expense_id) as expense_count,
    SUM(ce.amount) as total_amount,
    MIN(ce.expense_date) as first_expense_date,
    MAX(ce.expense_date) as last_expense_date
FROM marketing.campaign_expenses ce
JOIN marketing.campaigns c ON c.campaign_id = ce.campaign_id
GROUP BY c.campaign_code, c.campaign_name, ce.expense_category
ORDER BY total_amount DESC;

-- View 17: Recipient Delivery Status
CREATE VIEW reports.vw_recipient_delivery_status AS
SELECT 
    c.campaign_code,
    c.campaign_name,
    cr.status,
    COUNT(DISTINCT cr.campaign_recipient_id) as recipient_count,
    ROUND((COUNT(DISTINCT cr.campaign_recipient_id)::numeric / 
           NULLIF(SUM(COUNT(DISTINCT cr.campaign_recipient_id)) OVER (PARTITION BY c.campaign_id), 0) * 100), 2) as percent_of_total
FROM marketing.campaign_recipients cr
JOIN marketing.campaigns c ON c.campaign_id = cr.campaign_id
GROUP BY c.campaign_id, c.campaign_code, c.campaign_name, cr.status
ORDER BY c.campaign_code, recipient_count DESC;

-- View 18: Journey Completion Report
CREATE VIEW reports.vw_journey_completion AS
SELECT 
    cj.journey_name,
    js.step_name,
    js.step_order,
    js.step_type,
    COUNT(DISTINCT jp.journey_participant_id) FILTER (WHERE jp.current_step_id = js.journey_step_id) as participants_at_step
FROM marketing.customer_journeys cj
LEFT JOIN marketing.journey_steps js ON js.customer_journey_id = cj.customer_journey_id
LEFT JOIN marketing.journey_participants jp ON jp.customer_journey_id = cj.customer_journey_id
GROUP BY cj.customer_journey_id, cj.journey_name, js.journey_step_id, js.step_name, js.step_order, js.step_type
ORDER BY cj.journey_name, js.step_order;

-- View 19: Marketing ROI by Product
CREATE VIEW reports.vw_marketing_roi_by_product AS
SELECT 
    p.product_code,
    p.product_name,
    COUNT(DISTINCT cp.campaign_id) as campaigns_featured,
    SUM(c.actual_revenue) as attributed_revenue,
    SUM(COALESCE(cb.spent_amount, 0)) as campaign_spend
FROM marketing.campaign_products cp
JOIN catalog.products p ON p.product_id = cp.product_id
JOIN marketing.campaigns c ON c.campaign_id = cp.campaign_id AND c.is_active = TRUE
LEFT JOIN marketing.campaign_budgets cb ON cb.campaign_id = c.campaign_id
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY attributed_revenue DESC NULLS LAST;

-- View 20: Campaign Calendar
CREATE VIEW reports.vw_campaign_calendar AS
SELECT 
    c.campaign_id,
    c.campaign_code,
    c.campaign_name,
    ct.name as campaign_type,
    mc.name as channel,
    cs.code as status,
    c.start_date,
    c.end_date,
    c.scheduled_launch_at,
    c.target_recipients,
    c.target_revenue
FROM marketing.campaigns c
JOIN marketing.campaign_type_lookup ct ON ct.campaign_type_id = c.campaign_type_id
JOIN marketing.marketing_channel_lookup mc ON mc.marketing_channel_id = c.marketing_channel_id
JOIN marketing.campaign_status_lookup cs ON cs.campaign_status_id = c.campaign_status_id
WHERE c.is_active = TRUE
ORDER BY c.start_date NULLS LAST;

-- Function 1: Get Campaign Metrics by Date Range
CREATE OR REPLACE FUNCTION reports.get_campaign_metrics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    campaign_code VARCHAR,
    campaign_name VARCHAR,
    total_sent BIGINT,
    total_opened BIGINT,
    total_clicked BIGINT,
    total_converted BIGINT,
    revenue NUMERIC,
    roi_percent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.campaign_code::VARCHAR,
        c.campaign_name::VARCHAR,
        c.total_sent::BIGINT,
        c.total_opened::BIGINT,
        c.total_clicked::BIGINT,
        c.total_converted::BIGINT,
        c.actual_revenue,
        CASE 
            WHEN COALESCE(SUM(cb.spent_amount), 0) > 0 
            THEN ROUND(((c.actual_revenue - COALESCE(SUM(cb.spent_amount), 0)) / COALESCE(SUM(cb.spent_amount), 0) * 100)::numeric, 2)
            ELSE NULL 
        END
    FROM marketing.campaigns c
    LEFT JOIN marketing.campaign_budgets cb ON cb.campaign_id = c.campaign_id
    WHERE c.company_id = p_company_id
      AND c.created_at::DATE BETWEEN p_start_date AND p_end_date
    GROUP BY c.campaign_id, c.campaign_code, c.campaign_name, c.total_sent, c.total_opened, 
             c.total_clicked, c.total_converted, c.actual_revenue
    ORDER BY c.actual_revenue DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Customer Marketing History
CREATE OR REPLACE FUNCTION reports.get_customer_marketing_history(
    p_customer_id UUID
)
RETURNS TABLE (
    campaign_code VARCHAR,
    campaign_name VARCHAR,
    channel VARCHAR,
    status VARCHAR,
    sent_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    converted_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.campaign_code::VARCHAR,
        c.campaign_name::VARCHAR,
        mc.name::VARCHAR,
        cr.status::VARCHAR,
        cr.sent_at,
        cr.opened_at,
        cr.clicked_at,
        cr.converted_at
    FROM marketing.campaign_recipients cr
    JOIN marketing.campaigns c ON c.campaign_id = cr.campaign_id
    JOIN marketing.marketing_channel_lookup mc ON mc.marketing_channel_id = c.marketing_channel_id
    WHERE cr.customer_id = p_customer_id
    ORDER BY cr.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;