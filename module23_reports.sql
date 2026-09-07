BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 23: SEO & SEARCH ENGINE OPTIMIZATION REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: SEO Entity Coverage Report
CREATE VIEW reports.vw_seo_entity_coverage AS
SELECT
    set.code as entity_type,
    set.name as entity_type_name,
    COUNT(DISTINCT se.seo_entity_id) as total_entities,
    COUNT(DISTINCT CASE WHEN sm.meta_title IS NOT NULL THEN se.seo_entity_id END) as with_meta_title,
    COUNT(DISTINCT CASE WHEN sm.meta_description IS NOT NULL THEN se.seo_entity_id END) as with_meta_description,
    COUNT(DISTINCT CASE WHEN sm.canonical_url IS NOT NULL THEN se.seo_entity_id END) as with_canonical,
    COUNT(DISTINCT CASE WHEN sm.og_title IS NOT NULL THEN se.seo_entity_id END) as with_og_tags,
    ROUND((COUNT(DISTINCT CASE WHEN sm.meta_title IS NOT NULL THEN se.seo_entity_id END)::numeric /
           NULLIF(COUNT(DISTINCT se.seo_entity_id), 0) * 100), 2) as coverage_percent
FROM seo.seo_entity_type_lookup set
LEFT JOIN seo.seo_entities se ON se.seo_entity_type_id = set.seo_entity_type_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
GROUP BY set.seo_entity_type_id, set.code, set.name, set.sort_order
ORDER BY set.sort_order;

-- View 2: SEO Metadata Completeness Report
CREATE VIEW reports.vw_seo_metadata_completeness AS
SELECT
    se.seo_entity_id,
    se.entity_url,
    set.name as entity_type,
    sm.meta_title,
    sm.meta_description,
    sm.canonical_url,
    sm.og_title,
    sm.twitter_card,
    CASE WHEN sm.meta_title IS NOT NULL THEN TRUE ELSE FALSE END as has_meta_title,
    CASE WHEN sm.meta_description IS NOT NULL THEN TRUE ELSE FALSE END as has_meta_description,
    CASE WHEN sm.canonical_url IS NOT NULL THEN TRUE ELSE FALSE END as has_canonical,
    CASE WHEN sm.og_title IS NOT NULL THEN TRUE ELSE FALSE END as has_og_tags,
    CASE WHEN sm.twitter_card IS NOT NULL THEN TRUE ELSE FALSE END as has_twitter_card,
    se.seo_score
FROM seo.seo_entities se
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
WHERE se.is_active = TRUE
ORDER BY se.seo_score ASC NULLS LAST;

-- View 3: SEO Score Report
CREATE VIEW reports.vw_seo_score_report AS
SELECT
    set.code as entity_type,
    set.name as entity_type_name,
    COUNT(DISTINCT se.seo_entity_id) as entity_count,
    AVG(se.seo_score) as avg_seo_score,
    MIN(se.seo_score) as min_seo_score,
    MAX(se.seo_score) as max_seo_score,
    COUNT(DISTINCT CASE WHEN se.seo_score >= 90 THEN se.seo_entity_id END) as excellent_count,
    COUNT(DISTINCT CASE WHEN se.seo_score >= 70 AND se.seo_score < 90 THEN se.seo_entity_id END) as good_count,
    COUNT(DISTINCT CASE WHEN se.seo_score >= 50 AND se.seo_score < 70 THEN se.seo_entity_id END) as average_count,
    COUNT(DISTINCT CASE WHEN se.seo_score < 50 THEN se.seo_entity_id END) as poor_count
FROM seo.seo_entity_type_lookup set
LEFT JOIN seo.seo_entities se ON se.seo_entity_type_id = set.seo_entity_type_id AND se.seo_score IS NOT NULL
GROUP BY set.seo_entity_type_id, set.code, set.name, set.sort_order
ORDER BY set.sort_order;

-- View 4: SEO Audit Issues Report
CREATE VIEW reports.vw_seo_audit_issues AS
SELECT
    sa.audit_name,
    sa.started_at,
    sa.completed_at,
    se.entity_url,
    set.name as entity_type,
    sit.name as issue_type,
    sis.name as severity,
    sai.issue_message,
    sai.recommendation,
    sai.is_resolved,
    sai.resolved_at
FROM seo.seo_audit_issues sai
JOIN seo.seo_audits sa ON sa.seo_audit_id = sai.seo_audit_id
JOIN seo.seo_entities se ON se.seo_entity_id = sai.seo_entity_id
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
JOIN seo.seo_issue_type_lookup sit ON sit.seo_issue_type_id = sai.seo_issue_type_id
JOIN seo.seo_issue_severity_lookup sis ON sis.seo_issue_severity_id = sai.seo_issue_severity_id
ORDER BY
    CASE sis.code
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        WHEN 'LOW' THEN 4
        ELSE 5
    END,
    sai.created_at DESC;

-- View 5: Redirect Report
CREATE VIEW reports.vw_seo_redirect_report AS
SELECT
    sr.source_path,
    sr.target_path,
    sr.redirect_type,
    rs.code as redirect_status,
    sr.is_regex,
    sr.hit_count,
    sr.last_hit_at,
    sr.start_date,
    sr.end_date,
    s.site_name
FROM seo.seo_redirects sr
JOIN seo.redirect_status_lookup rs ON rs.redirect_status_id = sr.redirect_status_id
LEFT JOIN cms.sites s ON s.site_id = sr.site_id
ORDER BY sr.hit_count DESC;

-- View 6: Redirect Chain Report
CREATE VIEW reports.vw_redirect_chain_report AS
SELECT
    r1.source_path as chain_start,
    r1.target_path as chain_end,
    r1.redirect_type as first_redirect_type,
    r2.redirect_type as second_redirect_type,
    CASE
        WHEN r2.redirect_type IS NOT NULL THEN TRUE
        ELSE FALSE
    END as is_chain,
    CASE
        WHEN r1.source_path = r2.target_path THEN TRUE
        ELSE FALSE
    END as is_loop
FROM seo.seo_redirects r1
LEFT JOIN seo.seo_redirects r2 ON r2.source_path = r1.target_path AND r2.company_id = r1.company_id
WHERE r1.is_active = TRUE
ORDER BY is_chain DESC, is_loop DESC;

-- View 7: Sitemap Coverage Report
CREATE VIEW reports.vw_sitemap_coverage AS
SELECT
    st.code as sitemap_type,
    st.name as sitemap_name,
    ss.sitemap_url,
    ss.entry_count,
    ss.last_generated_at,
    ss.generation_frequency,
    ss.is_enabled
FROM seo.seo_sitemaps ss
JOIN seo.sitemap_type_lookup st ON st.sitemap_type_id = ss.sitemap_type_id
ORDER BY st.sort_order;

-- View 8: Structured Data Coverage Report
CREATE VIEW reports.vw_structured_data_coverage AS
SELECT
    set.name as entity_type,
    sdt.name as structured_data_type,
    sdt.schema_org_type,
    COUNT(DISTINCT ssd.seo_structured_data_id) as entity_count,
    COUNT(DISTINCT CASE WHEN ssd.is_enabled = TRUE THEN ssd.seo_structured_data_id END) as enabled_count
FROM seo.structured_data_type_lookup sdt
LEFT JOIN seo.seo_structured_data ssd ON ssd.structured_data_type_id = sdt.structured_data_type_id
LEFT JOIN seo.seo_entities se ON se.seo_entity_id = ssd.seo_entity_id
LEFT JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
GROUP BY sdt.structured_data_type_id, sdt.name, sdt.schema_org_type, set.name
ORDER BY sdt.sort_order;

-- View 9: Open Graph Coverage Report
CREATE VIEW reports.vw_open_graph_coverage AS
SELECT
    set.name as entity_type,
    COUNT(DISTINCT se.seo_entity_id) as total_entities,
    COUNT(DISTINCT CASE WHEN sm.og_title IS NOT NULL THEN se.seo_entity_id END) as with_og_title,
    COUNT(DISTINCT CASE WHEN sm.og_description IS NOT NULL THEN se.seo_entity_id END) as with_og_description,
    COUNT(DISTINCT CASE WHEN sm.og_image_url IS NOT NULL THEN se.seo_entity_id END) as with_og_image,
    ROUND((COUNT(DISTINCT CASE WHEN sm.og_title IS NOT NULL THEN se.seo_entity_id END)::numeric /
           NULLIF(COUNT(DISTINCT se.seo_entity_id), 0) * 100), 2) as og_coverage_percent
FROM seo.seo_entity_type_lookup set
LEFT JOIN seo.seo_entities se ON se.seo_entity_type_id = set.seo_entity_type_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
GROUP BY set.seo_entity_type_id, set.name, set.sort_order
ORDER BY set.sort_order;

-- View 10: Twitter Card Coverage Report
CREATE VIEW reports.vw_twitter_card_coverage AS
SELECT
    set.name as entity_type,
    COUNT(DISTINCT se.seo_entity_id) as total_entities,
    COUNT(DISTINCT CASE WHEN sm.twitter_card IS NOT NULL THEN se.seo_entity_id END) as with_twitter_card,
    COUNT(DISTINCT CASE WHEN sm.twitter_title IS NOT NULL THEN se.seo_entity_id END) as with_twitter_title,
    COUNT(DISTINCT CASE WHEN sm.twitter_image_url IS NOT NULL THEN se.seo_entity_id END) as with_twitter_image,
    ROUND((COUNT(DISTINCT CASE WHEN sm.twitter_card IS NOT NULL THEN se.seo_entity_id END)::numeric /
           NULLIF(COUNT(DISTINCT se.seo_entity_id), 0) * 100), 2) as twitter_coverage_percent
FROM seo.seo_entity_type_lookup set
LEFT JOIN seo.seo_entities se ON se.seo_entity_type_id = set.seo_entity_type_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
GROUP BY set.seo_entity_type_id, set.name, set.sort_order
ORDER BY set.sort_order;

-- View 11: Image SEO Report
CREATE VIEW reports.vw_image_seo_report AS
SELECT
    set.name as entity_type,
    sim.image_url,
    sim.alt_text,
    sim.title,
    sim.caption,
    sim.is_decorative,
    CASE
        WHEN sim.is_decorative = TRUE THEN 'DECORATIVE'
        WHEN sim.alt_text IS NOT NULL AND sim.alt_text <> '' THEN 'HAS_ALT'
        ELSE 'MISSING_ALT'
    END as alt_status
FROM seo.seo_image_metadata sim
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = sim.seo_entity_type_id
ORDER BY
    CASE
        WHEN sim.is_decorative = TRUE THEN 3
        WHEN sim.alt_text IS NOT NULL AND sim.alt_text <> '' THEN 2
        ELSE 1
    END;

-- View 12: Internal Linking Report
CREATE VIEW reports.vw_internal_linking_report AS
SELECT
    source_set.name as source_entity_type,
    target_set.name as target_entity_type,
    COUNT(DISTINCT sil.seo_internal_link_id) as link_count,
    SUM(sil.click_count) as total_clicks,
    MAX(sil.last_clicked_at) as last_clicked_at
FROM seo.seo_internal_links sil
JOIN seo.seo_entity_type_lookup source_set ON source_set.seo_entity_type_id = sil.source_entity_type_id
JOIN seo.seo_entity_type_lookup target_set ON target_set.seo_entity_type_id = sil.target_entity_type_id
GROUP BY source_set.name, target_set.name
ORDER BY link_count DESC;

-- View 13: Keyword Coverage Report
CREATE VIEW reports.vw_keyword_coverage AS
SELECT
    sk.keyword,
    sk.keyword_group,
    sk.search_volume,
    sk.difficulty_score,
    sk.is_primary,
    COUNT(DISTINCT sek.seo_entity_id) as entity_count,
    ROUND(AVG(sek.relevance_score), 2) as avg_relevance_score
FROM seo.seo_keywords sk
LEFT JOIN seo.seo_entity_keywords sek ON sek.seo_keyword_id = sk.seo_keyword_id
WHERE sk.is_active = TRUE
GROUP BY sk.seo_keyword_id, sk.keyword, sk.keyword_group, sk.search_volume, sk.difficulty_score, sk.is_primary
ORDER BY sk.search_volume DESC NULLS LAST;

-- View 14: SEO Analytics Report
CREATE VIEW reports.vw_seo_analytics_report AS
SELECT
    sa.stat_date,
    set.name as entity_type,
    SUM(sa.search_impressions) as total_impressions,
    SUM(sa.search_clicks) as total_clicks,
    AVG(sa.average_position) as avg_position,
    SUM(sa.organic_traffic) as total_organic_traffic,
    ROUND((SUM(sa.search_clicks)::numeric / NULLIF(SUM(sa.search_impressions), 0) * 100), 2) as ctr_percent
FROM seo.seo_analytics sa
JOIN seo.seo_entities se ON se.seo_entity_id = sa.seo_entity_id
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
GROUP BY sa.stat_date, set.name
ORDER BY sa.stat_date DESC;

-- View 15: Page SEO Performance Report
CREATE VIEW reports.vw_page_seo_performance AS
SELECT
    se.entity_url,
    se.seo_score,
    sm.meta_title,
    sm.meta_description,
    sa.search_impressions,
    sa.search_clicks,
    sa.average_position,
    sa.organic_traffic
FROM seo.seo_entities se
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
LEFT JOIN LATERAL (
    SELECT
        SUM(sa.search_impressions) as search_impressions,
        SUM(sa.search_clicks) as search_clicks,
        AVG(sa.average_position) as average_position,
        SUM(sa.organic_traffic) as organic_traffic
    FROM seo.seo_analytics sa
    WHERE sa.seo_entity_id = se.seo_entity_id
      AND sa.stat_date >= CURRENT_DATE - INTERVAL '30 days'
) sa ON TRUE
WHERE set.code = 'PAGE'
ORDER BY se.seo_score DESC NULLS LAST;

-- View 16: Product SEO Performance Report
CREATE VIEW reports.vw_product_seo_performance AS
SELECT
    p.product_code,
    p.product_name,
    se.seo_score,
    sm.meta_title,
    sm.meta_description,
    sa.search_impressions,
    sa.search_clicks,
    sa.average_position,
    sa.organic_traffic
FROM seo.seo_entities se
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
JOIN catalog.products p ON p.product_id = se.entity_reference_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
LEFT JOIN LATERAL (
    SELECT
        SUM(sa.search_impressions) as search_impressions,
        SUM(sa.search_clicks) as search_clicks,
        AVG(sa.average_position) as average_position,
        SUM(sa.organic_traffic) as organic_traffic
    FROM seo.seo_analytics sa
    WHERE sa.seo_entity_id = se.seo_entity_id
      AND sa.stat_date >= CURRENT_DATE - INTERVAL '30 days'
) sa ON TRUE
WHERE set.code = 'PRODUCT'
ORDER BY se.seo_score DESC NULLS LAST;

-- View 17: Blog SEO Performance Report
CREATE VIEW reports.vw_blog_seo_performance AS
SELECT
    bp.post_number,
    bp.title,
    bp.slug,
    se.seo_score,
    sm.meta_title,
    sm.meta_description,
    sa.search_impressions,
    sa.search_clicks,
    sa.average_position,
    sa.organic_traffic
FROM seo.seo_entities se
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
JOIN blog.blog_posts bp ON bp.blog_post_id = se.entity_reference_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
LEFT JOIN LATERAL (
    SELECT
        SUM(sa.search_impressions) as search_impressions,
        SUM(sa.search_clicks) as search_clicks,
        AVG(sa.average_position) as average_position,
        SUM(sa.organic_traffic) as organic_traffic
    FROM seo.seo_analytics sa
    WHERE sa.seo_entity_id = se.seo_entity_id
      AND sa.stat_date >= CURRENT_DATE - INTERVAL '30 days'
) sa ON TRUE
WHERE set.code = 'BLOG_POST'
ORDER BY se.seo_score DESC NULLS LAST;

-- View 18: Category SEO Performance Report
CREATE VIEW reports.vw_category_seo_performance AS
SELECT
    c.category_code,
    c.category_name,
    c.slug,
    se.seo_score,
    sm.meta_title,
    sm.meta_description,
    sa.search_impressions,
    sa.search_clicks,
    sa.average_position,
    sa.organic_traffic
FROM seo.seo_entities se
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
JOIN catalog.categories c ON c.category_id = se.entity_reference_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
LEFT JOIN LATERAL (
    SELECT
        SUM(sa.search_impressions) as search_impressions,
        SUM(sa.search_clicks) as search_clicks,
        AVG(sa.average_position) as average_position,
        SUM(sa.organic_traffic) as organic_traffic
    FROM seo.seo_analytics sa
    WHERE sa.seo_entity_id = se.seo_entity_id
      AND sa.stat_date >= CURRENT_DATE - INTERVAL '30 days'
) sa ON TRUE
WHERE set.code = 'CATEGORY'
ORDER BY se.seo_score DESC NULLS LAST;

-- View 19: SEO Freshness Report
CREATE VIEW reports.vw_seo_freshness_report AS
SELECT
    se.entity_url,
    set.name as entity_type,
    se.seo_score,
    se.last_audited_at,
    se.last_updated_at,
    CURRENT_DATE - se.last_audited_at::DATE as days_since_audit,
    CURRENT_DATE - se.last_updated_at::DATE as days_since_update,
    CASE
        WHEN CURRENT_DATE - se.last_audited_at::DATE <= 30 THEN 'FRESH'
        WHEN CURRENT_DATE - se.last_audited_at::DATE <= 90 THEN 'RECENT'
        ELSE 'STALE'
    END as freshness_status
FROM seo.seo_entities se
JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
WHERE se.is_active = TRUE
ORDER BY days_since_audit DESC NULLS LAST;

-- View 20: SEO Health Report
CREATE VIEW reports.vw_seo_health_report AS
SELECT
    s.site_name,
    COUNT(DISTINCT se.seo_entity_id) as total_entities,
    COUNT(DISTINCT CASE WHEN se.seo_score >= 90 THEN se.seo_entity_id END) as excellent_score_entities,
    COUNT(DISTINCT CASE WHEN se.seo_score < 50 THEN se.seo_entity_id END) as poor_score_entities,
    AVG(se.seo_score) as avg_seo_score,
    COUNT(DISTINCT CASE WHEN sm.meta_title IS NULL THEN se.seo_entity_id END) as missing_meta_title,
    COUNT(DISTINCT CASE WHEN sm.meta_description IS NULL THEN se.seo_entity_id END) as missing_meta_description,
    COUNT(DISTINCT ssd.seo_structured_data_id) as structured_data_count,
    COUNT(DISTINCT sr.seo_redirect_id) as redirect_count,
    COUNT(DISTINCT CASE WHEN sai.is_resolved = FALSE THEN sai.seo_audit_issue_id END) as unresolved_issues
FROM cms.sites s
LEFT JOIN seo.seo_entities se ON se.site_id = s.site_id
LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
LEFT JOIN seo.seo_structured_data ssd ON ssd.seo_entity_id = se.seo_entity_id
LEFT JOIN seo.seo_redirects sr ON sr.site_id = s.site_id
LEFT JOIN seo.seo_audit_issues sai ON sai.seo_entity_id = se.seo_entity_id
GROUP BY s.site_id, s.site_name
ORDER BY avg_seo_score DESC NULLS LAST;

-- Function 1: Get SEO Entity Details
CREATE OR REPLACE FUNCTION reports.get_seo_entity_details(
    p_seo_entity_id UUID
)
RETURNS TABLE (
    entity_url VARCHAR,
    entity_type VARCHAR,
    seo_score INTEGER,
    meta_title VARCHAR,
    meta_description TEXT,
    canonical_url VARCHAR,
    og_title VARCHAR,
    twitter_card VARCHAR,
    structured_data_count BIGINT,
    keyword_count BIGINT,
    internal_link_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        se.entity_url::VARCHAR,
        set.name::VARCHAR,
        se.seo_score,
        sm.meta_title::VARCHAR,
        sm.meta_description,
        sm.canonical_url::VARCHAR,
        sm.og_title::VARCHAR,
        sm.twitter_card::VARCHAR,
        COUNT(DISTINCT ssd.seo_structured_data_id),
        COUNT(DISTINCT sek.seo_entity_keyword_id),
        COUNT(DISTINCT sil.seo_internal_link_id)
    FROM seo.seo_entities se
    JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
    LEFT JOIN seo.seo_metadata sm ON sm.seo_entity_id = se.seo_entity_id
    LEFT JOIN seo.seo_structured_data ssd ON ssd.seo_entity_id = se.seo_entity_id
    LEFT JOIN seo.seo_entity_keywords sek ON sek.seo_entity_id = se.seo_entity_id
    LEFT JOIN seo.seo_internal_links sil ON sil.source_entity_id = se.seo_entity_id OR sil.target_entity_id = se.seo_entity_id
    WHERE se.seo_entity_id = p_seo_entity_id
    GROUP BY se.seo_entity_id, se.entity_url, set.name, se.seo_score, sm.meta_title, sm.meta_description, sm.canonical_url, sm.og_title, sm.twitter_card;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get SEO Analytics by Date Range
CREATE OR REPLACE FUNCTION reports.get_seo_analytics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_date DATE,
    entity_type VARCHAR,
    total_impressions BIGINT,
    total_clicks BIGINT,
    avg_position NUMERIC,
    total_organic_traffic BIGINT,
    ctr_percent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sa.stat_date,
        set.name::VARCHAR,
        SUM(sa.search_impressions)::BIGINT,
        SUM(sa.search_clicks)::BIGINT,
        ROUND(AVG(sa.average_position), 2),
        SUM(sa.organic_traffic)::BIGINT,
        ROUND((SUM(sa.search_clicks)::numeric / NULLIF(SUM(sa.search_impressions), 0) * 100), 2)
    FROM seo.seo_analytics sa
    JOIN seo.seo_entities se ON se.seo_entity_id = sa.seo_entity_id
    JOIN seo.seo_entity_type_lookup set ON set.seo_entity_type_id = se.seo_entity_type_id
    WHERE se.company_id = p_company_id
      AND sa.stat_date BETWEEN p_start_date AND p_end_date
    GROUP BY sa.stat_date, set.name
    ORDER BY sa.stat_date;
END;
$$ LANGUAGE plpgsql;

COMMIT;