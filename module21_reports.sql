BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 21: CMS / WEBSITE PAGES REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Site Overview
CREATE VIEW reports.vw_site_overview AS
SELECT
    s.site_code,
    s.site_name,
    s.primary_domain,
    ssl.code as site_status,
    s.default_language_code,
    s.timezone,
    s.is_default,
    COUNT(DISTINCT p.page_id) as total_pages,
    COUNT(DISTINCT CASE WHEN ps.code = 'PUBLISHED' THEN p.page_id END) as published_pages,
    COUNT(DISTINCT CASE WHEN ps.code = 'DRAFT' THEN p.page_id END) as draft_pages,
    COUNT(DISTINCT m.menu_id) as total_menus,
    COUNT(DISTINCT cb.content_block_id) as total_blocks
FROM cms.sites s
JOIN cms.site_status_lookup ssl ON ssl.site_status_id = s.site_status_id
LEFT JOIN cms.pages p ON p.site_id = s.site_id
LEFT JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
LEFT JOIN cms.menus m ON m.site_id = s.site_id
LEFT JOIN cms.content_blocks cb ON cb.company_id = s.company_id
GROUP BY s.site_id, s.site_code, s.site_name, s.primary_domain, ssl.code, s.default_language_code, s.timezone, s.is_default
ORDER BY s.is_default DESC, s.site_name;

-- View 2: Page Inventory Report
CREATE VIEW reports.vw_page_inventory AS
SELECT
    p.page_code,
    p.page_title,
    p.slug,
    pt.code as page_type,
    ps.code as page_status,
    p.is_homepage,
    p.is_searchable,
    p.current_version,
    p.published_version,
    p.published_at,
    p.scheduled_publish_at,
    p.created_at,
    p.updated_at,
    s.site_name,
    parent.page_title as parent_page_title
FROM cms.pages p
JOIN cms.page_type_lookup pt ON pt.page_type_id = p.page_type_id
JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
JOIN cms.sites s ON s.site_id = p.site_id
LEFT JOIN cms.pages parent ON parent.page_id = p.parent_page_id
ORDER BY p.sort_order, p.page_title;

-- View 3: Page Status Distribution
CREATE VIEW reports.vw_page_status_distribution AS
SELECT
    s.site_name,
    ps.code as page_status,
    ps.name as status_name,
    COUNT(DISTINCT p.page_id) as page_count,
    ROUND((COUNT(DISTINCT p.page_id)::numeric /
           NULLIF((SELECT COUNT(*) FROM cms.pages), 0) * 100), 2) as percent_of_total
FROM cms.page_status_lookup ps
LEFT JOIN cms.pages p ON p.page_status_id = ps.page_status_id
LEFT JOIN cms.sites s ON s.site_id = p.site_id
GROUP BY s.site_name, ps.page_status_id, ps.code, ps.name, ps.sort_order
ORDER BY ps.sort_order;

-- View 4: Content Block Usage Report
CREATE VIEW reports.vw_content_block_usage AS
SELECT
    cb.block_code,
    cb.block_name,
    bt.code as block_type,
    bt.name as block_type_name,
    cbs.code as block_status,
    cb.is_reusable,
    cb.is_system_block,
    cb.current_version,
    COUNT(DISTINCT pb.page_block_id) as usage_count,
    COUNT(DISTINCT ps.page_id) as pages_used_in,
    cb.created_at,
    cb.updated_at
FROM cms.content_blocks cb
JOIN cms.block_type_lookup bt ON bt.block_type_id = cb.block_type_id
JOIN cms.content_block_status_lookup cbs ON cbs.content_block_status_id = cb.content_block_status_id
LEFT JOIN cms.page_blocks pb ON pb.content_block_id = cb.content_block_id
LEFT JOIN cms.page_sections ps ON ps.page_section_id = pb.page_section_id
GROUP BY cb.content_block_id, cb.block_code, cb.block_name, bt.code, bt.name, cbs.code,
         cb.is_reusable, cb.is_system_block, cb.current_version, cb.created_at, cb.updated_at
ORDER BY usage_count DESC NULLS LAST;

-- View 5: Block Type Distribution
CREATE VIEW reports.vw_block_type_distribution AS
SELECT
    bt.code as block_type_code,
    bt.name as block_type_name,
    COUNT(DISTINCT cb.content_block_id) as block_count,
    COUNT(DISTINCT CASE WHEN cb.content_block_status_id = (SELECT content_block_status_id FROM cms.content_block_status_lookup WHERE code = 'ACTIVE') THEN cb.content_block_id END) as active_blocks,
    COUNT(DISTINCT pb.page_block_id) as total_usages
FROM cms.block_type_lookup bt
LEFT JOIN cms.content_blocks cb ON cb.block_type_id = bt.block_type_id
LEFT JOIN cms.page_blocks pb ON pb.content_block_id = cb.content_block_id
GROUP BY bt.block_type_id, bt.code, bt.name, bt.sort_order
ORDER BY bt.sort_order;

-- View 6: Menu Structure Report
CREATE VIEW reports.vw_menu_structure AS
SELECT
    m.menu_code,
    m.menu_name,
    m.menu_location,
    s.site_name,
    mi.label as menu_item_label,
    mi.url as menu_item_url,
    mlt.code as link_type,
    mi.sort_order,
    mi.is_visible,
    mi.is_mega_menu,
    parent_mi.label as parent_label,
    CASE WHEN mi.menu_item_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM cms.menu_items child WHERE child.parent_menu_item_id = mi.menu_item_id)
    ELSE 0 END as child_count
FROM cms.menus m
JOIN cms.sites s ON s.site_id = m.site_id
LEFT JOIN cms.menu_items mi ON mi.menu_id = m.menu_id
LEFT JOIN cms.menu_link_type_lookup mlt ON mlt.menu_link_type_id = mi.menu_link_type_id
LEFT JOIN cms.menu_items parent_mi ON parent_mi.menu_item_id = mi.parent_menu_item_id
ORDER BY m.menu_location, m.menu_name, mi.sort_order;

-- View 7: Orphan Pages Report (pages not in any menu)
CREATE VIEW reports.vw_orphan_pages AS
SELECT
    p.page_code,
    p.page_title,
    p.slug,
    pt.code as page_type,
    ps.code as page_status,
    p.created_at,
    p.updated_at
FROM cms.pages p
JOIN cms.page_type_lookup pt ON pt.page_type_id = p.page_type_id
JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
WHERE ps.code = 'PUBLISHED'
  AND NOT EXISTS (
      SELECT 1 FROM cms.menu_items mi WHERE mi.page_id = p.page_id
  )
  AND NOT pt.is_system
ORDER BY p.updated_at ASC;

-- View 8: Landing Page Performance
CREATE VIEW reports.vw_landing_page_performance AS
SELECT
    lp.landing_page_id,
    p.page_title,
    p.slug,
    lp.campaign_code,
    lp.goal_type,
    lp.total_visits,
    lp.total_conversions,
    lp.conversion_rate,
    lp.start_date,
    lp.end_date,
    lp.is_active,
    mc.campaign_name as marketing_campaign
FROM cms.landing_pages lp
JOIN cms.pages p ON p.page_id = lp.page_id
LEFT JOIN marketing.campaigns mc ON mc.campaign_id = lp.marketing_campaign_id
ORDER BY lp.total_conversions DESC NULLS LAST;

-- View 9: Form Submission Report
CREATE VIEW reports.vw_form_submission_report AS
SELECT
    cf.form_code,
    cf.form_name,
    fss.code as submission_status,
    COUNT(DISTINCT cfs.cms_form_submission_id) as submission_count,
    COUNT(DISTINCT CASE WHEN cfs.is_spam = TRUE THEN cfs.cms_form_submission_id END) as spam_count,
    COUNT(DISTINCT CASE WHEN cfs.customer_id IS NOT NULL THEN cfs.cms_form_submission_id END) as known_customer_count,
    MAX(cfs.submitted_at) as last_submission_at
FROM cms.cms_forms cf
LEFT JOIN cms.cms_form_submissions cfs ON cfs.cms_form_id = cf.cms_form_id
LEFT JOIN cms.form_submission_status_lookup fss ON fss.form_submission_status_id = cfs.form_submission_status_id
GROUP BY cf.cms_form_id, cf.form_code, cf.form_name, fss.code
ORDER BY submission_count DESC NULLS LAST;

-- View 10: Form Conversion Rate
CREATE VIEW reports.vw_form_conversion_rate AS
SELECT
    cf.form_code,
    cf.form_name,
    cf.total_submissions,
    COUNT(DISTINCT CASE WHEN cfs.is_spam = FALSE THEN cfs.cms_form_submission_id END) as valid_submissions,
    COUNT(DISTINCT CASE WHEN cfs.lead_id IS NOT NULL THEN cfs.cms_form_submission_id END) as leads_created,
    COUNT(DISTINCT CASE WHEN cfs.customer_id IS NOT NULL THEN cfs.cms_form_submission_id END) as customers_linked,
    ROUND((COUNT(DISTINCT CASE WHEN cfs.lead_id IS NOT NULL THEN cfs.cms_form_submission_id END)::numeric /
           NULLIF(COUNT(DISTINCT CASE WHEN cfs.is_spam = FALSE THEN cfs.cms_form_submission_id END), 0) * 100), 2) as lead_conversion_rate
FROM cms.cms_forms cf
LEFT JOIN cms.cms_form_submissions cfs ON cfs.cms_form_id = cf.cms_form_id
GROUP BY cf.cms_form_id, cf.form_code, cf.form_name, cf.total_submissions
ORDER BY lead_conversion_rate DESC NULLS LAST;

-- View 11: Redirect Report
CREATE VIEW reports.vw_redirect_report AS
SELECT
    r.source_path,
    r.target_path,
    r.redirect_type,
    rs.code as redirect_status,
    r.is_regex,
    r.hit_count,
    r.last_hit_at,
    r.start_date,
    r.end_date,
    s.site_name
FROM cms.redirects r
JOIN cms.redirect_status_lookup rs ON rs.redirect_status_id = r.redirect_status_id
JOIN cms.sites s ON s.site_id = r.site_id
ORDER BY r.hit_count DESC;

-- View 12: Content Version Report
CREATE VIEW reports.vw_content_version_report AS
SELECT
    p.page_code,
    p.page_title,
    p.current_version,
    p.published_version,
    COUNT(DISTINCT pv.page_version_id) as total_versions,
    MAX(pv.version_number) as latest_version,
    MAX(pv.created_at) as latest_version_date,
    p.updated_at as page_last_updated
FROM cms.pages p
LEFT JOIN cms.page_versions pv ON pv.page_id = p.page_id
GROUP BY p.page_id, p.page_code, p.page_title, p.current_version, p.published_version, p.updated_at
ORDER BY total_versions DESC;

-- View 13: Publishing Activity Report
CREATE VIEW reports.vw_publishing_activity AS
SELECT
    DATE(ph.performed_at) as activity_date,
    ph.action,
    COUNT(DISTINCT ph.publishing_history_id) as action_count,
    COUNT(DISTINCT ph.page_id) as pages_affected,
    COUNT(DISTINCT ph.performed_by_user_id) as users_involved
FROM cms.publishing_history ph
GROUP BY DATE(ph.performed_at), ph.action
ORDER BY activity_date DESC;

-- View 14: SEO Coverage Report
CREATE VIEW reports.vw_seo_coverage AS
SELECT
    p.page_code,
    p.page_title,
    p.slug,
    ps.code as page_status,
    CASE WHEN pseo.page_seo_id IS NOT NULL THEN TRUE ELSE FALSE END as has_seo,
    CASE WHEN pseo.meta_title IS NOT NULL AND pseo.meta_title <> '' THEN TRUE ELSE FALSE END as has_meta_title,
    CASE WHEN pseo.meta_description IS NOT NULL AND pseo.meta_description <> '' THEN TRUE ELSE FALSE END as has_meta_description,
    CASE WHEN pseo.og_title IS NOT NULL THEN TRUE ELSE FALSE END as has_og_tags,
    CASE WHEN pseo.og_image_url IS NOT NULL THEN TRUE ELSE FALSE END as has_og_image,
    pseo.sitemap_priority,
    pseo.exclude_from_sitemap
FROM cms.pages p
JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
LEFT JOIN cms.page_seo pseo ON pseo.page_id = p.page_id
WHERE ps.code = 'PUBLISHED'
ORDER BY has_seo ASC, p.page_title;

-- View 15: Content Freshness Report
CREATE VIEW reports.vw_content_freshness AS
SELECT
    p.page_code,
    p.page_title,
    p.slug,
    ps.code as page_status,
    p.updated_at,
    p.published_at,
    CURRENT_DATE - p.updated_at::DATE as days_since_update,
    CASE
        WHEN CURRENT_DATE - p.updated_at::DATE <= 30 THEN 'FRESH'
        WHEN CURRENT_DATE - p.updated_at::DATE <= 90 THEN 'RECENT'
        WHEN CURRENT_DATE - p.updated_at::DATE <= 180 THEN 'AGING'
        ELSE 'STALE'
    END as freshness_status
FROM cms.pages p
JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
WHERE ps.code = 'PUBLISHED'
ORDER BY days_since_update DESC;

-- View 16: Translation Coverage Report
CREATE VIEW reports.vw_translation_coverage AS
SELECT
    ct.entity_type,
    ct.language_code,
    COUNT(DISTINCT ct.entity_id) as translated_count,
    CASE ct.entity_type
        WHEN 'PAGE' THEN (SELECT COUNT(*) FROM cms.pages)
        WHEN 'BLOCK' THEN (SELECT COUNT(*) FROM cms.content_blocks)
        WHEN 'MENU_ITEM' THEN (SELECT COUNT(*) FROM cms.menu_items)
    END as total_entities,
    ROUND((COUNT(DISTINCT ct.entity_id)::numeric /
           NULLIF(CASE ct.entity_type
               WHEN 'PAGE' THEN (SELECT COUNT(*) FROM cms.pages)
               WHEN 'BLOCK' THEN (SELECT COUNT(*) FROM cms.content_blocks)
               WHEN 'MENU_ITEM' THEN (SELECT COUNT(*) FROM cms.menu_items)
           END, 0) * 100), 2) as coverage_percent
FROM cms.content_translations ct
GROUP BY ct.entity_type, ct.language_code
ORDER BY ct.entity_type, ct.language_code;

-- View 17: Page Performance by Type
CREATE VIEW reports.vw_page_performance_by_type AS
SELECT
    pt.code as page_type_code,
    pt.name as page_type_name,
    COUNT(DISTINCT p.page_id) as page_count,
    COUNT(DISTINCT CASE WHEN ps.code = 'PUBLISHED' THEN p.page_id END) as published_count,
    COUNT(DISTINCT CASE WHEN ps.code = 'DRAFT' THEN p.page_id END) as draft_count,
    COUNT(DISTINCT pb.page_block_id) as total_blocks_used,
    COUNT(DISTINCT psec.page_section_id) as total_sections
FROM cms.page_type_lookup pt
LEFT JOIN cms.pages p ON p.page_type_id = pt.page_type_id
LEFT JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
LEFT JOIN cms.page_sections psec ON psec.page_id = p.page_id
LEFT JOIN cms.page_blocks pb ON pb.page_section_id = psec.page_section_id
GROUP BY pt.page_type_id, pt.code, pt.name, pt.sort_order
ORDER BY pt.sort_order;

-- View 18: Content Reuse Analysis
CREATE VIEW reports.vw_content_reuse_analysis AS
SELECT
    cb.block_code,
    cb.block_name,
    bt.name as block_type,
    cb.is_reusable,
    COUNT(DISTINCT pb.page_block_id) as usage_count,
    COUNT(DISTINCT ps.page_id) as unique_pages,
    CASE
        WHEN COUNT(DISTINCT pb.page_block_id) = 0 THEN 'UNUSED'
        WHEN COUNT(DISTINCT ps.page_id) = 1 THEN 'SINGLE_USE'
        WHEN COUNT(DISTINCT ps.page_id) BETWEEN 2 AND 5 THEN 'MODERATE_REUSE'
        ELSE 'HIGH_REUSE'
    END as reuse_level
FROM cms.content_blocks cb
JOIN cms.block_type_lookup bt ON bt.block_type_id = cb.block_type_id
LEFT JOIN cms.page_blocks pb ON pb.content_block_id = cb.content_block_id
LEFT JOIN cms.page_sections ps ON ps.page_section_id = pb.page_section_id
WHERE cb.is_reusable = TRUE
GROUP BY cb.content_block_id, cb.block_code, cb.block_name, bt.name, cb.is_reusable
ORDER BY usage_count DESC;

-- View 19: Draft Aging Report
CREATE VIEW reports.vw_draft_aging AS
SELECT
    p.page_code,
    p.page_title,
    p.slug,
    ps.code as page_status,
    p.created_at,
    p.updated_at,
    CURRENT_DATE - p.created_at::DATE as days_in_draft,
    CURRENT_DATE - p.updated_at::DATE as days_since_last_edit,
    u.username as created_by
FROM cms.pages p
JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
LEFT JOIN identity.users u ON u.user_id = p.created_by_user_id
WHERE ps.code IN ('DRAFT', 'REVIEW')
ORDER BY days_in_draft DESC;

-- View 20: Site Health Report
CREATE VIEW reports.vw_site_health AS
SELECT
    s.site_code,
    s.site_name,
    ssl.code as site_status,
    COUNT(DISTINCT p.page_id) as total_pages,
    COUNT(DISTINCT CASE WHEN ps.code = 'PUBLISHED' THEN p.page_id END) as published_pages,
    COUNT(DISTINCT CASE WHEN ps.code = 'DRAFT' THEN p.page_id END) as draft_pages,
    COUNT(DISTINCT CASE WHEN ps.code = 'REVIEW' THEN p.page_id END) as pages_in_review,
    COUNT(DISTINCT sd.site_domain_id) as domain_count,
    COUNT(DISTINCT m.menu_id) as menu_count,
    COUNT(DISTINCT mi.menu_item_id) as menu_item_count,
    COUNT(DISTINCT r.redirect_id) as redirect_count,
    COUNT(DISTINCT cf.cms_form_id) as form_count,
    COUNT(DISTINCT pseo.page_seo_id) as pages_with_seo,
    ROUND((COUNT(DISTINCT pseo.page_seo_id)::numeric / NULLIF(COUNT(DISTINCT CASE WHEN ps.code = 'PUBLISHED' THEN p.page_id END), 0) * 100), 2) as seo_coverage_percent
FROM cms.sites s
JOIN cms.site_status_lookup ssl ON ssl.site_status_id = s.site_status_id
LEFT JOIN cms.pages p ON p.site_id = s.site_id
LEFT JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
LEFT JOIN cms.site_domains sd ON sd.site_id = s.site_id
LEFT JOIN cms.menus m ON m.site_id = s.site_id
LEFT JOIN cms.menu_items mi ON mi.menu_id = m.menu_id
LEFT JOIN cms.redirects r ON r.site_id = s.site_id
LEFT JOIN cms.cms_forms cf ON cf.site_id = s.site_id
LEFT JOIN cms.page_seo pseo ON pseo.page_id = p.page_id
GROUP BY s.site_id, s.site_code, s.site_name, ssl.code
ORDER BY s.is_default DESC;

-- Function 1: Get Page Content Tree
CREATE OR REPLACE FUNCTION reports.get_page_content_tree(
    p_page_id UUID
)
RETURNS TABLE (
    section_code VARCHAR,
    section_name VARCHAR,
    section_type VARCHAR,
    sort_order_section INTEGER,
    block_code VARCHAR,
    block_name VARCHAR,
    block_type VARCHAR,
    sort_order_block INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        psec.section_code::VARCHAR,
        psec.section_name::VARCHAR,
        psec.section_type::VARCHAR,
        psec.sort_order,
        cb.block_code::VARCHAR,
        cb.block_name::VARCHAR,
        bt.name::VARCHAR,
        pb.sort_order
    FROM cms.page_sections psec
    LEFT JOIN cms.page_blocks pb ON pb.page_section_id = psec.page_section_id AND pb.is_visible = TRUE
    LEFT JOIN cms.content_blocks cb ON cb.content_block_id = pb.content_block_id
    LEFT JOIN cms.block_type_lookup bt ON bt.block_type_id = cb.block_type_id
    WHERE psec.page_id = p_page_id AND psec.is_visible = TRUE
    ORDER BY psec.sort_order, pb.sort_order;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Site Content Summary
CREATE OR REPLACE FUNCTION reports.get_site_content_summary(
    p_site_id UUID
)
RETURNS TABLE (
    total_pages BIGINT,
    published_pages BIGINT,
    draft_pages BIGINT,
    total_menus BIGINT,
    total_menu_items BIGINT,
    total_blocks BIGINT,
    total_forms BIGINT,
    total_form_submissions BIGINT,
    total_redirects BIGINT,
    pages_with_seo BIGINT,
    seo_coverage NUMERIC
) AS $$
DECLARE
    v_total_published BIGINT;
    v_total_seo BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total_published
    FROM cms.pages p
    JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id
    WHERE p.site_id = p_site_id AND ps.code = 'PUBLISHED';

    SELECT COUNT(*) INTO v_total_seo
    FROM cms.page_seo pseo
    JOIN cms.pages p ON p.page_id = pseo.page_id
    WHERE p.site_id = p_site_id;

    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM cms.pages p WHERE p.site_id = p_site_id),
        v_total_published,
        (SELECT COUNT(*) FROM cms.pages p JOIN cms.page_status_lookup ps ON ps.page_status_id = p.page_status_id WHERE p.site_id = p_site_id AND ps.code = 'DRAFT'),
        (SELECT COUNT(*) FROM cms.menus m WHERE m.site_id = p_site_id),
        (SELECT COUNT(*) FROM cms.menu_items mi JOIN cms.menus m ON m.menu_id = mi.menu_id WHERE m.site_id = p_site_id),
        (SELECT COUNT(*) FROM cms.content_blocks cb WHERE cb.company_id = (SELECT company_id FROM cms.sites WHERE site_id = p_site_id)),
        (SELECT COUNT(*) FROM cms.cms_forms cf WHERE cf.site_id = p_site_id),
        (SELECT COUNT(*) FROM cms.cms_form_submissions cfs JOIN cms.cms_forms cf ON cf.cms_form_id = cfs.cms_form_id WHERE cf.site_id = p_site_id),
        (SELECT COUNT(*) FROM cms.redirects r WHERE r.site_id = p_site_id),
        v_total_seo,
        ROUND((v_total_seo::numeric / NULLIF(v_total_published, 0) * 100), 2);
END;
$$ LANGUAGE plpgsql;

COMMIT;