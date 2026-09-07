BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 22: BLOG & EDITORIAL CONTENT REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Blog Post Inventory
CREATE VIEW reports.vw_blog_post_inventory AS
SELECT
    bp.post_number,
    bp.title,
    bp.slug,
    bs.blog_name,
    bps.code as post_status,
    bpct.code as content_type,
    ba.display_name as author_name,
    bp.published_at,
    bp.scheduled_publish_at,
    bp.view_count,
    bp.comment_count,
    bp.like_count,
    bp.share_count,
    bp.is_featured,
    bp.is_pinned,
    bp.created_at,
    bp.updated_at
FROM blog.blog_posts bp
JOIN blog.blog_sites bs ON bs.blog_site_id = bp.blog_site_id
JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
JOIN blog.blog_post_content_type_lookup bpct ON bpct.blog_post_content_type_id = bp.blog_post_content_type_id
LEFT JOIN blog.blog_authors ba ON ba.blog_author_id = bp.author_blog_author_id
ORDER BY bp.published_at DESC NULLS LAST, bp.created_at DESC;

-- View 2: Blog Post Status Distribution
CREATE VIEW reports.vw_blog_post_status_distribution AS
SELECT
    bs.blog_name,
    bps.code as post_status,
    bps.name as status_name,
    COUNT(DISTINCT bp.blog_post_id) as post_count,
    ROUND((COUNT(DISTINCT bp.blog_post_id)::numeric /
           NULLIF((SELECT COUNT(*) FROM blog.blog_posts), 0) * 100), 2) as percent_of_total
FROM blog.blog_post_status_lookup bps
LEFT JOIN blog.blog_posts bp ON bp.blog_post_status_id = bps.blog_post_status_id
LEFT JOIN blog.blog_sites bs ON bs.blog_site_id = bp.blog_site_id
GROUP BY bs.blog_name, bps.blog_post_status_id, bps.code, bps.name, bps.sort_order
ORDER BY bps.sort_order;

-- View 3: Blog Content by Category
CREATE VIEW reports.vw_blog_content_by_category AS
SELECT
    bc.category_name,
    bc.slug as category_slug,
    COUNT(DISTINCT bp.blog_post_id) as post_count,
    COUNT(DISTINCT CASE WHEN bps.code = 'PUBLISHED' THEN bp.blog_post_id END) as published_count,
    SUM(bp.view_count) as total_views,
    SUM(bp.comment_count) as total_comments,
    SUM(bp.like_count) as total_likes,
    MAX(bp.published_at) as latest_post_date
FROM blog.blog_categories bc
LEFT JOIN blog.blog_post_categories bpc ON bpc.blog_category_id = bc.blog_category_id
LEFT JOIN blog.blog_posts bp ON bp.blog_post_id = bpc.blog_post_id
LEFT JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
WHERE bc.is_active = TRUE
GROUP BY bc.blog_category_id, bc.category_name, bc.slug
ORDER BY post_count DESC;

-- View 4: Blog Content by Tag
CREATE VIEW reports.vw_blog_content_by_tag AS
SELECT
    bt.tag_name,
    bt.slug as tag_slug,
    COUNT(DISTINCT bp.blog_post_id) as post_count,
    COUNT(DISTINCT CASE WHEN bps.code = 'PUBLISHED' THEN bp.blog_post_id END) as published_count,
    SUM(bp.view_count) as total_views
FROM blog.blog_tags bt
LEFT JOIN blog.blog_post_tags bpt ON bpt.blog_tag_id = bt.blog_tag_id
LEFT JOIN blog.blog_posts bp ON bp.blog_post_id = bpt.blog_post_id
LEFT JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
WHERE bt.is_active = TRUE
GROUP BY bt.blog_tag_id, bt.tag_name, bt.slug
ORDER BY post_count DESC;

-- View 5: Blog Author Performance
CREATE VIEW reports.vw_blog_author_performance AS
SELECT
    ba.author_code,
    ba.display_name,
    COUNT(DISTINCT bp.blog_post_id) as total_posts,
    COUNT(DISTINCT CASE WHEN bps.code = 'PUBLISHED' THEN bp.blog_post_id END) as published_posts,
    SUM(bp.view_count) as total_views,
    SUM(bp.comment_count) as total_comments,
    SUM(bp.like_count) as total_likes,
    SUM(bp.share_count) as total_shares,
    AVG(bp.view_count) FILTER (WHERE bp.view_count > 0) as avg_views_per_post,
    MAX(bp.published_at) as latest_post_date
FROM blog.blog_authors ba
LEFT JOIN blog.blog_posts bp ON bp.author_blog_author_id = ba.blog_author_id
LEFT JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
WHERE ba.is_active = TRUE
GROUP BY ba.blog_author_id, ba.author_code, ba.display_name
ORDER BY total_views DESC NULLS LAST;

-- View 6: Blog Post Analytics
CREATE VIEW reports.vw_blog_post_analytics AS
SELECT
    bp.post_number,
    bp.title,
    bp.slug,
    bp.published_at,
    bp.view_count,
    bp.unique_view_count,
    bp.like_count,
    bp.share_count,
    bp.comment_count,
    bp.reading_time_minutes,
    bp.word_count,
    bps_stat.avg_time_on_page_seconds,
    bps_stat.bounce_rate,
    bps_stat.product_click_count,
    bps_stat.conversion_count,
    bps_stat.conversion_revenue
FROM blog.blog_posts bp
LEFT JOIN LATERAL (
    SELECT
        AVG(bps.avg_time_on_page_seconds) as avg_time_on_page_seconds,
        AVG(bps.bounce_rate) as bounce_rate,
        SUM(bps.product_click_count) as product_click_count,
        SUM(bps.conversion_count) as conversion_count,
        SUM(bps.conversion_revenue) as conversion_revenue
    FROM blog.blog_post_statistics bps
    WHERE bps.blog_post_id = bp.blog_post_id
) bps_stat ON TRUE
JOIN blog.blog_post_status_lookup bpsl ON bpsl.blog_post_status_id = bp.blog_post_status_id
WHERE bpsl.code = 'PUBLISHED'
ORDER BY bp.view_count DESC;

-- View 7: Blog Comment Moderation Queue
CREATE VIEW reports.vw_blog_comment_moderation AS
SELECT
    bc.blog_comment_id,
    bp.title as post_title,
    bc.author_name,
    bc.author_email,
    bc.comment_text,
    bcs.code as comment_status,
    bc.is_spam,
    bc.spam_score,
    bc.created_at,
    CASE WHEN bc.parent_comment_id IS NOT NULL THEN TRUE ELSE FALSE END as is_reply
FROM blog.blog_comments bc
JOIN blog.blog_posts bp ON bp.blog_post_id = bc.blog_post_id
JOIN blog.blog_comment_status_lookup bcs ON bcs.blog_comment_status_id = bc.blog_comment_status_id
WHERE bcs.code IN ('PENDING_MODERATION', 'FLAGGED')
ORDER BY bc.created_at ASC;

-- View 8: Blog Comment Summary
CREATE VIEW reports.vw_blog_comment_summary AS
SELECT
    bp.post_number,
    bp.title,
    bcs.code as comment_status,
    COUNT(DISTINCT bc.blog_comment_id) as comment_count,
    COUNT(DISTINCT CASE WHEN bc.is_spam = TRUE THEN bc.blog_comment_id END) as spam_count,
    MAX(bc.created_at) as latest_comment_at
FROM blog.blog_posts bp
LEFT JOIN blog.blog_comments bc ON bc.blog_post_id = bp.blog_post_id
LEFT JOIN blog.blog_comment_status_lookup bcs ON bcs.blog_comment_status_id = bc.blog_comment_status_id
GROUP BY bp.post_number, bp.title, bcs.code
ORDER BY comment_count DESC;

-- View 9: Blog Series Progress
CREATE VIEW reports.vw_blog_series_progress AS
SELECT
    bsrs.series_name,
    bsrs.slug as series_slug,
    bsrs.description,
    bsrs.total_parts,
    COUNT(DISTINCT bsp.blog_post_id) as published_parts,
    COUNT(DISTINCT CASE WHEN bps.code = 'PUBLISHED' THEN bsp.blog_post_id END) as live_parts,
    ROUND((COUNT(DISTINCT CASE WHEN bps.code = 'PUBLISHED' THEN bsp.blog_post_id END)::numeric /
           NULLIF(bsrs.total_parts, 0) * 100), 2) as completion_percent
FROM blog.blog_series bsrs
LEFT JOIN blog.blog_series_posts bsp ON bsp.blog_series_id = bsrs.blog_series_id
LEFT JOIN blog.blog_posts bp ON bp.blog_post_id = bsp.blog_post_id
LEFT JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
WHERE bsrs.is_active = TRUE
GROUP BY bsrs.blog_series_id, bsrs.series_name, bsrs.slug, bsrs.description, bsrs.total_parts
ORDER BY bsrs.series_name;

-- View 10: Blog Product Integration Report
CREATE VIEW reports.vw_blog_product_integration AS
SELECT
    bp.post_number,
    bp.title as post_title,
    p.product_code,
    p.product_name,
    bpp.relation_type,
    bpp.is_featured,
    bp.published_at,
    bps_stat.product_click_count,
    bps_stat.conversion_count
FROM blog.blog_post_products bpp
JOIN blog.blog_posts bp ON bp.blog_post_id = bpp.blog_post_id
JOIN catalog.products p ON p.product_id = bpp.product_id
LEFT JOIN LATERAL (
    SELECT
        SUM(bps.product_click_count) as product_click_count,
        SUM(bps.conversion_count) as conversion_count
    FROM blog.blog_post_statistics bps
    WHERE bps.blog_post_id = bp.blog_post_id
) bps_stat ON TRUE
ORDER BY bps_stat.conversion_count DESC NULLS LAST;

-- View 11: Blog Editorial Workflow Report
CREATE VIEW reports.vw_blog_editorial_workflow AS
SELECT
    DATE(bph.performed_at) as activity_date,
    bph.action,
    COUNT(DISTINCT bph.blog_publishing_history_id) as action_count,
    COUNT(DISTINCT bph.blog_post_id) as posts_affected,
    COUNT(DISTINCT bph.performed_by_user_id) as users_involved
FROM blog.blog_publishing_history bph
GROUP BY DATE(bph.performed_at), bph.action
ORDER BY activity_date DESC;

-- View 12: Blog Content Freshness Report
CREATE VIEW reports.vw_blog_content_freshness AS
SELECT
    bp.post_number,
    bp.title,
    bp.slug,
    bps.code as post_status,
    bp.published_at,
    bp.updated_at,
    CURRENT_DATE - bp.published_at::DATE as days_since_publish,
    CURRENT_DATE - bp.updated_at::DATE as days_since_update,
    CASE
        WHEN CURRENT_DATE - bp.published_at::DATE <= 30 THEN 'FRESH'
        WHEN CURRENT_DATE - bp.published_at::DATE <= 90 THEN 'RECENT'
        WHEN CURRENT_DATE - bp.published_at::DATE <= 180 THEN 'AGING'
        ELSE 'STALE'
    END as freshness_status
FROM blog.blog_posts bp
JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
WHERE bps.code = 'PUBLISHED'
ORDER BY days_since_publish DESC;

-- View 13: Blog SEO Coverage Report
CREATE VIEW reports.vw_blog_seo_coverage AS
SELECT
    bp.post_number,
    bp.title,
    bp.slug,
    bps.code as post_status,
    CASE WHEN bpseo.blog_post_seo_id IS NOT NULL THEN TRUE ELSE FALSE END as has_seo,
    CASE WHEN bpseo.meta_title IS NOT NULL AND bpseo.meta_title <> '' THEN TRUE ELSE FALSE END as has_meta_title,
    CASE WHEN bpseo.meta_description IS NOT NULL AND bpseo.meta_description <> '' THEN TRUE ELSE FALSE END as has_meta_description,
    CASE WHEN bpseo.og_title IS NOT NULL THEN TRUE ELSE FALSE END as has_og_tags,
    CASE WHEN bpseo.structured_data IS NOT NULL THEN TRUE ELSE FALSE END as has_structured_data
FROM blog.blog_posts bp
JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
LEFT JOIN blog.blog_post_seo bpseo ON bpseo.blog_post_id = bp.blog_post_id
WHERE bps.code = 'PUBLISHED'
ORDER BY has_seo ASC, bp.title;

-- View 14: Blog Traffic Sources Report
CREATE VIEW reports.vw_blog_traffic_sources AS
SELECT
    DATE(bps.stat_date) as traffic_date,
    SUM(bps.traffic_source_organic) as organic_traffic,
    SUM(bps.traffic_source_social) as social_traffic,
    SUM(bps.traffic_source_direct) as direct_traffic,
    SUM(bps.traffic_source_referral) as referral_traffic,
    SUM(bps.traffic_source_email) as email_traffic,
    SUM(bps.view_count) as total_views
FROM blog.blog_post_statistics bps
GROUP BY DATE(bps.stat_date)
ORDER BY traffic_date DESC;

-- View 15: Blog Conversion Report
CREATE VIEW reports.vw_blog_conversion_report AS
SELECT
    bp.post_number,
    bp.title,
    bp.published_at,
    bp.view_count,
    bps_stat.product_click_count,
    bps_stat.conversion_count,
    bps_stat.conversion_revenue,
    ROUND((bps_stat.conversion_count::numeric / NULLIF(bp.view_count, 0) * 100), 2) as conversion_rate,
    ROUND((bps_stat.product_click_count::numeric / NULLIF(bp.view_count, 0) * 100), 2) as click_rate
FROM blog.blog_posts bp
LEFT JOIN LATERAL (
    SELECT
        SUM(bps.product_click_count) as product_click_count,
        SUM(bps.conversion_count) as conversion_count,
        SUM(bps.conversion_revenue) as conversion_revenue
    FROM blog.blog_post_statistics bps
    WHERE bps.blog_post_id = bp.blog_post_id
) bps_stat ON TRUE
JOIN blog.blog_post_status_lookup bpsl ON bpsl.blog_post_status_id = bp.blog_post_status_id
WHERE bpsl.code = 'PUBLISHED' AND bp.view_count > 0
ORDER BY bps_stat.conversion_revenue DESC NULLS LAST;

-- View 16: Blog Social Sharing Report
CREATE VIEW reports.vw_blog_social_sharing AS
SELECT
    bp.post_number,
    bp.title,
    bp.share_count,
    bp.view_count,
    ROUND((bp.share_count::numeric / NULLIF(bp.view_count, 0) * 100), 2) as share_rate,
    bp.published_at
FROM blog.blog_posts bp
JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
WHERE bps.code = 'PUBLISHED' AND bp.share_count > 0
ORDER BY bp.share_count DESC;

-- View 17: Blog Draft Aging Report
CREATE VIEW reports.vw_blog_draft_aging AS
SELECT
    bp.post_number,
    bp.title,
    bp.slug,
    bps.code as post_status,
    bp.created_at,
    bp.updated_at,
    CURRENT_DATE - bp.created_at::DATE as days_in_draft,
    CURRENT_DATE - bp.updated_at::DATE as days_since_last_edit,
    u.username as created_by
FROM blog.blog_posts bp
JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
LEFT JOIN identity.users u ON u.user_id = bp.created_by_user_id
WHERE bps.code IN ('DRAFT', 'IN_REVIEW', 'CHANGES_REQUESTED')
ORDER BY days_in_draft DESC;

-- View 18: Blog Site Health Report
CREATE VIEW reports.vw_blog_site_health AS
SELECT
    bs.blog_code,
    bs.blog_name,
    bs.base_url,
    COUNT(DISTINCT bp.blog_post_id) as total_posts,
    COUNT(DISTINCT CASE WHEN bps.code = 'PUBLISHED' THEN bp.blog_post_id END) as published_posts,
    COUNT(DISTINCT CASE WHEN bps.code = 'DRAFT' THEN bp.blog_post_id END) as draft_posts,
    COUNT(DISTINCT bc.blog_category_id) as category_count,
    COUNT(DISTINCT bt.blog_tag_id) as tag_count,
    COUNT(DISTINCT ba.blog_author_id) as author_count,
    COUNT(DISTINCT bsr.blog_series_id) as series_count,
    SUM(bp.view_count) as total_views,
    SUM(bp.comment_count) as total_comments
FROM blog.blog_sites bs
LEFT JOIN blog.blog_posts bp ON bp.blog_site_id = bs.blog_site_id
LEFT JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
LEFT JOIN blog.blog_categories bc ON bc.blog_site_id = bs.blog_site_id
LEFT JOIN blog.blog_tags bt ON bt.blog_site_id = bs.blog_site_id
LEFT JOIN blog.blog_authors ba ON ba.company_id = bs.company_id
LEFT JOIN blog.blog_series bsr ON bsr.blog_site_id = bs.blog_site_id
GROUP BY bs.blog_site_id, bs.blog_code, bs.blog_name, bs.base_url
ORDER BY published_posts DESC NULLS LAST;

-- View 19: Blog RSS Feed Report
CREATE VIEW reports.vw_blog_rss_feed AS
SELECT
    bp.post_number,
    bp.title,
    bp.slug,
    bp.excerpt,
    bp.summary,
    bp.published_at,
    bs.base_url || '/' || bp.slug as post_url,
    bp.featured_image_url,
    ba.display_name as author_name,
    bp.reading_time_minutes
FROM blog.blog_posts bp
JOIN blog.blog_sites bs ON bs.blog_site_id = bp.blog_site_id
JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
LEFT JOIN blog.blog_authors ba ON ba.blog_author_id = bp.author_blog_author_id
WHERE bps.code = 'PUBLISHED'
  AND bs.rss_enabled = TRUE
ORDER BY bp.published_at DESC
LIMIT 20;

-- View 20: Blog Post Engagement Rate
CREATE VIEW reports.vw_blog_post_engagement AS
SELECT
    bp.post_number,
    bp.title,
    bp.view_count,
    bp.like_count,
    bp.comment_count,
    bp.share_count,
    (bp.like_count + bp.comment_count + bp.share_count) as total_engagement,
    ROUND(((bp.like_count + bp.comment_count + bp.share_count)::numeric / NULLIF(bp.view_count, 0) * 100), 2) as engagement_rate,
    bp.published_at
FROM blog.blog_posts bp
JOIN blog.blog_post_status_lookup bps ON bps.blog_post_status_id = bp.blog_post_status_id
WHERE bps.code = 'PUBLISHED' AND bp.view_count > 0
ORDER BY engagement_rate DESC;

-- Function 1: Get Blog Post Full Content
CREATE OR REPLACE FUNCTION reports.get_blog_post_content(
    p_blog_post_id UUID
)
RETURNS TABLE (
    post_number VARCHAR,
    title VARCHAR,
    slug VARCHAR,
    content_html TEXT,
    author_name VARCHAR,
    published_at TIMESTAMPTZ,
    reading_time INTEGER,
    categories TEXT[],
    tags TEXT[],
    related_products BIGINT,
    related_posts BIGINT,
    comment_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bp.post_number::VARCHAR,
        bp.title::VARCHAR,
        bp.slug::VARCHAR,
        bp.content_html,
        ba.display_name::VARCHAR,
        bp.published_at,
        bp.reading_time_minutes,
        ARRAY_AGG(DISTINCT bc.category_name) FILTER (WHERE bc.category_name IS NOT NULL),
        ARRAY_AGG(DISTINCT bt.tag_name) FILTER (WHERE bt.tag_name IS NOT NULL),
        COUNT(DISTINCT bpp.blog_post_product_id),
        COUNT(DISTINCT bpr.blog_post_relation_id),
        COUNT(DISTINCT bcm.blog_comment_id)
    FROM blog.blog_posts bp
    LEFT JOIN blog.blog_authors ba ON ba.blog_author_id = bp.author_blog_author_id
    LEFT JOIN blog.blog_post_categories bpc ON bpc.blog_post_id = bp.blog_post_id
    LEFT JOIN blog.blog_categories bc ON bc.blog_category_id = bpc.blog_category_id
    LEFT JOIN blog.blog_post_tags bpt ON bpt.blog_post_id = bp.blog_post_id
    LEFT JOIN blog.blog_tags bt ON bt.blog_tag_id = bpt.blog_tag_id
    LEFT JOIN blog.blog_post_products bpp ON bpp.blog_post_id = bp.blog_post_id
    LEFT JOIN blog.blog_post_relations bpr ON bpr.blog_post_id = bp.blog_post_id
    LEFT JOIN blog.blog_comments bcm ON bcm.blog_post_id = bp.blog_post_id
    WHERE bp.blog_post_id = p_blog_post_id
    GROUP BY bp.blog_post_id, bp.post_number, bp.title, bp.slug, bp.content_html, ba.display_name, bp.published_at, bp.reading_time_minutes;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Blog Statistics by Date Range
CREATE OR REPLACE FUNCTION reports.get_blog_statistics(
    p_blog_site_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_date DATE,
    total_views BIGINT,
    unique_views BIGINT,
    total_likes BIGINT,
    total_shares BIGINT,
    total_comments BIGINT,
    product_clicks BIGINT,
    conversions BIGINT,
    conversion_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bps.stat_date,
        SUM(bps.view_count)::BIGINT,
        SUM(bps.unique_view_count)::BIGINT,
        SUM(bps.like_count)::BIGINT,
        SUM(bps.share_count)::BIGINT,
        SUM(bps.comment_count)::BIGINT,
        SUM(bps.product_click_count)::BIGINT,
        SUM(bps.conversion_count)::BIGINT,
        SUM(bps.conversion_revenue)
    FROM blog.blog_post_statistics bps
    JOIN blog.blog_posts bp ON bp.blog_post_id = bps.blog_post_id
    WHERE bp.blog_site_id = p_blog_site_id
      AND bps.stat_date BETWEEN p_start_date AND p_end_date
    GROUP BY bps.stat_date
    ORDER BY bps.stat_date;
END;
$$ LANGUAGE plpgsql;

COMMIT;