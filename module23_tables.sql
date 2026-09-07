BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 23 — SEO & SEARCH ENGINE OPTIMIZATION
-- DATABASE TABLES
-- ============================================================
-- Architecture Principles:
--   1. SEO builds on top of CMS (Module 21) and Blog (Module 22)
--   2. SEO centralizes metadata for all entities (pages, products,
--      categories, blog posts)
--   3. Backend manages SEO data; Next.js renders actual metadata
--   4. Structured data (JSON-LD) generated from actual entity data
--   5. Redirects detect chains and loops
--   6. Sitemaps generated dynamically per entity type
--   7. SEO audit scores entities and identifies issues
-- ============================================================
-- Components:
--   23.1  SEO Entities
--   23.2  SEO Metadata
--   23.3  Open Graph Tags
--   23.4  Twitter Cards
--   23.5  Structured Data (JSON-LD)
--   23.6  SEO Keywords
--   23.7  SEO Redirects
--   23.8  Sitemaps
--   23.9  Robots.txt
--   23.10 SEO Audits
--   23.11 SEO Audit Issues
--   23.12 Image SEO
--   23.13 Internal Linking
--   23.14 SEO Analytics
-- ============================================================

CREATE SCHEMA IF NOT EXISTS seo;

-- ============================================================
-- 23.0 SEO LOOKUPS
-- ============================================================

-- SEO Entity Type
CREATE TABLE IF NOT EXISTS seo.seo_entity_type_lookup (
    seo_entity_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO seo.seo_entity_type_lookup (code, name, description, sort_order) VALUES
    ('PAGE', 'CMS Page', 'SEO for CMS pages.', 10),
    ('PRODUCT', 'Product', 'SEO for product pages.', 20),
    ('CATEGORY', 'Category', 'SEO for category pages.', 30),
    ('BLOG_POST', 'Blog Post', 'SEO for blog posts.', 40),
    ('COLLECTION', 'Collection', 'SEO for collection pages.', 50),
    ('LANDING_PAGE', 'Landing Page', 'SEO for landing pages.', 60),
    ('BRAND', 'Brand', 'SEO for brand pages.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- SEO Audit Status
CREATE TABLE IF NOT EXISTS seo.seo_audit_status_lookup (
    seo_audit_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO seo.seo_audit_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Audit scheduled.', 10),
    ('IN_PROGRESS', 'In Progress', 'Audit is running.', 20),
    ('COMPLETED', 'Completed', 'Audit completed.', 30),
    ('FAILED', 'Failed', 'Audit failed.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- SEO Issue Type
CREATE TABLE IF NOT EXISTS seo.seo_issue_type_lookup (
    seo_issue_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO seo.seo_issue_type_lookup (code, name, description, sort_order) VALUES
    ('MISSING_META_TITLE', 'Missing Meta Title', 'Meta title is missing.', 10),
    ('MISSING_META_DESCRIPTION', 'Missing Meta Description', 'Meta description is missing.', 20),
    ('DUPLICATE_META_TITLE', 'Duplicate Meta Title', 'Meta title is duplicated.', 30),
    ('MISSING_CANONICAL', 'Missing Canonical URL', 'Canonical URL is missing.', 40),
    ('MISSING_SCHEMA', 'Missing Structured Data', 'Structured data is missing.', 50),
    ('MISSING_ALT_TEXT', 'Missing ALT Text', 'Image ALT text is missing.', 60),
    ('MISSING_OG_TAGS', 'Missing Open Graph Tags', 'Open Graph tags are missing.', 70),
    ('MISSING_TWITTER_CARD', 'Missing Twitter Card', 'Twitter Card is missing.', 80),
    ('FEW_INTERNAL_LINKS', 'Few Internal Links', 'Insufficient internal links.', 90),
    ('REDIRECT_CHAIN', 'Redirect Chain', 'Redirect chain detected.', 100),
    ('REDIRECT_LOOP', 'Redirect Loop', 'Redirect loop detected.', 110),
    ('THIN_CONTENT', 'Thin Content', 'Content is too short.', 120),
    ('MISSING_SITEMAP', 'Missing Sitemap', 'Entity not in sitemap.', 130)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- SEO Issue Severity
CREATE TABLE IF NOT EXISTS seo.seo_issue_severity_lookup (
    seo_issue_severity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO seo.seo_issue_severity_lookup (code, name, description, sort_order) VALUES
    ('CRITICAL', 'Critical', 'Critical SEO issue.', 10),
    ('HIGH', 'High', 'High priority SEO issue.', 20),
    ('MEDIUM', 'Medium', 'Medium priority SEO issue.', 30),
    ('LOW', 'Low', 'Low priority SEO issue.', 40),
    ('INFO', 'Info', 'Informational SEO note.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Redirect Status
CREATE TABLE IF NOT EXISTS seo.redirect_status_lookup (
    redirect_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO seo.redirect_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Redirect is active.', 10),
    ('INACTIVE', 'Inactive', 'Redirect is disabled.', 20),
    ('EXPIRED', 'Expired', 'Redirect has expired.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Sitemap Type
CREATE TABLE IF NOT EXISTS seo.sitemap_type_lookup (
    sitemap_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO seo.sitemap_type_lookup (code, name, description, sort_order) VALUES
    ('PRODUCTS', 'Products', 'Sitemap for product pages.', 10),
    ('CATEGORIES', 'Categories', 'Sitemap for category pages.', 20),
    ('BLOG', 'Blog', 'Sitemap for blog posts.', 30),
    ('PAGES', 'Pages', 'Sitemap for CMS pages.', 40),
    ('COLLECTIONS', 'Collections', 'Sitemap for collection pages.', 50),
    ('INDEX', 'Sitemap Index', 'Sitemap index file.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Structured Data Type
CREATE TABLE IF NOT EXISTS seo.structured_data_type_lookup (
    structured_data_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    schema_org_type VARCHAR(100) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO seo.structured_data_type_lookup (code, name, description, schema_org_type, sort_order) VALUES
    ('ARTICLE', 'Article', 'Article structured data.', 'Article', 10),
    ('BLOG_POSTING', 'Blog Posting', 'Blog posting structured data.', 'BlogPosting', 20),
    ('PRODUCT', 'Product', 'Product structured data.', 'Product', 30),
    ('BREADCRUMB_LIST', 'Breadcrumb List', 'Breadcrumb list structured data.', 'BreadcrumbList', 40),
    ('ORGANIZATION', 'Organization', 'Organization structured data.', 'Organization', 50),
    ('PERSON', 'Person', 'Person structured data.', 'Person', 60),
    ('FAQ_PAGE', 'FAQ Page', 'FAQ page structured data.', 'FAQPage', 70),
    ('REVIEW', 'Review', 'Review structured data.', 'Review', 80),
    ('AGGREGATE_RATING', 'Aggregate Rating', 'Aggregate rating structured data.', 'AggregateRating', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, schema_org_type = EXCLUDED.schema_org_type;

-- ============================================================
-- 23.1 SEO ENTITIES
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_entities (
    seo_entity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_id UUID NULL,
    seo_entity_type_id UUID NOT NULL,

    entity_reference_id UUID NOT NULL,
    entity_url VARCHAR(1000) NOT NULL,
    entity_slug VARCHAR(500) NULL,

    seo_score INTEGER NULL,
    last_audited_at TIMESTAMPTZ NULL,
    last_updated_at TIMESTAMPTZ NULL,

    is_indexable BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_se_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_se_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_se_type FOREIGN KEY (seo_entity_type_id) REFERENCES seo.seo_entity_type_lookup(seo_entity_type_id),
    CONSTRAINT uq_se_entity UNIQUE (company_id, seo_entity_type_id, entity_reference_id)
);

CREATE INDEX ix_se_company ON seo.seo_entities(company_id);
CREATE INDEX ix_se_type ON seo.seo_entities(seo_entity_type_id);
CREATE INDEX ix_se_reference ON seo.seo_entities(entity_reference_id);
CREATE INDEX ix_se_url ON seo.seo_entities(entity_url);

-- ============================================================
-- 23.2 SEO METADATA
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_metadata (
    seo_metadata_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seo_entity_id UUID NOT NULL,

    meta_title VARCHAR(300) NULL,
    meta_description TEXT NULL,
    meta_keywords TEXT NULL,
    canonical_url VARCHAR(500) NULL,
    robots_directive VARCHAR(100) NULL,

    og_title VARCHAR(300) NULL,
    og_description TEXT NULL,
    og_image_url VARCHAR(500) NULL,
    og_type VARCHAR(50) NULL,

    twitter_card VARCHAR(50) NULL,
    twitter_title VARCHAR(300) NULL,
    twitter_description TEXT NULL,
    twitter_image_url VARCHAR(500) NULL,

    hreflang_tags JSONB NULL,

    is_auto_generated BOOLEAN NOT NULL DEFAULT FALSE,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sm_entity FOREIGN KEY (seo_entity_id) REFERENCES seo.seo_entities(seo_entity_id) ON DELETE CASCADE,
    CONSTRAINT uq_seo_metadata UNIQUE (seo_entity_id),
    CONSTRAINT ck_sm_robots CHECK (robots_directive IS NULL OR robots_directive IN ('index,follow', 'noindex,follow', 'index,nofollow', 'noindex,nofollow'))
);

CREATE INDEX ix_sm_entity ON seo.seo_metadata(seo_entity_id);

-- ============================================================
-- 23.5 STRUCTURED DATA (JSON-LD)
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_structured_data (
    seo_structured_data_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seo_entity_id UUID NOT NULL,
    structured_data_type_id UUID NOT NULL,

    json_ld_data JSONB NOT NULL,
    is_auto_generated BOOLEAN NOT NULL DEFAULT TRUE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ssd_entity FOREIGN KEY (seo_entity_id) REFERENCES seo.seo_entities(seo_entity_id) ON DELETE CASCADE,
    CONSTRAINT fk_ssd_type FOREIGN KEY (structured_data_type_id) REFERENCES seo.structured_data_type_lookup(structured_data_type_id),
    CONSTRAINT uq_structured_data UNIQUE (seo_entity_id, structured_data_type_id)
);

CREATE INDEX ix_ssd_entity ON seo.seo_structured_data(seo_entity_id);

-- ============================================================
-- 23.6 SEO KEYWORDS
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_keywords (
    seo_keyword_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    keyword VARCHAR(300) NOT NULL,
    keyword_group VARCHAR(200) NULL,
    search_volume INTEGER NULL,
    difficulty_score INTEGER NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sk_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_keyword UNIQUE (company_id, keyword)
);

CREATE INDEX ix_sk_company ON seo.seo_keywords(company_id);

-- SEO Entity Keywords (Many-to-Many)
CREATE TABLE IF NOT EXISTS seo.seo_entity_keywords (
    seo_entity_keyword_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seo_entity_id UUID NOT NULL,
    seo_keyword_id UUID NOT NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    relevance_score NUMERIC(5,2) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sek_entity FOREIGN KEY (seo_entity_id) REFERENCES seo.seo_entities(seo_entity_id) ON DELETE CASCADE,
    CONSTRAINT fk_sek_keyword FOREIGN KEY (seo_keyword_id) REFERENCES seo.seo_keywords(seo_keyword_id) ON DELETE CASCADE,
    CONSTRAINT uq_entity_keyword UNIQUE (seo_entity_id, seo_keyword_id)
);

CREATE INDEX ix_sek_entity ON seo.seo_entity_keywords(seo_entity_id);
CREATE INDEX ix_sek_keyword ON seo.seo_entity_keywords(seo_keyword_id);

-- ============================================================
-- 23.7 SEO REDIRECTS
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_redirects (
    seo_redirect_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_id UUID NULL,
    redirect_status_id UUID NOT NULL DEFAULT (SELECT redirect_status_id FROM seo.redirect_status_lookup WHERE code = 'ACTIVE'),

    source_path VARCHAR(1000) NOT NULL,
    target_path VARCHAR(1000) NOT NULL,
    redirect_type INTEGER NOT NULL DEFAULT 301,

    is_regex BOOLEAN NOT NULL DEFAULT FALSE,
    is_case_sensitive BOOLEAN NOT NULL DEFAULT FALSE,

    hit_count INTEGER NOT NULL DEFAULT 0,
    last_hit_at TIMESTAMPTZ NULL,

    start_date DATE NULL,
    end_date DATE NULL,

    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sr_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_sr_status FOREIGN KEY (redirect_status_id) REFERENCES seo.redirect_status_lookup(redirect_status_id),
    CONSTRAINT uq_redirect UNIQUE (company_id, source_path),
    CONSTRAINT ck_sr_type CHECK (redirect_type IN (301, 302, 307, 308)),
    CONSTRAINT ck_sr_not_self CHECK (source_path <> target_path)
);

CREATE INDEX ix_sr_company ON seo.seo_redirects(company_id);
CREATE INDEX ix_sr_source ON seo.seo_redirects(company_id, source_path);
CREATE INDEX ix_sr_target ON seo.seo_redirects(company_id, target_path);

-- ============================================================
-- 23.8 SITEMAPS
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_sitemaps (
    seo_sitemap_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_id UUID NULL,
    sitemap_type_id UUID NOT NULL,

    sitemap_url VARCHAR(500) NOT NULL,
    last_generated_at TIMESTAMPTZ NULL,
    entry_count INTEGER NOT NULL DEFAULT 0,

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    generation_frequency VARCHAR(20) NOT NULL DEFAULT 'DAILY',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ss_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ss_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_ss_type FOREIGN KEY (sitemap_type_id) REFERENCES seo.sitemap_type_lookup(sitemap_type_id),
    CONSTRAINT uq_sitemap UNIQUE (company_id, sitemap_type_id),
    CONSTRAINT ck_ss_frequency CHECK (generation_frequency IN ('HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY'))
);

CREATE INDEX ix_ss_company ON seo.seo_sitemaps(company_id);

-- Sitemap Entries
CREATE TABLE IF NOT EXISTS seo.seo_sitemap_entries (
    seo_sitemap_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seo_sitemap_id UUID NOT NULL,
    seo_entity_id UUID NOT NULL,

    url VARCHAR(1000) NOT NULL,
    last_modified_at TIMESTAMPTZ NULL,
    change_frequency VARCHAR(20) NOT NULL DEFAULT 'weekly',
    priority NUMERIC(3,2) NOT NULL DEFAULT 0.5,

    is_included BOOLEAN NOT NULL DEFAULT TRUE,
    included_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sse_sitemap FOREIGN KEY (seo_sitemap_id) REFERENCES seo.seo_sitemaps(seo_sitemap_id) ON DELETE CASCADE,
    CONSTRAINT fk_sse_entity FOREIGN KEY (seo_entity_id) REFERENCES seo.seo_entities(seo_entity_id) ON DELETE CASCADE,
    CONSTRAINT uq_sitemap_entry UNIQUE (seo_sitemap_id, seo_entity_id),
    CONSTRAINT ck_sse_frequency CHECK (change_frequency IN ('always', 'hourly', 'daily', 'weekly', 'monthly', 'yearly', 'never')),
    CONSTRAINT ck_sse_priority CHECK (priority >= 0 AND priority <= 1)
);

CREATE INDEX ix_sse_sitemap ON seo.seo_sitemap_entries(seo_sitemap_id);
CREATE INDEX ix_sse_entity ON seo.seo_sitemap_entries(seo_entity_id);

-- ============================================================
-- 23.9 ROBOTS.TXT
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_robots_txt (
    seo_robots_txt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_id UUID NULL,

    robots_content TEXT NOT NULL,
    is_custom BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_srt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_srt_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT uq_robots UNIQUE (company_id, site_id)
);

-- ============================================================
-- 23.10 SEO AUDITS
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_audits (
    seo_audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_id UUID NULL,
    seo_audit_status_id UUID NOT NULL DEFAULT (SELECT seo_audit_status_id FROM seo.seo_audit_status_lookup WHERE code = 'PENDING'),

    audit_name VARCHAR(300) NOT NULL,
    audit_scope VARCHAR(50) NOT NULL DEFAULT 'ALL',

    total_entities_audited INTEGER NOT NULL DEFAULT 0,
    total_issues_found INTEGER NOT NULL DEFAULT 0,
    critical_issues INTEGER NOT NULL DEFAULT 0,
    high_issues INTEGER NOT NULL DEFAULT 0,
    medium_issues INTEGER NOT NULL DEFAULT 0,
    low_issues INTEGER NOT NULL DEFAULT 0,
    info_issues INTEGER NOT NULL DEFAULT 0,

    average_seo_score NUMERIC(5,2) NULL,

    started_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_sa_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sa_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_sa_status FOREIGN KEY (seo_audit_status_id) REFERENCES seo.seo_audit_status_lookup(seo_audit_status_id),
    CONSTRAINT ck_sa_scope CHECK (audit_scope IN ('ALL', 'PAGES', 'PRODUCTS', 'CATEGORIES', 'BLOG_POSTS'))
);

CREATE INDEX ix_sa_company ON seo.seo_audits(company_id);
CREATE INDEX ix_sa_status ON seo.seo_audits(seo_audit_status_id);

-- ============================================================
-- 23.11 SEO AUDIT ISSUES
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_audit_issues (
    seo_audit_issue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seo_audit_id UUID NOT NULL,
    seo_entity_id UUID NOT NULL,
    seo_issue_type_id UUID NOT NULL,
    seo_issue_severity_id UUID NOT NULL,

    issue_message TEXT NOT NULL,
    recommendation TEXT NULL,

    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMPTZ NULL,
    resolved_by_user_id UUID NULL,
    resolution_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sai_audit FOREIGN KEY (seo_audit_id) REFERENCES seo.seo_audits(seo_audit_id) ON DELETE CASCADE,
    CONSTRAINT fk_sai_entity FOREIGN KEY (seo_entity_id) REFERENCES seo.seo_entities(seo_entity_id) ON DELETE CASCADE,
    CONSTRAINT fk_sai_issue_type FOREIGN KEY (seo_issue_type_id) REFERENCES seo.seo_issue_type_lookup(seo_issue_type_id),
    CONSTRAINT fk_sai_severity FOREIGN KEY (seo_issue_severity_id) REFERENCES seo.seo_issue_severity_lookup(seo_issue_severity_id)
);

CREATE INDEX ix_sai_audit ON seo.seo_audit_issues(seo_audit_id);
CREATE INDEX ix_sai_entity ON seo.seo_audit_issues(seo_entity_id);
CREATE INDEX ix_sai_issue_type ON seo.seo_audit_issues(seo_issue_type_id);
CREATE INDEX ix_sai_severity ON seo.seo_audit_issues(seo_issue_severity_id);
CREATE INDEX ix_sai_resolved ON seo.seo_audit_issues(is_resolved);

-- ============================================================
-- 23.12 IMAGE SEO
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_image_metadata (
    seo_image_metadata_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    seo_entity_type_id UUID NOT NULL,
    entity_reference_id UUID NOT NULL,

    image_url VARCHAR(1000) NOT NULL,
    alt_text VARCHAR(500) NULL,
    title VARCHAR(300) NULL,
    caption TEXT NULL,

    is_decorative BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_sim_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sim_type FOREIGN KEY (seo_entity_type_id) REFERENCES seo.seo_entity_type_lookup(seo_entity_type_id)
);

CREATE INDEX ix_sim_entity ON seo.seo_image_metadata(seo_entity_type_id, entity_reference_id);

-- ============================================================
-- 23.13 INTERNAL LINKING
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_internal_links (
    seo_internal_link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    source_entity_type_id UUID NOT NULL,
    source_entity_id UUID NOT NULL,
    target_entity_type_id UUID NOT NULL,
    target_entity_id UUID NOT NULL,

    anchor_text VARCHAR(300) NULL,
    link_position VARCHAR(50) NULL,

    click_count INTEGER NOT NULL DEFAULT 0,
    last_clicked_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sil_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sil_source_type FOREIGN KEY (source_entity_type_id) REFERENCES seo.seo_entity_type_lookup(seo_entity_type_id),
    CONSTRAINT fk_sil_target_type FOREIGN KEY (target_entity_type_id) REFERENCES seo.seo_entity_type_lookup(seo_entity_type_id),
    CONSTRAINT ck_sil_not_self CHECK (source_entity_id <> target_entity_id)
);

CREATE INDEX ix_sil_source ON seo.seo_internal_links(source_entity_type_id, source_entity_id);
CREATE INDEX ix_sil_target ON seo.seo_internal_links(target_entity_type_id, target_entity_id);

-- ============================================================
-- 23.14 SEO ANALYTICS
-- ============================================================

CREATE TABLE IF NOT EXISTS seo.seo_analytics (
    seo_analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seo_entity_id UUID NOT NULL,

    stat_date DATE NOT NULL,

    search_impressions INTEGER NOT NULL DEFAULT 0,
    search_clicks INTEGER NOT NULL DEFAULT 0,
    average_position NUMERIC(5,2) NULL,
    organic_traffic INTEGER NOT NULL DEFAULT 0,

    click_through_rate NUMERIC(7,4) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sana_entity FOREIGN KEY (seo_entity_id) REFERENCES seo.seo_entities(seo_entity_id) ON DELETE CASCADE,
    CONSTRAINT uq_seo_analytics UNIQUE (seo_entity_id, stat_date)
);

CREATE INDEX ix_sana_entity ON seo.seo_analytics(seo_entity_id);
CREATE INDEX ix_sana_date ON seo.seo_analytics(stat_date DESC);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_site_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT site_id INTO v_site_id FROM cms.sites WHERE company_id = v_company_id AND is_default = TRUE LIMIT 1;

    -- Create default robots.txt
    INSERT INTO seo.seo_robots_txt (company_id, site_id, robots_content, is_custom)
    SELECT v_company_id, v_site_id,
           'User-agent: *
Allow: /
Disallow: /admin/
Disallow: /checkout/
Disallow: /cart/
Disallow: /account/
Disallow: /preview/

Sitemap: https://www.estore.pk/sitemap.xml',
           FALSE
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_robots_txt WHERE company_id = v_company_id AND site_id = v_site_id);

    -- Create default sitemaps
    INSERT INTO seo.seo_sitemaps (company_id, site_id, sitemap_type_id, sitemap_url, generation_frequency)
    SELECT v_company_id, v_site_id,
           (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'PRODUCTS'),
           'https://www.estore.pk/sitemap-products.xml', 'DAILY'
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_sitemaps WHERE company_id = v_company_id AND sitemap_type_id = (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'PRODUCTS'));

    INSERT INTO seo.seo_sitemaps (company_id, site_id, sitemap_type_id, sitemap_url, generation_frequency)
    SELECT v_company_id, v_site_id,
           (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'CATEGORIES'),
           'https://www.estore.pk/sitemap-categories.xml', 'WEEKLY'
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_sitemaps WHERE company_id = v_company_id AND sitemap_type_id = (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'CATEGORIES'));

    INSERT INTO seo.seo_sitemaps (company_id, site_id, sitemap_type_id, sitemap_url, generation_frequency)
    SELECT v_company_id, v_site_id,
           (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'BLOG'),
           'https://www.estore.pk/sitemap-blog.xml', 'DAILY'
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_sitemaps WHERE company_id = v_company_id AND sitemap_type_id = (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'BLOG'));

    INSERT INTO seo.seo_sitemaps (company_id, site_id, sitemap_type_id, sitemap_url, generation_frequency)
    SELECT v_company_id, v_site_id,
           (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'PAGES'),
           'https://www.estore.pk/sitemap-pages.xml', 'WEEKLY'
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_sitemaps WHERE company_id = v_company_id AND sitemap_type_id = (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'PAGES'));

    INSERT INTO seo.seo_sitemaps (company_id, site_id, sitemap_type_id, sitemap_url, generation_frequency)
    SELECT v_company_id, v_site_id,
           (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'INDEX'),
           'https://www.estore.pk/sitemap-index.xml', 'DAILY'
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_sitemaps WHERE company_id = v_company_id AND sitemap_type_id = (SELECT sitemap_type_id FROM seo.sitemap_type_lookup WHERE code = 'INDEX'));

    -- Create default SEO keywords
    INSERT INTO seo.seo_keywords (company_id, keyword, keyword_group, search_volume, is_primary)
    SELECT v_company_id, 'buy wallet online', 'Wallets', 5000, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_keywords WHERE company_id = v_company_id AND keyword = 'buy wallet online');

    INSERT INTO seo.seo_keywords (company_id, keyword, keyword_group, search_volume, is_primary)
    SELECT v_company_id, 'leather wallet pakistan', 'Wallets', 2000, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_keywords WHERE company_id = v_company_id AND keyword = 'leather wallet pakistan');

    INSERT INTO seo.seo_keywords (company_id, keyword, keyword_group, search_volume, is_primary)
    SELECT v_company_id, 'laptop bag', 'Bags', 3000, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_keywords WHERE company_id = v_company_id AND keyword = 'laptop bag');

    INSERT INTO seo.seo_keywords (company_id, keyword, keyword_group, search_volume, is_primary)
    SELECT v_company_id, 'running shoes', 'Shoes', 8000, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM seo.seo_keywords WHERE company_id = v_company_id AND keyword = 'running shoes');

END $$;

COMMIT;