BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 15: ADVANCED CRM & CUSTOMER SERVICE REPORTING
-- 18 Views + 2 Functions
-- ============================================================

-- View 1: Lead Summary
CREATE VIEW reports.vw_lead_summary AS
SELECT 
    DATE(l.created_at) as lead_date,
    ls.code as lead_source,
    lst.code as lead_status,
    lq.code as lead_quality,
    COUNT(DISTINCT l.customer_lead_id) as total_leads,
    COUNT(DISTINCT CASE WHEN lst.code = 'QUALIFIED' THEN l.customer_lead_id END) as qualified_leads,
    COUNT(DISTINCT CASE WHEN lst.code = 'WON' THEN l.customer_lead_id END) as converted_leads,
    COUNT(DISTINCT CASE WHEN lst.code = 'LOST' THEN l.customer_lead_id END) as lost_leads,
    SUM(COALESCE(l.estimated_value, 0)) as total_estimated_value
FROM crm.customer_leads l
JOIN crm.customer_lead_source_lookup ls ON ls.customer_lead_source_id = l.customer_lead_source_id
JOIN crm.customer_lead_status_lookup lst ON lst.customer_lead_status_id = l.customer_lead_status_id
LEFT JOIN crm.customer_lead_quality_lookup lq ON lq.customer_lead_quality_id = l.customer_lead_quality_id
WHERE l.is_active = TRUE
GROUP BY DATE(l.created_at), ls.code, lst.code, lq.code
ORDER BY lead_date DESC;

-- View 2: Lead Conversion Funnel
CREATE VIEW reports.vw_lead_conversion_funnel AS
SELECT 
    lst.code as stage,
    lst.name as stage_name,
    lst.sort_order,
    COUNT(DISTINCT l.customer_lead_id) as lead_count,
    ROUND(
        (COUNT(DISTINCT l.customer_lead_id)::numeric / 
         NULLIF((SELECT COUNT(*) FROM crm.customer_leads WHERE is_active = TRUE), 0) * 100), 2
    ) as percent_of_total
FROM crm.customer_lead_status_lookup lst
LEFT JOIN crm.customer_leads l ON l.customer_lead_status_id = lst.customer_lead_status_id AND l.is_active = TRUE
GROUP BY lst.customer_lead_status_id, lst.code, lst.name, lst.sort_order
ORDER BY lst.sort_order;

-- View 3: Opportunity Pipeline Summary
CREATE VIEW reports.vw_opportunity_pipeline AS
SELECT 
    ps.code as stage_code,
    ps.name as stage_name,
    ps.stage_order,
    ps.probability_percent,
    COUNT(DISTINCT o.customer_opportunity_id) as opportunity_count,
    SUM(COALESCE(o.estimated_value, 0)) as total_value,
    SUM(COALESCE(o.estimated_value, 0) * ps.probability_percent / 100) as weighted_value
FROM crm.customer_pipeline_stage_lookup ps
LEFT JOIN crm.customer_opportunities o ON o.customer_pipeline_stage_id = ps.customer_pipeline_stage_id
    AND o.customer_opportunity_status_id = (SELECT customer_opportunity_status_id FROM crm.customer_opportunity_status_lookup WHERE code = 'OPEN')
GROUP BY ps.customer_pipeline_stage_id, ps.code, ps.name, ps.stage_order, ps.probability_percent
ORDER BY ps.stage_order;

-- View 4: Opportunity Performance by Employee
CREATE VIEW reports.vw_opportunity_performance_by_employee AS
SELECT 
    e.employee_id,
    COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, '') as employee_name,
    COUNT(DISTINCT o.customer_opportunity_id) as total_opportunities,
    COUNT(DISTINCT CASE WHEN os.code = 'WON' THEN o.customer_opportunity_id END) as won_opportunities,
    COUNT(DISTINCT CASE WHEN os.code = 'LOST' THEN o.customer_opportunity_id END) as lost_opportunities,
    SUM(COALESCE(o.estimated_value, 0)) as total_pipeline_value,
    ROUND(
        (COUNT(DISTINCT CASE WHEN os.code = 'WON' THEN o.customer_opportunity_id END)::numeric / 
         NULLIF(COUNT(DISTINCT o.customer_opportunity_id), 0) * 100), 2
    ) as win_rate_percent
FROM crm.customer_opportunities o
JOIN crm.customer_opportunity_status_lookup os ON os.customer_opportunity_status_id = o.customer_opportunity_status_id
LEFT JOIN identity.employees e ON e.employee_id = o.assigned_to_employee_id
LEFT JOIN identity.persons p ON p.person_id = e.person_id
GROUP BY e.employee_id, p.first_name, p.last_name
ORDER BY total_pipeline_value DESC NULLS LAST;

-- View 5: Ticket Summary Dashboard
CREATE VIEW reports.vw_ticket_summary AS
SELECT 
    DATE(t.created_at) as ticket_date,
    tc.code as category,
    tp.code as priority,
    ts.code as status,
    tch.code as channel,
    COUNT(DISTINCT t.ticket_id) as ticket_count,
    COUNT(DISTINCT CASE WHEN ts.is_open = TRUE THEN t.ticket_id END) as open_tickets,
    COUNT(DISTINCT CASE WHEN ts.is_open = FALSE THEN t.ticket_id END) as closed_tickets
FROM support.tickets t
JOIN support.ticket_category_lookup tc ON tc.ticket_category_id = t.ticket_category_id
JOIN support.ticket_priority_lookup tp ON tp.ticket_priority_id = t.ticket_priority_id
JOIN support.ticket_status_lookup ts ON ts.ticket_status_id = t.ticket_status_id
JOIN support.ticket_channel_lookup tch ON tch.ticket_channel_id = t.ticket_channel_id
GROUP BY DATE(t.created_at), tc.code, tp.code, ts.code, tch.code
ORDER BY ticket_date DESC;

-- View 6: Ticket Aging Report
CREATE VIEW reports.vw_ticket_aging AS
SELECT 
    t.ticket_id,
    t.ticket_number,
    t.subject,
    c.display_name as customer_name,
    tc.code as category,
    tp.code as priority,
    ts.code as status,
    t.created_at,
    CURRENT_TIMESTAMP - t.created_at as time_open,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - t.created_at))/3600 as hours_open,
    CASE 
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - t.created_at))/3600 < 24 THEN '0-24 hours'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - t.created_at))/3600 < 72 THEN '1-3 days'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - t.created_at))/3600 < 168 THEN '3-7 days'
        ELSE '7+ days'
    END as aging_bucket
FROM support.tickets t
JOIN crm.customers c ON c.customer_id = t.customer_id
JOIN support.ticket_category_lookup tc ON tc.ticket_category_id = t.ticket_category_id
JOIN support.ticket_priority_lookup tp ON tp.ticket_priority_id = t.ticket_priority_id
JOIN support.ticket_status_lookup ts ON ts.ticket_status_id = t.ticket_status_id
WHERE ts.is_open = TRUE
ORDER BY t.created_at ASC;

-- View 7: Agent Performance Report
CREATE VIEW reports.vw_agent_performance AS
SELECT 
    e.employee_id,
    COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, '') as agent_name,
    COUNT(DISTINCT t.ticket_id) as total_assigned,
    COUNT(DISTINCT CASE WHEN ts.code IN ('RESOLVED', 'CLOSED') THEN t.ticket_id END) as resolved_tickets,
    COUNT(DISTINCT CASE WHEN ts.is_open = TRUE THEN t.ticket_id END) as currently_open,
    AVG(EXTRACT(EPOCH FROM (t.resolved_at - t.created_at))/3600) FILTER (WHERE t.resolved_at IS NOT NULL) as avg_resolution_hours,
    AVG(t.customer_satisfaction_score) FILTER (WHERE t.customer_satisfaction_score IS NOT NULL) as avg_satisfaction_score
FROM support.tickets t
LEFT JOIN identity.employees e ON e.employee_id = t.assigned_to_employee_id
LEFT JOIN identity.persons p ON p.person_id = e.person_id
JOIN support.ticket_status_lookup ts ON ts.ticket_status_id = t.ticket_status_id
GROUP BY e.employee_id, p.first_name, p.last_name
ORDER BY resolved_tickets DESC NULLS LAST;

-- View 8: SLA Compliance Report
CREATE VIEW reports.vw_sla_compliance AS
SELECT 
    sp.policy_name,
    COUNT(DISTINCT st.ticket_id) as total_tracked,
    COUNT(DISTINCT CASE WHEN st.first_response_met = TRUE THEN st.ticket_id END) as first_response_met_count,
    COUNT(DISTINCT CASE WHEN st.first_response_met = FALSE THEN st.ticket_id END) as first_response_breached,
    COUNT(DISTINCT CASE WHEN st.resolution_met = TRUE THEN st.ticket_id END) as resolution_met_count,
    COUNT(DISTINCT CASE WHEN st.resolution_met = FALSE THEN st.ticket_id END) as resolution_breached,
    ROUND(
        (COUNT(DISTINCT CASE WHEN st.resolution_met = TRUE THEN st.ticket_id END)::numeric / 
         NULLIF(COUNT(DISTINCT st.ticket_id), 0) * 100), 2
    ) as sla_compliance_percent
FROM support.sla_tracking st
JOIN support.sla_policies sp ON sp.sla_policy_id = st.sla_policy_id
GROUP BY sp.sla_policy_id, sp.policy_name
ORDER BY sla_compliance_percent DESC NULLS LAST;

-- View 9: Complaint Summary
CREATE VIEW reports.vw_complaint_summary AS
SELECT 
    DATE(comp.received_at) as complaint_date,
    crc.code as root_cause,
    cres.code as resolution,
    comp.severity,
    comp.status,
    COUNT(DISTINCT comp.complaint_id) as complaint_count
FROM support.complaints comp
LEFT JOIN support.complaint_root_cause_lookup crc ON crc.complaint_root_cause_id = comp.complaint_root_cause_id
LEFT JOIN support.complaint_resolution_lookup cres ON cres.complaint_resolution_id = comp.complaint_resolution_id
GROUP BY DATE(comp.received_at), crc.code, cres.code, comp.severity, comp.status
ORDER BY complaint_date DESC;

-- View 10: Customer Satisfaction Report
CREATE VIEW reports.vw_customer_satisfaction AS
SELECT 
    DATE(css.submitted_at) as survey_date,
    css.survey_type,
    COUNT(DISTINCT css.satisfaction_survey_id) as total_surveys,
    AVG(css.overall_score) as avg_overall_score,
    AVG(css.product_quality_score) as avg_product_score,
    AVG(css.delivery_score) as avg_delivery_score,
    AVG(css.service_score) as avg_service_score,
    COUNT(DISTINCT CASE WHEN css.would_recommend = TRUE THEN css.satisfaction_survey_id END) as would_recommend_count
FROM support.customer_satisfaction_surveys css
WHERE css.submitted_at IS NOT NULL
GROUP BY DATE(css.submitted_at), css.survey_type
ORDER BY survey_date DESC;

-- View 11: Knowledge Base Performance
CREATE VIEW reports.vw_knowledge_base_performance AS
SELECT 
    kbc.name as category_name,
    COUNT(DISTINCT kba.knowledge_base_article_id) as article_count,
    SUM(kba.view_count) as total_views,
    SUM(kba.helpful_count) as total_helpful,
    SUM(kba.not_helpful_count) as total_not_helpful,
    ROUND(
        (SUM(kba.helpful_count)::numeric / 
         NULLIF(SUM(kba.helpful_count) + SUM(kba.not_helpful_count), 0) * 100), 2
    ) as helpfulness_percent
FROM support.knowledge_base_articles kba
JOIN support.knowledge_base_categories kbc ON kbc.knowledge_base_category_id = kba.knowledge_base_category_id
WHERE kba.status = 'PUBLISHED'
GROUP BY kbc.knowledge_base_category_id, kbc.name
ORDER BY total_views DESC NULLS LAST;

-- View 12: Sales Team Performance
CREATE VIEW reports.vw_sales_team_performance AS
SELECT 
    st.team_name,
    COUNT(DISTINCT stm.employee_id) as team_size,
    COUNT(DISTINCT o.customer_opportunity_id) as total_opportunities,
    SUM(COALESCE(o.estimated_value, 0)) as total_pipeline_value,
    COUNT(DISTINCT CASE WHEN os.code = 'WON' THEN o.customer_opportunity_id END) as won_count,
    SUM(CASE WHEN os.code = 'WON' THEN COALESCE(o.estimated_value, 0) ELSE 0 END) as won_value
FROM crm.customer_sales_teams st
LEFT JOIN crm.customer_sales_team_members stm ON stm.customer_sales_team_id = st.customer_sales_team_id AND stm.is_active = TRUE
LEFT JOIN crm.customer_opportunities o ON o.assigned_to_employee_id = stm.employee_id
LEFT JOIN crm.customer_opportunity_status_lookup os ON os.customer_opportunity_status_id = o.customer_opportunity_status_id
WHERE st.is_active = TRUE
GROUP BY st.customer_sales_team_id, st.team_name
ORDER BY total_pipeline_value DESC NULLS LAST;

-- View 13: Lead Source Effectiveness
CREATE VIEW reports.vw_lead_source_effectiveness AS
SELECT 
    ls.code as source_code,
    ls.name as source_name,
    COUNT(DISTINCT l.customer_lead_id) as total_leads,
    COUNT(DISTINCT CASE WHEN lst.code = 'WON' THEN l.customer_lead_id END) as converted_leads,
    ROUND(
        (COUNT(DISTINCT CASE WHEN lst.code = 'WON' THEN l.customer_lead_id END)::numeric / 
         NULLIF(COUNT(DISTINCT l.customer_lead_id), 0) * 100), 2
    ) as conversion_rate_percent,
    SUM(COALESCE(l.estimated_value, 0)) as total_value
FROM crm.customer_lead_source_lookup ls
LEFT JOIN crm.customer_leads l ON l.customer_lead_source_id = ls.customer_lead_source_id AND l.is_active = TRUE
LEFT JOIN crm.customer_lead_status_lookup lst ON lst.customer_lead_status_id = l.customer_lead_status_id
GROUP BY ls.customer_lead_source_id, ls.code, ls.name
ORDER BY conversion_rate_percent DESC NULLS LAST;

-- View 14: Ticket Category Analysis
CREATE VIEW reports.vw_ticket_category_analysis AS
SELECT 
    tc.code as category_code,
    tc.name as category_name,
    COUNT(DISTINCT t.ticket_id) as total_tickets,
    COUNT(DISTINCT CASE WHEN ts.is_open = TRUE THEN t.ticket_id END) as open_tickets,
    AVG(EXTRACT(EPOCH FROM (t.resolved_at - t.created_at))/3600) FILTER (WHERE t.resolved_at IS NOT NULL) as avg_resolution_hours,
    AVG(t.customer_satisfaction_score) FILTER (WHERE t.customer_satisfaction_score IS NOT NULL) as avg_satisfaction
FROM support.ticket_category_lookup tc
LEFT JOIN support.tickets t ON t.ticket_category_id = tc.ticket_category_id
LEFT JOIN support.ticket_status_lookup ts ON ts.ticket_status_id = t.ticket_status_id
GROUP BY tc.ticket_category_id, tc.code, tc.name
ORDER BY total_tickets DESC NULLS LAST;

-- View 15: Opportunity Stage History
CREATE VIEW reports.vw_opportunity_stage_history AS
SELECT 
    o.opportunity_number,
    o.opportunity_name,
    c.display_name as customer_name,
    from_stage.name as from_stage,
    to_stage.name as to_stage,
    osh.changed_at,
    osh.notes
FROM crm.customer_opportunity_stage_history osh
JOIN crm.customer_opportunities o ON o.customer_opportunity_id = osh.customer_opportunity_id
JOIN crm.customers c ON c.customer_id = o.customer_id
LEFT JOIN crm.customer_pipeline_stage_lookup from_stage ON from_stage.customer_pipeline_stage_id = osh.from_stage_id
JOIN crm.customer_pipeline_stage_lookup to_stage ON to_stage.customer_pipeline_stage_id = osh.to_stage_id
ORDER BY osh.changed_at DESC;

-- View 16: Support Team Workload
CREATE VIEW reports.vw_support_team_workload AS
SELECT 
    st.team_name,
    COUNT(DISTINCT stm.employee_id) as team_size,
    COUNT(DISTINCT t.ticket_id) as total_assigned_tickets,
    COUNT(DISTINCT CASE WHEN ts.is_open = TRUE THEN t.ticket_id END) as open_tickets,
    COUNT(DISTINCT CASE WHEN ts.code = 'ESCALATED' THEN t.ticket_id END) as escalated_tickets
FROM support.support_teams st
LEFT JOIN support.support_team_members stm ON stm.support_team_id = st.support_team_id AND stm.is_active = TRUE
LEFT JOIN support.tickets t ON t.assigned_team_id = st.support_team_id
LEFT JOIN support.ticket_status_lookup ts ON ts.ticket_status_id = t.ticket_status_id
WHERE st.is_active = TRUE
GROUP BY st.support_team_id, st.team_name
ORDER BY open_tickets DESC NULLS LAST;

-- View 17: Complaint Resolution Analysis
CREATE VIEW reports.vw_complaint_resolution_analysis AS
SELECT 
    crc.code as root_cause_code,
    crc.name as root_cause_name,
    COUNT(DISTINCT comp.complaint_id) as total_complaints,
    COUNT(DISTINCT CASE WHEN comp.status IN ('RESOLVED', 'CLOSED') THEN comp.complaint_id END) as resolved_complaints,
    AVG(EXTRACT(EPOCH FROM (comp.resolved_at - comp.received_at))/3600) FILTER (WHERE comp.resolved_at IS NOT NULL) as avg_resolution_hours
FROM support.complaint_root_cause_lookup crc
LEFT JOIN support.complaints comp ON comp.complaint_root_cause_id = crc.complaint_root_cause_id
GROUP BY crc.complaint_root_cause_id, crc.code, crc.name
ORDER BY total_complaints DESC NULLS LAST;

-- View 18: Customer 360 Support Summary
CREATE VIEW reports.vw_customer_360_support AS
SELECT 
    c.customer_id,
    c.customer_number,
    c.display_name,
    COUNT(DISTINCT t.ticket_id) as total_tickets,
    COUNT(DISTINCT CASE WHEN ts.is_open = TRUE THEN t.ticket_id END) as open_tickets,
    COUNT(DISTINCT comp.complaint_id) as total_complaints,
    COUNT(DISTINCT CASE WHEN comp.status IN ('OPEN', 'ACKNOWLEDGED', 'INVESTIGATING') THEN comp.complaint_id END) as open_complaints,
    AVG(t.customer_satisfaction_score) FILTER (WHERE t.customer_satisfaction_score IS NOT NULL) as avg_satisfaction
FROM crm.customers c
LEFT JOIN support.tickets t ON t.customer_id = c.customer_id
LEFT JOIN support.ticket_status_lookup ts ON ts.ticket_status_id = t.ticket_status_id
LEFT JOIN support.complaints comp ON comp.customer_id = c.customer_id
WHERE c.is_active = TRUE
GROUP BY c.customer_id, c.customer_number, c.display_name
ORDER BY total_tickets DESC NULLS LAST;

-- Function 1: Get Pipeline Value by Date Range
CREATE OR REPLACE FUNCTION reports.get_pipeline_value(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stage_name VARCHAR,
    opportunity_count BIGINT,
    total_value NUMERIC,
    weighted_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ps.name::VARCHAR,
        COUNT(DISTINCT o.customer_opportunity_id),
        SUM(COALESCE(o.estimated_value, 0)),
        SUM(COALESCE(o.estimated_value, 0) * ps.probability_percent / 100)
    FROM crm.customer_opportunities o
    JOIN crm.customer_pipeline_stage_lookup ps ON ps.customer_pipeline_stage_id = o.customer_pipeline_stage_id
    WHERE o.company_id = p_company_id
      AND o.created_at::DATE BETWEEN p_start_date AND p_end_date
    GROUP BY ps.name, ps.stage_order
    ORDER BY ps.stage_order;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Customer Ticket History
CREATE OR REPLACE FUNCTION reports.get_customer_ticket_history(
    p_customer_id UUID
)
RETURNS TABLE (
    ticket_number VARCHAR,
    subject VARCHAR,
    category VARCHAR,
    priority VARCHAR,
    status VARCHAR,
    created_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.ticket_number::VARCHAR,
        t.subject::VARCHAR,
        tc.name::VARCHAR,
        tp.name::VARCHAR,
        ts.name::VARCHAR,
        t.created_at,
        t.resolved_at
    FROM support.tickets t
    JOIN support.ticket_category_lookup tc ON tc.ticket_category_id = t.ticket_category_id
    JOIN support.ticket_priority_lookup tp ON tp.ticket_priority_id = t.ticket_priority_id
    JOIN support.ticket_status_lookup ts ON ts.ticket_status_id = t.ticket_status_id
    WHERE t.customer_id = p_customer_id
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;