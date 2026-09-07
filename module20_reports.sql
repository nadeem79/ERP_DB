BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 20: NEWSLETTER & EMAIL MARKETING REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Newsletter Campaign Summary
CREATE VIEW reports.vw_newsletter_campaign_summary AS
SELECT
    nc.campaign_code,
    nc.campaign_name,
    nc.start_date,
    nc.end_date,
    nc.total_issues_sent,
    nc.total_subscribers_reached,
    nc.total_opens,
    nc.total_clicks,
    nc.total_conversions,
    nc.total_revenue,
    ROUND((nc.total_opens::numeric / NULLIF(nc.total_subscribers_reached, 0) * 100), 2) as avg_open_rate,
    ROUND((nc.total_clicks::numeric / NULLIF(nc.total_opens, 0) * 100), 2) as avg_click_rate,
    ROUND((nc.total_conversions::numeric / NULLIF(nc.total_clicks, 0) * 100), 2) as avg_conversion_rate,
    nc.is_active
FROM newsletter.newsletter_campaigns nc
ORDER BY nc.created_at DESC;

-- View 2: Newsletter Issue Performance
CREATE VIEW reports.vw_newsletter_issue_performance AS
SELECT
    ni.issue_number,
    ni.issue_name,
    ni.subject,
    nl.list_name,
    ntl.code as newsletter_type,
    nsl.code as status,
    ni.scheduled_at,
    ni.sent_at,
    ni.total_recipients,
    ni.total_sent,
    ni.total_delivered,
    ni.total_opened,
    ni.total_clicked,
    ni.total_bounced,
    ni.total_unsubscribed,
    ni.total_conversions,
    ni.total_revenue,
    ni.open_rate,
    ni.click_rate,
    ni.bounce_rate,
    ni.unsubscribe_rate,
    ni.conversion_rate
FROM newsletter.newsletter_issues ni
JOIN newsletter.newsletter_lists nl ON nl.newsletter_list_id = ni.newsletter_list_id
JOIN newsletter.newsletter_type_lookup ntl ON ntl.newsletter_type_id = ni.newsletter_type_id
JOIN newsletter.newsletter_status_lookup nsl ON nsl.newsletter_status_id = ni.newsletter_status_id
ORDER BY ni.sent_at DESC NULLS LAST;

-- View 3: Subscriber Growth Report
CREATE VIEW reports.vw_subscriber_growth AS
SELECT
    DATE(s.subscribed_at) as signup_date,
    ssl.code as source,
    COUNT(DISTINCT s.subscriber_id) as new_subscribers,
    COUNT(DISTINCT CASE WHEN s.confirmed_at IS NOT NULL THEN s.subscriber_id END) as confirmed_subscribers
FROM newsletter.subscribers s
JOIN newsletter.subscription_source_lookup ssl ON ssl.subscription_source_id = s.subscription_source_id
WHERE s.subscribed_at IS NOT NULL
GROUP BY DATE(s.subscribed_at), ssl.code
ORDER BY signup_date DESC;

-- View 4: Subscriber Churn Report
CREATE VIEW reports.vw_subscriber_churn AS
SELECT
    DATE(s.unsubscribed_at) as unsubscribe_date,
    COUNT(DISTINCT s.subscriber_id) as unsubscribed_count,
    COUNT(DISTINCT CASE WHEN s.subscriber_status_id = (SELECT subscriber_status_id FROM newsletter.subscriber_status_lookup WHERE code = 'BOUNCED') THEN s.subscriber_id END) as bounced_count,
    COUNT(DISTINCT CASE WHEN s.subscriber_status_id = (SELECT subscriber_status_id FROM newsletter.subscriber_status_lookup WHERE code = 'COMPLAINED') THEN s.subscriber_id END) as complained_count
FROM newsletter.subscribers s
WHERE s.unsubscribed_at IS NOT NULL OR s.bounced_at IS NOT NULL OR s.complained_at IS NOT NULL
GROUP BY DATE(s.unsubscribed_at)
ORDER BY unsubscribe_date DESC;

-- View 5: Open Rate Analysis
CREATE VIEW reports.vw_open_rate_analysis AS
SELECT
    DATE(ni.sent_at) as send_date,
    nl.list_name,
    ntl.code as newsletter_type,
    COUNT(DISTINCT ni.newsletter_issue_id) as issues_sent,
    SUM(ni.total_sent) as total_sent,
    SUM(ni.total_opened) as total_opened,
    ROUND((SUM(ni.total_opened)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as open_rate,
    EXTRACT(DOW FROM ni.sent_at) as day_of_week,
    EXTRACT(HOUR FROM ni.sent_at) as hour_of_day
FROM newsletter.newsletter_issues ni
JOIN newsletter.newsletter_lists nl ON nl.newsletter_list_id = ni.newsletter_list_id
JOIN newsletter.newsletter_type_lookup ntl ON ntl.newsletter_type_id = ni.newsletter_type_id
WHERE ni.sent_at IS NOT NULL
GROUP BY DATE(ni.sent_at), nl.list_name, ntl.code, EXTRACT(DOW FROM ni.sent_at), EXTRACT(HOUR FROM ni.sent_at)
ORDER BY send_date DESC;

-- View 6: Click-Through Rate Analysis
CREATE VIEW reports.vw_click_rate_analysis AS
SELECT
    ni.issue_number,
    ni.subject,
    nl.list_name,
    ni.total_sent,
    ni.total_opened,
    ni.total_clicked,
    ROUND((ni.total_clicked::numeric / NULLIF(ni.total_sent, 0) * 100), 2) as ctr,
    ROUND((ni.total_clicked::numeric / NULLIF(ni.total_opened, 0) * 100), 2) as ctor
FROM newsletter.newsletter_issues ni
JOIN newsletter.newsletter_lists nl ON nl.newsletter_list_id = ni.newsletter_list_id
WHERE ni.sent_at IS NOT NULL AND ni.total_sent > 0
ORDER BY ni.sent_at DESC;

-- View 7: Bounce Report
CREATE VIEW reports.vw_bounce_report AS
SELECT
    DATE(ir.bounced_at) as bounce_date,
    ni.issue_number,
    ni.subject,
    s.email_address,
    s.subscriber_code,
    ssl.code as subscriber_status
FROM newsletter.issue_recipients ir
JOIN newsletter.newsletter_issues ni ON ni.newsletter_issue_id = ir.newsletter_issue_id
JOIN newsletter.subscribers s ON s.subscriber_id = ir.subscriber_id
JOIN newsletter.subscriber_status_lookup ssl ON ssl.subscriber_status_id = s.subscriber_status_id
WHERE ir.bounced_at IS NOT NULL
ORDER BY ir.bounced_at DESC;

-- View 8: Unsubscribe Report
CREATE VIEW reports.vw_unsubscribe_report AS
SELECT
    DATE(ir.unsubscribed_at) as unsubscribe_date,
    ni.issue_number,
    ni.subject,
    nl.list_name,
    COUNT(DISTINCT ir.subscriber_id) as unsubscribe_count,
    ROUND((COUNT(DISTINCT ir.subscriber_id)::numeric / NULLIF(ni.total_sent, 0) * 100), 2) as unsubscribe_rate
FROM newsletter.issue_recipients ir
JOIN newsletter.newsletter_issues ni ON ni.newsletter_issue_id = ir.newsletter_issue_id
JOIN newsletter.newsletter_lists nl ON nl.newsletter_list_id = ni.newsletter_list_id
WHERE ir.unsubscribed_at IS NOT NULL
GROUP BY DATE(ir.unsubscribed_at), ni.issue_number, ni.subject, nl.list_name, ni.total_sent
ORDER BY unsubscribe_date DESC;

-- View 9: List Performance Comparison
CREATE VIEW reports.vw_list_performance AS
SELECT
    nl.newsletter_list_id,
    nl.list_code,
    nl.list_name,
    nl.subscriber_count,
    nl.active_subscriber_count,
    COUNT(DISTINCT ni.newsletter_issue_id) as total_issues_sent,
    SUM(ni.total_sent) as total_emails_sent,
    SUM(ni.total_opened) as total_opens,
    SUM(ni.total_clicked) as total_clicks,
    SUM(ni.total_conversions) as total_conversions,
    SUM(ni.total_revenue) as total_revenue,
    ROUND((SUM(ni.total_opened)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as avg_open_rate,
    ROUND((SUM(ni.total_clicked)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as avg_ctr
FROM newsletter.newsletter_lists nl
LEFT JOIN newsletter.newsletter_issues ni ON ni.newsletter_list_id = nl.newsletter_list_id AND ni.sent_at IS NOT NULL
GROUP BY nl.newsletter_list_id, nl.list_code, nl.list_name, nl.subscriber_count, nl.active_subscriber_count
ORDER BY total_revenue DESC NULLS LAST;

-- View 10: Template Performance
CREATE VIEW reports.vw_template_performance AS
SELECT
    nt.template_code,
    nt.template_name,
    COUNT(DISTINCT ni.newsletter_issue_id) as times_used,
    SUM(ni.total_sent) as total_sent,
    SUM(ni.total_opened) as total_opened,
    SUM(ni.total_clicked) as total_clicked,
    ROUND((SUM(ni.total_opened)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as avg_open_rate,
    ROUND((SUM(ni.total_clicked)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as avg_ctr,
    MAX(ni.sent_at) as last_used_at
FROM newsletter.newsletter_templates nt
LEFT JOIN newsletter.newsletter_issues ni ON ni.newsletter_template_id = nt.newsletter_template_id AND ni.sent_at IS NOT NULL
WHERE nt.is_active = TRUE
GROUP BY nt.newsletter_template_id, nt.template_code, nt.template_name
ORDER BY times_used DESC NULLS LAST;

-- View 11: Content Block Performance
CREATE VIEW reports.vw_content_block_performance AS
SELECT
    cb.block_code,
    cb.block_name,
    ctbl.code as block_type,
    COUNT(DISTINCT icb.issue_content_block_id) as usage_count,
    COUNT(DISTINCT icb.newsletter_issue_id) as issues_used_in,
    cb.is_reusable,
    cb.is_active
FROM newsletter.content_blocks cb
JOIN newsletter.content_block_type_lookup ctbl ON ctbl.content_block_type_id = cb.content_block_type_id
LEFT JOIN newsletter.issue_content_blocks icb ON icb.content_block_id = cb.content_block_id
GROUP BY cb.content_block_id, cb.block_code, cb.block_name, ctbl.code, cb.is_reusable, cb.is_active
ORDER BY usage_count DESC NULLS LAST;

-- View 12: Product Performance in Newsletters
CREATE VIEW reports.vw_product_newsletter_performance AS
SELECT
    p.product_code,
    p.product_name,
    COUNT(DISTINCT ip.issue_product_id) as times_featured,
    COUNT(DISTINCT ip.newsletter_issue_id) as issues_featured_in,
    SUM(ip.click_count) as total_clicks,
    SUM(ip.conversion_count) as total_conversions,
    ROUND((SUM(ip.conversion_count)::numeric / NULLIF(SUM(ip.click_count), 0) * 100), 2) as conversion_rate
FROM newsletter.issue_products ip
JOIN catalog.products p ON p.product_id = ip.product_id
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY total_conversions DESC NULLS LAST;

-- View 13: Revenue Attribution from Newsletters
CREATE VIEW reports.vw_newsletter_revenue_attribution AS
SELECT
    ni.issue_number,
    ni.subject,
    ni.sent_at,
    nl.list_name,
    ni.total_sent,
    ni.total_conversions,
    ni.total_revenue,
    ROUND((ni.total_revenue / NULLIF(ni.total_sent, 0)), 2) as revenue_per_email,
    ROUND((ni.total_conversions::numeric / NULLIF(ni.total_sent, 0) * 100), 2) as conversion_rate
FROM newsletter.newsletter_issues ni
JOIN newsletter.newsletter_lists nl ON nl.newsletter_list_id = ni.newsletter_list_id
WHERE ni.sent_at IS NOT NULL AND ni.total_revenue > 0
ORDER BY ni.total_revenue DESC;

-- View 14: A/B Test Results
CREATE VIEW reports.vw_ab_test_results AS
SELECT
    abt.test_name,
    abt.test_type,
    abts.code as test_status,
    abtc.code as winner_criteria,
    abt.sample_size_percent,
    abt.test_duration_hours,
    abt.started_at,
    abt.completed_at,
    COUNT(DISTINCT abtv.ab_test_variant_id) as variant_count,
    MAX(CASE WHEN abtv.is_winner = TRUE THEN abtv.variant_code END) as winning_variant,
    MAX(CASE WHEN abtv.is_winner = TRUE THEN abtv.open_rate END) as winner_open_rate,
    MAX(CASE WHEN abtv.is_winner = TRUE THEN abtv.click_rate END) as winner_click_rate
FROM newsletter.ab_tests abt
JOIN newsletter.ab_test_status_lookup abts ON abts.ab_test_status_id = abt.ab_test_status_id
JOIN newsletter.ab_test_criteria_lookup abtc ON abtc.ab_test_criteria_id = abt.ab_test_criteria_id
LEFT JOIN newsletter.ab_test_variants abtv ON abtv.ab_test_id = abt.ab_test_id
GROUP BY abt.ab_test_id, abt.test_name, abt.test_type, abts.code, abtc.code,
         abt.sample_size_percent, abt.test_duration_hours, abt.started_at, abt.completed_at
ORDER BY abt.created_at DESC;

-- View 15: Send Time Optimization
CREATE VIEW reports.vw_send_time_optimization AS
SELECT
    EXTRACT(DOW FROM ni.sent_at) as day_of_week,
    EXTRACT(HOUR FROM ni.sent_at) as hour_of_day,
    COUNT(DISTINCT ni.newsletter_issue_id) as sends_count,
    SUM(ni.total_sent) as total_sent,
    SUM(ni.total_opened) as total_opened,
    SUM(ni.total_clicked) as total_clicked,
    ROUND((SUM(ni.total_opened)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as open_rate,
    ROUND((SUM(ni.total_clicked)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as click_rate
FROM newsletter.newsletter_issues ni
WHERE ni.sent_at IS NOT NULL
GROUP BY EXTRACT(DOW FROM ni.sent_at), EXTRACT(HOUR FROM ni.sent_at)
ORDER BY open_rate DESC NULLS LAST;

-- View 16: Subscriber Engagement Score
CREATE VIEW reports.vw_subscriber_engagement AS
SELECT
    s.subscriber_code,
    s.email_address,
    s.first_name,
    s.last_name,
    ssl.code as status,
    s.engagement_score,
    s.total_emails_sent,
    s.total_emails_opened,
    s.total_emails_clicked,
    ROUND((s.total_emails_opened::numeric / NULLIF(s.total_emails_sent, 0) * 100), 2) as open_rate,
    ROUND((s.total_emails_clicked::numeric / NULLIF(s.total_emails_sent, 0) * 100), 2) as click_rate,
    s.last_engaged_at,
    s.subscribed_at,
    CASE
        WHEN s.engagement_score >= 80 THEN 'HIGH'
        WHEN s.engagement_score >= 50 THEN 'MEDIUM'
        WHEN s.engagement_score >= 20 THEN 'LOW'
        ELSE 'VERY_LOW'
    END as engagement_level
FROM newsletter.subscribers s
JOIN newsletter.subscriber_status_lookup ssl ON ssl.subscriber_status_id = s.subscriber_status_id
WHERE s.is_active = TRUE
ORDER BY s.engagement_score DESC;

-- View 17: Newsletter ROI Report
CREATE VIEW reports.vw_newsletter_roi AS
SELECT
    DATE_TRUNC('month', ni.sent_at) as month,
    COUNT(DISTINCT ni.newsletter_issue_id) as issues_sent,
    SUM(ni.total_sent) as total_sent,
    SUM(ni.total_conversions) as total_conversions,
    SUM(ni.total_revenue) as total_revenue,
    ROUND((SUM(ni.total_revenue) / NULLIF(SUM(ni.total_sent), 0)), 2) as revenue_per_email,
    ROUND((SUM(ni.total_conversions)::numeric / NULLIF(SUM(ni.total_sent), 0) * 100), 2) as conversion_rate
FROM newsletter.newsletter_issues ni
WHERE ni.sent_at IS NOT NULL
GROUP BY DATE_TRUNC('month', ni.sent_at)
ORDER BY month DESC;

-- View 18: Segment Performance
CREATE VIEW reports.vw_segment_performance AS
SELECT
    ns.segment_code,
    ns.segment_name,
    ns.is_dynamic,
    ns.estimated_size,
    ns.last_calculated_at,
    COUNT(DISTINCT ni.newsletter_issue_id) as issues_targeted,
    SUM(ni.total_sent) as total_sent_to_segment,
    SUM(ni.total_opened) as total_opens_from_segment,
    SUM(ni.total_conversions) as total_conversions_from_segment,
    SUM(ni.total_revenue) as total_revenue_from_segment
FROM newsletter.newsletter_segments ns
LEFT JOIN newsletter.newsletter_issues ni ON ni.target_segment_id = ns.newsletter_segment_id AND ni.sent_at IS NOT NULL
WHERE ns.is_active = TRUE
GROUP BY ns.newsletter_segment_id, ns.segment_code, ns.segment_name, ns.is_dynamic, ns.estimated_size, ns.last_calculated_at
ORDER BY total_revenue_from_segment DESC NULLS LAST;

-- View 19: Automation Performance
CREATE VIEW reports.vw_automation_performance AS
SELECT
    ar.rule_name,
    ar.trigger_event,
    ar.delay_minutes,
    ar.is_active,
    ar.execution_count,
    ar.last_executed_at,
    nl.list_name,
    nt.template_name
FROM newsletter.automation_rules ar
LEFT JOIN newsletter.newsletter_lists nl ON nl.newsletter_list_id = ar.newsletter_list_id
LEFT JOIN newsletter.newsletter_templates nt ON nt.newsletter_template_id = ar.newsletter_template_id
ORDER BY ar.execution_count DESC;

-- View 20: Subscriber Source Analysis
CREATE VIEW reports.vw_subscriber_source_analysis AS
SELECT
    ssl.code as source_code,
    ssl.name as source_name,
    COUNT(DISTINCT s.subscriber_id) as total_subscribers,
    COUNT(DISTINCT CASE WHEN s.subscriber_status_id = (SELECT subscriber_status_id FROM newsletter.subscriber_status_lookup WHERE code = 'SUBSCRIBED') THEN s.subscriber_id END) as active_subscribers,
    COUNT(DISTINCT CASE WHEN s.subscriber_status_id = (SELECT subscriber_status_id FROM newsletter.subscriber_status_lookup WHERE code = 'UNSUBSCRIBED') THEN s.subscriber_id END) as unsubscribed,
    ROUND(AVG(s.engagement_score), 2) as avg_engagement_score
FROM newsletter.subscription_source_lookup ssl
LEFT JOIN newsletter.subscribers s ON s.subscription_source_id = ssl.subscription_source_id
GROUP BY ssl.subscription_source_id, ssl.code, ssl.name
ORDER BY total_subscribers DESC NULLS LAST;

-- Function 1: Get Newsletter Issue Stats
CREATE OR REPLACE FUNCTION reports.get_newsletter_issue_stats(
    p_newsletter_issue_id UUID
)
RETURNS TABLE (
    issue_number VARCHAR,
    subject VARCHAR,
    total_sent BIGINT,
    total_delivered BIGINT,
    total_opened BIGINT,
    total_clicked BIGINT,
    total_bounced BIGINT,
    total_unsubscribed BIGINT,
    total_conversions BIGINT,
    total_revenue NUMERIC,
    open_rate NUMERIC,
    click_rate NUMERIC,
    conversion_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ni.issue_number::VARCHAR,
        ni.subject::VARCHAR,
        ni.total_sent::BIGINT,
        ni.total_delivered::BIGINT,
        ni.total_opened::BIGINT,
        ni.total_clicked::BIGINT,
        ni.total_bounced::BIGINT,
        ni.total_unsubscribed::BIGINT,
        ni.total_conversions::BIGINT,
        ni.total_revenue,
        ni.open_rate,
        ni.click_rate,
        ni.conversion_rate
    FROM newsletter.newsletter_issues ni
    WHERE ni.newsletter_issue_id = p_newsletter_issue_id;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Subscriber History
CREATE OR REPLACE FUNCTION reports.get_subscriber_history(
    p_subscriber_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    event_type VARCHAR,
    issue_number VARCHAR,
    subject VARCHAR,
    occurred_at TIMESTAMPTZ,
    link_url VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        setl.code::VARCHAR,
        ni.issue_number::VARCHAR,
        ni.subject::VARCHAR,
        se.occurred_at,
        se.link_url::VARCHAR
    FROM newsletter.subscriber_events se
    JOIN newsletter.subscriber_event_type_lookup setl ON setl.subscriber_event_type_id = se.subscriber_event_type_id
    LEFT JOIN newsletter.newsletter_issues ni ON ni.newsletter_issue_id = se.newsletter_issue_id
    WHERE se.subscriber_id = p_subscriber_id
    ORDER BY se.occurred_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMIT;