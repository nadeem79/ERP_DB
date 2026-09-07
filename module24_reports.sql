BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 24: SEARCH & DISCOVERY REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Search Query Volume Report
CREATE VIEW reports.vw_search_query_volume AS
SELECT
    DATE(sql.searched_at) as search_date,
    COUNT(DISTINCT sql.search_query_log_id) as total_searches,
    COUNT(DISTINCT sql.query_hash) as unique_queries,
    COUNT(DISTINCT CASE WHEN sqsl.code = 'ZERO_RESULTS' THEN sql.search_query_log_id END) as zero_result_searches,
    COUNT(DISTINCT CASE WHEN sqsl.code = 'ERROR' THEN sql.search_query_log_id END) as error_searches,
    COUNT(DISTINCT CASE WHEN sql.is_autocomplete = TRUE THEN sql.search_query_log_id END) as autocomplete_searches,
    COUNT(DISTINCT CASE WHEN sql.is_admin_search = TRUE THEN sql.search_query_log_id END) as admin_searches,
    AVG(sql.response_time_ms) as avg_response_time_ms,
    AVG(sql.results_count) as avg_results_count
FROM search.search_query_logs sql
JOIN search.search_query_status_lookup sqsl ON sqsl.search_query_status_id = sql.search_query_status_id
GROUP BY DATE(sql.searched_at)
ORDER BY search_date DESC;

-- View 2: Zero-Result Searches Report
CREATE VIEW reports.vw_zero_result_searches AS
SELECT
    szr.query_text,
    szr.normalized_query,
    szr.search_count,
    szr.first_searched_at,
    szr.last_searched_at,
    szr.resolution_status,
    szr.resolution_action,
    szr.resolution_notes,
    szr.resolved_at,
    u.username as resolved_by
FROM search.search_zero_results szr
LEFT JOIN identity.users u ON u.user_id = szr.resolved_by_user_id
ORDER BY szr.search_count DESC, szr.last_searched_at DESC;

-- View 3: Popular Searches Report
CREATE VIEW reports.vw_popular_searches AS
SELECT
    spq.query_text,
    spq.normalized_query,
    spq.search_count,
    spq.click_count,
    spq.conversion_count,
    spq.zero_result_count,
    spq.avg_response_time_ms,
    spq.avg_results_count,
    spq.period_start,
    spq.period_end,
    ROUND((spq.click_count::numeric / NULLIF(spq.search_count, 0) * 100), 2) as ctr_percent,
    ROUND((spq.conversion_count::numeric / NULLIF(spq.click_count, 0) * 100), 2) as conversion_rate_percent
FROM search.search_popular_queries spq
ORDER BY spq.search_count DESC;

-- View 4: Search CTR Report
CREATE VIEW reports.vw_search_ctr_report AS
SELECT
    DATE(sql.searched_at) as search_date,
    COUNT(DISTINCT sql.search_query_log_id) as total_searches,
    COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NOT NULL THEN sql.search_query_log_id END) as searches_with_clicks,
    ROUND((COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NOT NULL THEN sql.search_query_log_id END)::numeric /
           NULLIF(COUNT(DISTINCT sql.search_query_log_id), 0) * 100), 2) as ctr_percent
FROM search.search_query_logs sql
GROUP BY DATE(sql.searched_at)
ORDER BY search_date DESC;

-- View 5: Search Conversion Report
CREATE VIEW reports.vw_search_conversion_report AS
SELECT
    DATE(sa.stat_date) as stat_date,
    set.name as entity_type,
    SUM(sa.total_searches) as total_searches,
    SUM(sa.total_clicks) as total_clicks,
    SUM(sa.total_conversions) as total_conversions,
    SUM(sa.conversion_revenue) as total_conversion_revenue,
    ROUND((SUM(sa.total_clicks)::numeric / NULLIF(SUM(sa.total_searches), 0) * 100), 2) as ctr_percent,
    ROUND((SUM(sa.total_conversions)::numeric / NULLIF(SUM(sa.total_clicks), 0) * 100), 2) as conversion_rate_percent,
    ROUND((SUM(sa.conversion_revenue) / NULLIF(SUM(sa.total_conversions), 0)), 2) as avg_revenue_per_conversion
FROM search.search_analytics sa
LEFT JOIN search.search_entity_type_lookup set ON set.search_entity_type_id = sa.search_entity_type_id
GROUP BY DATE(sa.stat_date), set.name
ORDER BY stat_date DESC;

-- View 6: Search Merchandising Performance
CREATE VIEW reports.vw_search_merchandising_performance AS
SELECT
    sqr.query_pattern,
    sqrt.name as rule_type,
    sqr.priority,
    sqr.is_active,
    sqr.start_date,
    sqr.end_date,
    sqr.boost_weight,
    sqr.pin_position,
    sqr.redirect_url,
    sqr.notes
FROM search.search_query_rules sqr
JOIN search.search_query_rule_type_lookup sqrt ON sqrt.search_query_rule_type_id = sqr.search_query_rule_type_id
ORDER BY sqr.priority DESC, sqr.created_at DESC;

-- View 7: Synonym Effectiveness Report
CREATE VIEW reports.vw_synonym_effectiveness AS
SELECT
    ss.term,
    ss.synonym,
    ss.is_bidirectional,
    ss.usage_count,
    ss.is_active,
    ss.created_at
FROM search.search_synonyms ss
ORDER BY ss.usage_count DESC;

-- View 8: Search Query Rules Report
CREATE VIEW reports.vw_search_query_rules AS
SELECT
    sqr.search_query_rule_id,
    sqr.query_pattern,
    sqrt.code as rule_type_code,
    sqrt.name as rule_type_name,
    sqr.is_exact_match,
    sqr.is_case_sensitive,
    sqr.priority,
    sqr.is_active,
    sqr.start_date,
    sqr.end_date,
    sqr.created_at
FROM search.search_query_rules sqr
JOIN search.search_query_rule_type_lookup sqrt ON sqrt.search_query_rule_type_id = sqr.search_query_rule_type_id
ORDER BY sqr.priority DESC;

-- View 9: Search Index Health Report
CREATE VIEW reports.vw_search_index_health AS
SELECT
    set.code as entity_type,
    set.name as entity_type_name,
    COUNT(DISTINCT si.search_index_id) as total_indexed,
    COUNT(DISTINCT CASE WHEN si.is_active = TRUE THEN si.search_index_id END) as active_indexed,
    COUNT(DISTINCT CASE WHEN si.is_published = TRUE THEN si.search_index_id END) as published_indexed,
    COUNT(DISTINCT CASE WHEN si.is_searchable = TRUE THEN si.search_index_id END) as searchable_indexed,
    MAX(si.indexed_at) as last_indexed_at,
    MAX(si.updated_at) as last_updated_at
FROM search.search_entity_type_lookup set
LEFT JOIN search.search_index si ON si.search_entity_type_id = set.search_entity_type_id
GROUP BY set.search_entity_type_id, set.code, set.name, set.sort_order
ORDER BY set.sort_order;

-- View 10: Search Performance Report
CREATE VIEW reports.vw_search_performance AS
SELECT
    DATE(sql.searched_at) as search_date,
    COUNT(DISTINCT sql.search_query_log_id) as total_searches,
    AVG(sql.response_time_ms) as avg_response_time_ms,
    MIN(sql.response_time_ms) as min_response_time_ms,
    MAX(sql.response_time_ms) as max_response_time_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sql.response_time_ms) as p95_response_time_ms,
    COUNT(DISTINCT CASE WHEN sql.response_time_ms > 1000 THEN sql.search_query_log_id END) as slow_searches
FROM search.search_query_logs sql
GROUP BY DATE(sql.searched_at)
ORDER BY search_date DESC;

-- View 11: Search Entity Coverage Report
CREATE VIEW reports.vw_search_entity_coverage AS
SELECT
    set.code as entity_type,
    set.name as entity_type_name,
    set.is_searchable_public,
    set.is_searchable_admin,
    COUNT(DISTINCT si.search_index_id) as indexed_count,
    COUNT(DISTINCT CASE WHEN si.is_searchable = TRUE THEN si.search_index_id END) as searchable_count
FROM search.search_entity_type_lookup set
LEFT JOIN search.search_index si ON si.search_entity_type_id = set.search_entity_type_id
GROUP BY set.search_entity_type_id, set.code, set.name, set.is_searchable_public, set.is_searchable_admin, set.sort_order
ORDER BY set.sort_order;

-- View 12: Search Traffic Sources Report
CREATE VIEW reports.vw_search_traffic_sources AS
SELECT
    sql.utm_source,
    sql.utm_medium,
    COUNT(DISTINCT sql.search_query_log_id) as search_count,
    COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NOT NULL THEN sql.search_query_log_id END) as click_count,
    AVG(sql.response_time_ms) as avg_response_time_ms
FROM search.search_query_logs sql
WHERE sql.utm_source IS NOT NULL
GROUP BY sql.utm_source, sql.utm_medium
ORDER BY search_count DESC;

-- View 13: Search Abandonment Report
CREATE VIEW reports.vw_search_abandonment AS
SELECT
    DATE(sql.searched_at) as search_date,
    COUNT(DISTINCT sql.search_query_log_id) as total_searches,
    COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NULL THEN sql.search_query_log_id END) as searches_without_click,
    ROUND((COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NULL THEN sql.search_query_log_id END)::numeric /
           NULLIF(COUNT(DISTINCT sql.search_query_log_id), 0) * 100), 2) as abandonment_rate_percent
FROM search.search_query_logs sql
GROUP BY DATE(sql.searched_at)
ORDER BY search_date DESC;

-- View 14: Search Trend Report
CREATE VIEW reports.vw_search_trend AS
SELECT
    DATE_TRUNC('week', sql.searched_at) as week_start,
    COUNT(DISTINCT sql.search_query_log_id) as total_searches,
    COUNT(DISTINCT sql.query_hash) as unique_queries,
    COUNT(DISTINCT sql.customer_id) as unique_customers,
    COUNT(DISTINCT CASE WHEN sqsl.code = 'ZERO_RESULTS' THEN sql.search_query_log_id END) as zero_result_searches,
    AVG(sql.results_count) as avg_results_count
FROM search.search_query_logs sql
JOIN search.search_query_status_lookup sqsl ON sqsl.search_query_status_id = sql.search_query_status_id
GROUP BY DATE_TRUNC('week', sql.searched_at)
ORDER BY week_start DESC;

-- View 15: Search Revenue Attribution
CREATE VIEW reports.vw_search_revenue_attribution AS
SELECT
    DATE(sa.stat_date) as stat_date,
    SUM(sa.total_conversions) as total_conversions,
    SUM(sa.conversion_revenue) as total_revenue,
    ROUND((SUM(sa.conversion_revenue) / NULLIF(SUM(sa.total_conversions), 0)), 2) as avg_revenue_per_conversion,
    ROUND((SUM(sa.conversion_revenue) / NULLIF(SUM(sa.total_searches), 0)), 2) as revenue_per_search
FROM search.search_analytics sa
GROUP BY DATE(sa.stat_date)
ORDER BY stat_date DESC;

-- View 16: Search Facet Usage Report
CREATE VIEW reports.vw_search_facet_usage AS
SELECT
    sfc.facet_code,
    sfc.facet_name,
    set.name as entity_type,
    sft.name as facet_type,
    sfc.is_enabled,
    sfc.is_multi_select,
    sfc.sort_order
FROM search.search_facet_configuration sfc
JOIN search.search_entity_type_lookup set ON set.search_entity_type_id = sfc.search_entity_type_id
JOIN search.search_facet_type_lookup sft ON sft.search_facet_type_id = sfc.search_facet_type_id
ORDER BY set.sort_order, sfc.sort_order;

-- View 17: Search Autocomplete Performance
CREATE VIEW reports.vw_search_autocomplete_performance AS
SELECT
    DATE(sql.searched_at) as search_date,
    COUNT(DISTINCT sql.search_query_log_id) as autocomplete_searches,
    AVG(sql.response_time_ms) as avg_response_time_ms,
    COUNT(DISTINCT CASE WHEN sql.results_count > 0 THEN sql.search_query_log_id END) as with_results,
    COUNT(DISTINCT CASE WHEN sql.results_count = 0 THEN sql.search_query_log_id END) as without_results
FROM search.search_query_logs sql
WHERE sql.is_autocomplete = TRUE
GROUP BY DATE(sql.searched_at)
ORDER BY search_date DESC;

-- View 18: Search Error Report
CREATE VIEW reports.vw_search_error_report AS
SELECT
    DATE(sql.searched_at) as error_date,
    sql.query_text,
    sql.response_time_ms,
    sql.results_count,
    sql.user_agent,
    sql.ip_address
FROM search.search_query_logs sql
JOIN search.search_query_status_lookup sqsl ON sqsl.search_query_status_id = sql.search_query_status_id
WHERE sqsl.code IN ('ERROR', 'TIMEOUT')
ORDER BY sql.searched_at DESC;

-- View 19: Search Session Analysis
CREATE VIEW reports.vw_search_session_analysis AS
SELECT
    sql.session_id,
    COUNT(DISTINCT sql.search_query_log_id) as searches_in_session,
    COUNT(DISTINCT sql.query_hash) as unique_queries_in_session,
    COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NOT NULL THEN sql.search_query_log_id END) as clicks_in_session,
    MIN(sql.searched_at) as session_start,
    MAX(sql.searched_at) as session_end,
    EXTRACT(EPOCH FROM (MAX(sql.searched_at) - MIN(sql.searched_at))) as session_duration_seconds
FROM search.search_query_logs sql
WHERE sql.session_id IS NOT NULL
GROUP BY sql.session_id
HAVING COUNT(DISTINCT sql.search_query_log_id) > 1
ORDER BY searches_in_session DESC;

-- View 20: Search Health Dashboard
CREATE VIEW reports.vw_search_health_dashboard AS
SELECT
    s.company_id,
    c.company_name,
    COUNT(DISTINCT si.search_index_id) as total_indexed_entities,
    COUNT(DISTINCT CASE WHEN si.is_active = TRUE AND si.is_published = TRUE THEN si.search_index_id END) as active_published_entities,
    (SELECT COUNT(*) FROM search.search_query_logs sql WHERE sql.company_id = s.company_id AND sql.searched_at >= CURRENT_DATE - INTERVAL '7 days') as searches_last_7_days,
    (SELECT COUNT(*) FROM search.search_query_logs sql JOIN search.search_query_status_lookup sqsl ON sqsl.search_query_status_id = sql.search_query_status_id WHERE sql.company_id = s.company_id AND sqsl.code = 'ZERO_RESULTS' AND sql.searched_at >= CURRENT_DATE - INTERVAL '7 days') as zero_results_last_7_days,
    (SELECT COUNT(*) FROM search.search_zero_results szr WHERE szr.company_id = s.company_id AND szr.resolution_status = 'UNRESOLVED') as unresolved_zero_results,
    (SELECT COUNT(*) FROM search.search_query_rules sqr WHERE sqr.company_id = s.company_id AND sqr.is_active = TRUE) as active_query_rules,
    (SELECT COUNT(*) FROM search.search_synonyms ss WHERE ss.company_id = s.company_id AND ss.is_active = TRUE) as active_synonyms,
    (SELECT MAX(sij.completed_at) FROM search.search_index_jobs sij WHERE sij.company_id = s.company_id AND sij.search_index_job_status_id = (SELECT search_index_job_status_id FROM search.search_index_job_status_lookup WHERE code = 'COMPLETED')) as last_successful_index_job
FROM organization.companies c
CROSS JOIN LATERAL (SELECT c.company_id) s(company_id)
LEFT JOIN search.search_index si ON si.company_id = s.company_id
GROUP BY s.company_id, c.company_name;

-- Function 1: Get Search Analytics by Date Range
CREATE OR REPLACE FUNCTION reports.get_search_analytics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_date DATE,
    total_searches BIGINT,
    unique_searches BIGINT,
    zero_result_searches BIGINT,
    total_clicks BIGINT,
    total_conversions BIGINT,
    conversion_revenue NUMERIC,
    avg_response_time_ms INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sa.stat_date,
        SUM(sa.total_searches)::BIGINT,
        SUM(sa.unique_searches)::BIGINT,
        SUM(sa.zero_result_searches)::BIGINT,
        SUM(sa.total_clicks)::BIGINT,
        SUM(sa.total_conversions)::BIGINT,
        SUM(sa.conversion_revenue),
        AVG(sa.avg_response_time_ms)::INTEGER
    FROM search.search_analytics sa
    WHERE sa.company_id = p_company_id
      AND sa.stat_date BETWEEN p_start_date AND p_end_date
    GROUP BY sa.stat_date
    ORDER BY sa.stat_date;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Top Search Queries
CREATE OR REPLACE FUNCTION reports.get_top_search_queries(
    p_company_id UUID,
    p_days INTEGER DEFAULT 30,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    query_text VARCHAR,
    search_count BIGINT,
    click_count BIGINT,
    zero_result_count BIGINT,
    ctr_percent NUMERIC,
    avg_response_time_ms INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sql.normalized_query::VARCHAR,
        COUNT(DISTINCT sql.search_query_log_id)::BIGINT,
        COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NOT NULL THEN sql.search_query_log_id END)::BIGINT,
        COUNT(DISTINCT CASE WHEN sqsl.code = 'ZERO_RESULTS' THEN sql.search_query_log_id END)::BIGINT,
        ROUND((COUNT(DISTINCT CASE WHEN sql.clicked_entity_id IS NOT NULL THEN sql.search_query_log_id END)::numeric /
               NULLIF(COUNT(DISTINCT sql.search_query_log_id), 0) * 100), 2),
        AVG(sql.response_time_ms)::INTEGER
    FROM search.search_query_logs sql
    JOIN search.search_query_status_lookup sqsl ON sqsl.search_query_status_id = sql.search_query_status_id
    WHERE sql.company_id = p_company_id
      AND sql.searched_at >= CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    GROUP BY sql.normalized_query
    ORDER BY COUNT(DISTINCT sql.search_query_log_id) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMIT;