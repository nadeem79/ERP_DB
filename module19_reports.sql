BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 19: NOTIFICATION CENTER REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Notification Summary Dashboard
CREATE VIEW reports.vw_notification_summary AS
SELECT
    DATE(n.queued_at) as notification_date,
    ncl.code as channel,
    ntl.code as notification_type,
    nsl.code as status,
    COUNT(DISTINCT n.notification_id) as notification_count,
    SUM(n.total_recipients) as total_recipients,
    SUM(n.sent_count) as total_sent,
    SUM(n.delivered_count) as total_delivered,
    SUM(n.opened_count) as total_opened,
    SUM(n.clicked_count) as total_clicked,
    SUM(n.failed_count) as total_failed,
    SUM(n.bounced_count) as total_bounced
FROM notifications.notifications n
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = n.notification_type_id
JOIN notifications.notification_status_lookup nsl ON nsl.notification_status_id = n.notification_status_id
GROUP BY DATE(n.queued_at), ncl.code, ntl.code, nsl.code
ORDER BY notification_date DESC;

-- View 2: Channel Performance
CREATE VIEW reports.vw_channel_performance AS
SELECT
    ncl.code as channel_code,
    ncl.name as channel_name,
    COUNT(DISTINCT n.notification_id) as total_notifications,
    SUM(n.total_recipients) as total_recipients,
    SUM(n.sent_count) as total_sent,
    SUM(n.delivered_count) as total_delivered,
    SUM(n.opened_count) as total_opened,
    SUM(n.clicked_count) as total_clicked,
    SUM(n.failed_count) as total_failed,
    ROUND((SUM(n.delivered_count)::numeric / NULLIF(SUM(n.sent_count), 0) * 100), 2) as delivery_rate,
    ROUND((SUM(n.opened_count)::numeric / NULLIF(SUM(n.delivered_count), 0) * 100), 2) as open_rate,
    ROUND((SUM(n.clicked_count)::numeric / NULLIF(SUM(n.opened_count), 0) * 100), 2) as click_rate,
    ROUND((SUM(n.failed_count)::numeric / NULLIF(SUM(n.sent_count), 0) * 100), 2) as failure_rate
FROM notifications.notification_channel_lookup ncl
LEFT JOIN notifications.notifications n ON n.notification_channel_id = ncl.notification_channel_id
WHERE ncl.is_active = TRUE
GROUP BY ncl.notification_channel_id, ncl.code, ncl.name
ORDER BY total_notifications DESC NULLS LAST;

-- View 3: Provider Performance
CREATE VIEW reports.vw_provider_performance AS
SELECT
    np.provider_code,
    np.provider_name,
    ncl.name as channel_name,
    nps.name as provider_status,
    np.is_primary,
    COUNT(DISTINCT nd.notification_delivery_id) as total_deliveries,
    COUNT(DISTINCT CASE WHEN nd.delivered_at IS NOT NULL THEN nd.notification_delivery_id END) as successful_deliveries,
    COUNT(DISTINCT CASE WHEN nd.bounced_at IS NOT NULL THEN nd.notification_delivery_id END) as bounced_count,
    ROUND((COUNT(DISTINCT CASE WHEN nd.delivered_at IS NOT NULL THEN nd.notification_delivery_id END)::numeric /
           NULLIF(COUNT(DISTINCT nd.notification_delivery_id), 0) * 100), 2) as success_rate
FROM notifications.notification_providers np
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = np.notification_channel_id
JOIN notifications.provider_status_lookup nps ON nps.provider_status_id = np.provider_status_id
LEFT JOIN notifications.notification_deliveries nd ON nd.notification_provider_id = np.notification_provider_id
WHERE np.is_active = TRUE
GROUP BY np.notification_provider_id, np.provider_code, np.provider_name, ncl.name, nps.name, np.is_primary
ORDER BY total_deliveries DESC NULLS LAST;

-- View 4: Template Usage Report
CREATE VIEW reports.vw_template_usage AS
SELECT
    nt.template_code,
    nt.template_name,
    ncl.name as channel_name,
    ntl.name as type_name,
    tsl.name as template_status,
    nt.locale,
    nt.current_version,
    COUNT(DISTINCT n.notification_id) as times_used,
    MAX(n.queued_at) as last_used_at
FROM notifications.notification_templates nt
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = nt.notification_channel_id
JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = nt.notification_type_id
JOIN notifications.template_status_lookup tsl ON tsl.template_status_id = nt.template_status_id
LEFT JOIN notifications.notifications n ON n.notification_template_id = nt.notification_template_id
WHERE nt.is_active = TRUE
GROUP BY nt.notification_template_id, nt.template_code, nt.template_name, ncl.name, ntl.name, tsl.name, nt.locale, nt.current_version
ORDER BY times_used DESC NULLS LAST;

-- View 5: Delivery Status Distribution
CREATE VIEW reports.vw_delivery_status_distribution AS
SELECT
    nsl.code as status_code,
    nsl.name as status_name,
    nsl.is_terminal,
    COUNT(DISTINCT nr.notification_recipient_id) as recipient_count,
    ROUND((COUNT(DISTINCT nr.notification_recipient_id)::numeric /
           NULLIF((SELECT COUNT(*) FROM notifications.notification_recipients), 0) * 100), 2) as percent_of_total
FROM notifications.notification_status_lookup nsl
LEFT JOIN notifications.notification_recipients nr ON nr.delivery_status_id = nsl.notification_status_id
GROUP BY nsl.notification_status_id, nsl.code, nsl.name, nsl.is_terminal, nsl.sort_order
ORDER BY nsl.sort_order;

-- View 6: Failed Notifications Report
CREATE VIEW reports.vw_failed_notifications AS
SELECT
    n.notification_number,
    n.subject,
    ncl.name as channel,
    ntl.name as notification_type,
    nr.recipient_name,
    nr.recipient_email,
    nr.recipient_phone,
    nr.failure_reason,
    nd.error_message,
    nd.error_code,
    nr.failed_at,
    nd.attempt_count
FROM notifications.notifications n
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = n.notification_type_id
JOIN notifications.notification_recipients nr ON nr.notification_id = n.notification_id
LEFT JOIN notifications.notification_deliveries nd ON nd.notification_recipient_id = nr.notification_recipient_id
WHERE nr.failed_at IS NOT NULL
ORDER BY nr.failed_at DESC;

-- View 7: Bounce Report
CREATE VIEW reports.vw_bounce_report AS
SELECT
    DATE(nr.bounced_at) as bounce_date,
    ncl.name as channel,
    COUNT(DISTINCT nr.notification_recipient_id) as bounce_count,
    COUNT(DISTINCT nr.customer_id) as affected_customers,
    COUNT(DISTINCT nr.recipient_email) as affected_emails
FROM notifications.notification_recipients nr
JOIN notifications.notifications n ON n.notification_id = nr.notification_id
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
WHERE nr.bounced_at IS NOT NULL
GROUP BY DATE(nr.bounced_at), ncl.name
ORDER BY bounce_date DESC;

-- View 8: Unsubscribe Report
CREATE VIEW reports.vw_unsubscribe_report AS
SELECT
    DATE(nr.unsubscribed_at) as unsubscribe_date,
    ncl.name as channel,
    ntl.name as notification_type,
    COUNT(DISTINCT nr.notification_recipient_id) as unsubscribe_count
FROM notifications.notification_recipients nr
JOIN notifications.notifications n ON n.notification_id = nr.notification_id
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = n.notification_type_id
WHERE nr.unsubscribed_at IS NOT NULL
GROUP BY DATE(nr.unsubscribed_at), ncl.name, ntl.name
ORDER BY unsubscribe_date DESC;

-- View 9: Suppression List Report
CREATE VIEW reports.vw_suppression_list AS
SELECT
    ns.notification_suppression_id,
    ncl.name as channel,
    ns.email_address,
    ns.phone_number,
    ns.suppression_reason,
    ns.suppression_source,
    ns.suppressed_at,
    ns.expires_at,
    ns.is_active
FROM notifications.notification_suppressions ns
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = ns.notification_channel_id
WHERE ns.is_active = TRUE
ORDER BY ns.suppressed_at DESC;

-- View 10: Preference Summary
CREATE VIEW reports.vw_preference_summary AS
SELECT
    ncl.name as channel,
    ntl.name as notification_type,
    psl.name as preference_status,
    COUNT(DISTINCT np.notification_preference_id) as preference_count
FROM notifications.notification_preferences np
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = np.notification_channel_id
JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = np.notification_type_id
JOIN notifications.preference_status_lookup psl ON psl.preference_status_id = np.preference_status_id
GROUP BY ncl.name, ntl.name, psl.name
ORDER BY ncl.name, ntl.name, preference_count DESC;

-- View 11: Dead Letter Queue Report
CREATE VIEW reports.vw_dead_letter_queue AS
SELECT
    dlq.dead_letter_id,
    dlq.error_message,
    dlq.error_code,
    dlq.failure_count,
    dlq.first_failed_at,
    dlq.last_failed_at,
    dlq.max_retries,
    dlq.is_resolved,
    dlq.resolved_at,
    n.notification_number,
    n.subject
FROM notifications.dead_letter_queue dlq
LEFT JOIN notifications.notifications n ON n.notification_id = dlq.notification_id
ORDER BY dlq.is_resolved ASC, dlq.last_failed_at DESC;

-- View 12: In-App Notification Center
CREATE VIEW reports.vw_in_app_notifications AS
SELECT
    ian.in_app_notification_id,
    ian.title,
    ian.body,
    ian.notification_type,
    ian.severity,
    ian.recipient_type,
    ian.is_read,
    ian.read_at,
    ian.is_archived,
    ian.created_at,
    ian.action_url,
    ian.reference_type,
    ian.reference_id
FROM notifications.in_app_notifications ian
WHERE ian.is_archived = FALSE
ORDER BY ian.created_at DESC;

-- View 13: Scheduled Notifications Report
CREATE VIEW reports.vw_scheduled_notifications AS
SELECT
    sn.scheduled_notification_id,
    sn.schedule_name,
    ncl.name as channel,
    ntl.name as notification_type,
    ssl.name as schedule_status,
    sn.scheduled_at,
    sn.timezone,
    sn.sent_at,
    sn.cancelled_at
FROM notifications.scheduled_notifications sn
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = sn.notification_channel_id
JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = sn.notification_type_id
JOIN notifications.schedule_status_lookup ssl ON ssl.schedule_status_id = sn.schedule_status_id
ORDER BY sn.scheduled_at DESC;

-- View 14: Digest Performance
CREATE VIEW reports.vw_digest_performance AS
SELECT
    nd.digest_name,
    ncl.name as channel,
    dfl.name as frequency,
    nd.send_time,
    nd.last_sent_at,
    nd.next_send_at,
    nd.is_active,
    COUNT(DISTINCT de.digest_entry_id) as total_entries,
    COUNT(DISTINCT CASE WHEN de.is_sent = TRUE THEN de.digest_entry_id END) as sent_entries
FROM notifications.notification_digests nd
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = nd.notification_channel_id
JOIN notifications.digest_frequency_lookup dfl ON dfl.digest_frequency_id = nd.digest_frequency_id
LEFT JOIN notifications.digest_entries de ON de.notification_digest_id = nd.notification_digest_id
GROUP BY nd.notification_digest_id, nd.digest_name, ncl.name, dfl.name, nd.send_time, nd.last_sent_at, nd.next_send_at, nd.is_active
ORDER BY nd.last_sent_at DESC NULLS LAST;

-- View 15: Notification Events Timeline
CREATE VIEW reports.vw_notification_events_timeline AS
SELECT
    ne.event_type,
    ne.occurred_at,
    ne.source,
    n.notification_number,
    n.subject,
    ncl.name as channel,
    ne.event_data
FROM notifications.notification_events ne
LEFT JOIN notifications.notifications n ON n.notification_id = ne.notification_id
LEFT JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
ORDER BY ne.occurred_at DESC
LIMIT 1000;

-- View 16: Retry Analysis
CREATE VIEW reports.vw_retry_analysis AS
SELECT
    DATE(da.attempted_at) as attempt_date,
    np.provider_name,
    COUNT(DISTINCT da.delivery_attempt_id) as total_attempts,
    COUNT(DISTINCT CASE WHEN da.status = 'SENT' THEN da.delivery_attempt_id END) as successful_attempts,
    COUNT(DISTINCT CASE WHEN da.status = 'FAILED' THEN da.delivery_attempt_id END) as failed_attempts,
    COUNT(DISTINCT CASE WHEN da.is_retry = TRUE THEN da.delivery_attempt_id END) as retry_attempts,
    AVG(da.duration_ms) as avg_duration_ms
FROM notifications.delivery_attempts da
JOIN notifications.notification_providers np ON np.notification_provider_id = da.notification_provider_id
GROUP BY DATE(da.attempted_at), np.provider_name
ORDER BY attempt_date DESC;

-- View 17: Notification by Reference Type
CREATE VIEW reports.vw_notification_by_reference AS
SELECT
    n.reference_type,
    COUNT(DISTINCT n.notification_id) as notification_count,
    SUM(n.total_recipients) as total_recipients,
    SUM(n.sent_count) as total_sent,
    SUM(n.delivered_count) as total_delivered,
    SUM(n.opened_count) as total_opened,
    MAX(n.queued_at) as last_notification_at
FROM notifications.notifications n
WHERE n.reference_type IS NOT NULL
GROUP BY n.reference_type
ORDER BY notification_count DESC;

-- View 18: Monthly Notification Analytics
CREATE VIEW reports.vw_monthly_notification_analytics AS
SELECT
    DATE_TRUNC('month', n.queued_at) as month,
    ncl.name as channel,
    COUNT(DISTINCT n.notification_id) as total_notifications,
    SUM(n.total_recipients) as total_recipients,
    SUM(n.sent_count) as total_sent,
    SUM(n.delivered_count) as total_delivered,
    SUM(n.opened_count) as total_opened,
    SUM(n.clicked_count) as total_clicked,
    SUM(n.failed_count) as total_failed,
    ROUND((SUM(n.delivered_count)::numeric / NULLIF(SUM(n.sent_count), 0) * 100), 2) as delivery_rate,
    ROUND((SUM(n.opened_count)::numeric / NULLIF(SUM(n.delivered_count), 0) * 100), 2) as open_rate
FROM notifications.notifications n
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
GROUP BY DATE_TRUNC('month', n.queued_at), ncl.name
ORDER BY month DESC;

-- View 19: Customer Notification History
CREATE VIEW reports.vw_customer_notification_history AS
SELECT
    c.customer_number,
    c.display_name,
    ncl.name as channel,
    ntl.name as notification_type,
    n.subject,
    nsl.name as status,
    nr.sent_at,
    nr.delivered_at,
    nr.opened_at,
    nr.clicked_at
FROM notifications.notification_recipients nr
JOIN crm.customers c ON c.customer_id = nr.customer_id
JOIN notifications.notifications n ON n.notification_id = nr.notification_id
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = n.notification_type_id
JOIN notifications.notification_status_lookup nsl ON nsl.notification_status_id = n.notification_status_id
ORDER BY nr.sent_at DESC NULLS LAST;

-- View 20: Provider Failover Report
CREATE VIEW reports.vw_provider_failover AS
SELECT
    np.provider_code,
    np.provider_name,
    fp.provider_code as failover_provider_code,
    fp.provider_name as failover_provider_name,
    ncl.name as channel,
    np.is_primary,
    nps.name as status
FROM notifications.notification_providers np
LEFT JOIN notifications.notification_providers fp ON fp.notification_provider_id = np.failover_provider_id
JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = np.notification_channel_id
JOIN notifications.provider_status_lookup nps ON nps.provider_status_id = np.provider_status_id
WHERE np.is_active = TRUE
ORDER BY ncl.name, np.priority;

-- Function 1: Get Notification Delivery Stats
CREATE OR REPLACE FUNCTION reports.get_notification_delivery_stats(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    channel VARCHAR,
    notification_type VARCHAR,
    total_sent BIGINT,
    total_delivered BIGINT,
    total_opened BIGINT,
    total_clicked BIGINT,
    total_failed BIGINT,
    delivery_rate NUMERIC,
    open_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ncl.code::VARCHAR,
        ntl.code::VARCHAR,
        SUM(n.sent_count)::BIGINT,
        SUM(n.delivered_count)::BIGINT,
        SUM(n.opened_count)::BIGINT,
        SUM(n.clicked_count)::BIGINT,
        SUM(n.failed_count)::BIGINT,
        ROUND((SUM(n.delivered_count)::numeric / NULLIF(SUM(n.sent_count), 0) * 100), 2),
        ROUND((SUM(n.opened_count)::numeric / NULLIF(SUM(n.delivered_count), 0) * 100), 2)
    FROM notifications.notifications n
    JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = n.notification_channel_id
    JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = n.notification_type_id
    WHERE n.company_id = p_company_id
      AND n.queued_at::DATE BETWEEN p_start_date AND p_end_date
    GROUP BY ncl.code, ntl.code
    ORDER BY SUM(n.sent_count) DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Customer Notification Preferences
CREATE OR REPLACE FUNCTION reports.get_customer_notification_preferences(
    p_customer_id UUID
)
RETURNS TABLE (
    channel VARCHAR,
    notification_type VARCHAR,
    preference_status VARCHAR,
    quiet_hours_start TIME,
    quiet_hours_end TIME
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ncl.code::VARCHAR,
        ntl.code::VARCHAR,
        psl.code::VARCHAR,
        np.quiet_hours_start,
        np.quiet_hours_end
    FROM notifications.notification_preferences np
    JOIN notifications.notification_channel_lookup ncl ON ncl.notification_channel_id = np.notification_channel_id
    JOIN notifications.notification_type_lookup ntl ON ntl.notification_type_id = np.notification_type_id
    JOIN notifications.preference_status_lookup psl ON psl.preference_status_id = np.preference_status_id
    WHERE np.customer_id = p_customer_id
    ORDER BY ncl.sort_order, ntl.sort_order;
END;
$$ LANGUAGE plpgsql;

COMMIT;