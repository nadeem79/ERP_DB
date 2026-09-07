BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 22 — BLOG & EDITORIAL CONTENT
-- DATABASE TABLES
-- ============================================================
-- Architecture Principles:
--   1. Blog builds on top of CMS (Module 21) — uses CMS blocks
--   2. Blog references Product Catalog for related products
--   3. Blog connects to Marketing, Affiliate, Newsletter, Loyalty
--   4. Editorial workflow: DRAFT → IN_REVIEW → CHANGES_REQUESTED
--      → APPROVED → SCHEDULED → PUBLISHED
--   5. Comments need moderation workflow
--   6. Blog is NOT a separate content engine — extends CMS
-- ============================================================
-- Components:
--   22.1  Blog Sites
--   22.2  Blog Posts
--   22.3  Post Content Types & Statuses
--   22.4  Post Versions / Revisions
--   22.5  Blog Categories
--   22.6  Blog Tags
--   22.7  Blog Authors
--   22.8  Post Media / Featured Images
--   22.9  Post Content Blocks (CMS Integration)
--   22.10 Related Products
--   22.11 Related Posts & Relations
--   22.12 Blog Series
--   22.13 Editorial Workflow & Publishing
--   22.14 Comments & Moderation
--   22.15 Post SEO Metadata
--   22.16 Post Statistics & Analytics
--   22.17 Publishing History
-- ============================================================

CREATE SCHEMA IF NOT EXISTS blog;

-- ============================================================
-- 22.0 BLOG LOOKUPS
-- ============================================================

-- Blog Post Status
CREATE TABLE IF NOT EXISTS blog.blog_post_status_lookup (
    blog_post_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO blog.blog_post_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Post is being written.', 10),
    ('IN_REVIEW', 'In Review', 'Post submitted for editorial review.', 20),
    ('CHANGES_REQUESTED', 'Changes Requested', 'Reviewer requested changes.', 30),
    ('APPROVED', 'Approved', 'Post approved for publishing.', 40),
    ('SCHEDULED', 'Scheduled', 'Post scheduled for future publish.', 50),
    ('PUBLISHED', 'Published', 'Post is live on the blog.', 60),
    ('UNPUBLISHED', 'Unpublished', 'Post was taken offline.', 70),
    ('ARCHIVED', 'Archived', 'Post archived.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Blog Post Content Type
CREATE TABLE IF NOT EXISTS blog.blog_post_content_type_lookup (
    blog_post_content_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO blog.blog_post_content_type_lookup (code, name, description, sort_order) VALUES
    ('ARTICLE', 'Article', 'Standard blog article.', 10),
    ('NEWS', 'News', 'News announcement.', 20),
    ('TUTORIAL', 'Tutorial', 'Step-by-step tutorial.', 30),
    ('GUIDE', 'Guide', 'Comprehensive guide.', 40),
    ('REVIEW', 'Review', 'Product or service review.', 50),
    ('ANNOUNCEMENT', 'Announcement', 'Company announcement.', 60),
    ('EVENT', 'Event', 'Event information.', 70),
    ('FAQ', 'FAQ', 'Frequently asked questions.', 80),
    ('CASE_STUDY', 'Case Study', 'Customer case study.', 90),
    ('OPINION', 'Opinion', 'Opinion or editorial piece.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Blog Comment Status
CREATE TABLE IF NOT EXISTS blog.blog_comment_status_lookup (
    blog_comment_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO blog.blog_comment_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING_MODERATION', 'Pending Moderation', 'Awaiting moderator review.', 10),
    ('APPROVED', 'Approved', 'Comment approved and visible.', 20),
    ('REJECTED', 'Rejected', 'Comment rejected.', 30),
    ('SPAM', 'Spam', 'Identified as spam.', 40),
    ('FLAGGED', 'Flagged', 'Flagged for review.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Blog Post Relation Type
CREATE TABLE IF NOT EXISTS blog.blog_post_relation_type_lookup (
    blog_post_relation_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO blog.blog_post_relation_type_lookup (code, name, description, sort_order) VALUES
    ('RELATED', 'Related', 'Generally related content.', 10),
    ('NEXT', 'Next', 'Next post in sequence.', 20),
    ('PREVIOUS', 'Previous', 'Previous post in sequence.', 30),
    ('FOLLOW_UP', 'Follow Up', 'Follow-up to another post.', 40),
    ('SERIES', 'Series', 'Part of a series.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Blog Author Role
CREATE TABLE IF NOT EXISTS blog.blog_author_role_lookup (
    blog_author_role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO blog.blog_author_role_lookup (code, name, description, sort_order) VALUES
    ('AUTHOR', 'Author', 'Primary author of the post.', 10),
    ('CO_AUTHOR', 'Co-Author', 'Co-author of the post.', 20),
    ('EDITOR', 'Editor', 'Editor who reviewed the post.', 30),
    ('REVIEWER', 'Reviewer', 'Reviewer who approved the post.', 40),
    ('CONTRIBUTOR', 'Contributor', 'Contributed content to the post.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 22.1 BLOG SITES
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_sites (
    blog_site_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_id UUID NULL,

    blog_code VARCHAR(50) NOT NULL,
    blog_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    base_url VARCHAR(500) NULL,
    default_language_code VARCHAR(10) NOT NULL DEFAULT 'en',

    posts_per_page INTEGER NOT NULL DEFAULT 10,
    allow_comments BOOLEAN NOT NULL DEFAULT TRUE,
    require_comment_moderation BOOLEAN NOT NULL DEFAULT TRUE,
    allow_guest_comments BOOLEAN NOT NULL DEFAULT FALSE,

    rss_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    rss_item_count INTEGER NOT NULL DEFAULT 20,

    featured_image_width INTEGER NULL,
    featured_image_height INTEGER NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_bs_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_bs_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT uq_blog_code UNIQUE (company_id, blog_code)
);

CREATE INDEX ix_bs_company ON blog.blog_sites(company_id);

-- ============================================================
-- 22.7 BLOG AUTHORS
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_authors (
    blog_author_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    person_id UUID NULL,
    user_id UUID NULL,
    employee_id UUID NULL,

    author_code VARCHAR(50) NOT NULL,
    display_name VARCHAR(200) NOT NULL,
    bio TEXT NULL,
    avatar_url VARCHAR(500) NULL,

    email VARCHAR(300) NULL,
    website_url VARCHAR(500) NULL,
    social_links JSONB NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ba_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ba_person FOREIGN KEY (person_id) REFERENCES identity.persons(person_id),
    CONSTRAINT fk_ba_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_ba_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT uq_author_code UNIQUE (company_id, author_code)
);

CREATE INDEX ix_ba_company ON blog.blog_authors(company_id);

-- ============================================================
-- 22.2 BLOG POSTS
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_posts (
    blog_post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_site_id UUID NOT NULL,
    company_id UUID NOT NULL,
    blog_post_status_id UUID NOT NULL DEFAULT (SELECT blog_post_status_id FROM blog.blog_post_status_lookup WHERE code = 'DRAFT'),
    blog_post_content_type_id UUID NOT NULL DEFAULT (SELECT blog_post_content_type_id FROM blog.blog_post_content_type_lookup WHERE code = 'ARTICLE'),
    blog_series_id UUID NULL,

    post_number VARCHAR(50) NOT NULL,
    title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) NOT NULL,
    excerpt TEXT NULL,
    summary TEXT NULL,
    content_html TEXT NULL,
    content_markdown TEXT NULL,

    featured_image_url VARCHAR(500) NULL,
    featured_image_alt VARCHAR(300) NULL,

    author_blog_author_id UUID NULL,
    author_person_id UUID NULL,
    author_user_id UUID NULL,

    reading_time_minutes INTEGER NULL,
    word_count INTEGER NULL,

    published_at TIMESTAMPTZ NULL,
    scheduled_publish_at TIMESTAMPTZ NULL,
    scheduled_unpublish_at TIMESTAMPTZ NULL,
    unpublished_at TIMESTAMPTZ NULL,

    current_version INTEGER NOT NULL DEFAULT 1,
    published_version INTEGER NULL,

    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    allow_comments BOOLEAN NOT NULL DEFAULT TRUE,

    view_count INTEGER NOT NULL DEFAULT 0,
    like_count INTEGER NOT NULL DEFAULT 0,
    share_count INTEGER NOT NULL DEFAULT 0,
    comment_count INTEGER NOT NULL DEFAULT 0,

    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_bp_site FOREIGN KEY (blog_site_id) REFERENCES blog.blog_sites(blog_site_id),
    CONSTRAINT fk_bp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_bp_status FOREIGN KEY (blog_post_status_id) REFERENCES blog.blog_post_status_lookup(blog_post_status_id),
    CONSTRAINT fk_bp_content_type FOREIGN KEY (blog_post_content_type_id) REFERENCES blog.blog_post_content_type_lookup(blog_post_content_type_id),
    CONSTRAINT fk_bp_author FOREIGN KEY (author_blog_author_id) REFERENCES blog.blog_authors(blog_author_id),
    CONSTRAINT fk_bp_person FOREIGN KEY (author_person_id) REFERENCES identity.persons(person_id),
    CONSTRAINT fk_bp_user FOREIGN KEY (author_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_post_number UNIQUE (blog_site_id, post_number),
    CONSTRAINT uq_post_slug UNIQUE (blog_site_id, slug)
);

CREATE INDEX ix_bp_site ON blog.blog_posts(blog_site_id);
CREATE INDEX ix_bp_status ON blog.blog_posts(blog_post_status_id);
CREATE INDEX ix_bp_content_type ON blog.blog_posts(blog_post_content_type_id);
CREATE INDEX ix_bp_author ON blog.blog_posts(author_blog_author_id);
CREATE INDEX ix_bp_published ON blog.blog_posts(published_at DESC);
CREATE INDEX ix_bp_featured ON blog.blog_posts(is_featured, published_at DESC);

-- ============================================================
-- 22.4 BLOG POST VERSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_post_versions (
    blog_post_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,

    version_number INTEGER NOT NULL,
    title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) NULL,
    excerpt TEXT NULL,
    content_html TEXT NULL,
    content_markdown TEXT NULL,

    change_description TEXT NULL,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_bpv_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT uq_post_version UNIQUE (blog_post_id, version_number)
);

CREATE INDEX ix_bpv_post ON blog.blog_post_versions(blog_post_id);

-- ============================================================
-- 22.5 BLOG CATEGORIES
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_categories (
    blog_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_site_id UUID NOT NULL,
    parent_category_id UUID NULL,

    category_code VARCHAR(100) NOT NULL,
    category_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    slug VARCHAR(200) NOT NULL,

    image_url VARCHAR(500) NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,

    post_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_bc_site FOREIGN KEY (blog_site_id) REFERENCES blog.blog_sites(blog_site_id),
    CONSTRAINT fk_bc_parent FOREIGN KEY (parent_category_id) REFERENCES blog.blog_categories(blog_category_id),
    CONSTRAINT uq_category_code UNIQUE (blog_site_id, category_code),
    CONSTRAINT uq_category_slug UNIQUE (blog_site_id, slug)
);

CREATE INDEX ix_bc_site ON blog.blog_categories(blog_site_id);
CREATE INDEX ix_bc_parent ON blog.blog_categories(parent_category_id);

-- Blog Post Categories (Many-to-Many)
CREATE TABLE IF NOT EXISTS blog.blog_post_categories (
    blog_post_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,
    blog_category_id UUID NOT NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bpc_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_bpc_category FOREIGN KEY (blog_category_id) REFERENCES blog.blog_categories(blog_category_id) ON DELETE CASCADE,
    CONSTRAINT uq_post_category UNIQUE (blog_post_id, blog_category_id)
);

CREATE INDEX ix_bpc_post ON blog.blog_post_categories(blog_post_id);
CREATE INDEX ix_bpc_category ON blog.blog_post_categories(blog_category_id);

-- ============================================================
-- 22.6 BLOG TAGS
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_tags (
    blog_tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_site_id UUID NOT NULL,

    tag_code VARCHAR(100) NOT NULL,
    tag_name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL,

    post_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_bt_site FOREIGN KEY (blog_site_id) REFERENCES blog.blog_sites(blog_site_id),
    CONSTRAINT uq_tag_code UNIQUE (blog_site_id, tag_code),
    CONSTRAINT uq_tag_slug UNIQUE (blog_site_id, slug)
);

CREATE INDEX ix_bt_site ON blog.blog_tags(blog_site_id);

-- Blog Post Tags (Many-to-Many)
CREATE TABLE IF NOT EXISTS blog.blog_post_tags (
    blog_post_tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,
    blog_tag_id UUID NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bpt_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_bpt_tag FOREIGN KEY (blog_tag_id) REFERENCES blog.blog_tags(blog_tag_id) ON DELETE CASCADE,
    CONSTRAINT uq_post_tag UNIQUE (blog_post_id, blog_tag_id)
);

CREATE INDEX ix_bpt_post ON blog.blog_post_tags(blog_post_id);
CREATE INDEX ix_bpt_tag ON blog.blog_post_tags(blog_tag_id);

-- ============================================================
-- 22.8 BLOG POST MEDIA
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_post_media (
    blog_post_media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,

    media_type VARCHAR(30) NOT NULL DEFAULT 'IMAGE',
    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,

    file_name VARCHAR(500) NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,

    alt_text VARCHAR(300) NULL,
    caption TEXT NULL,

    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bpm_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT ck_bpm_type CHECK (media_type IN ('IMAGE', 'VIDEO', 'AUDIO', 'DOCUMENT'))
);

CREATE INDEX ix_bpm_post ON blog.blog_post_media(blog_post_id);

-- ============================================================
-- 22.9 BLOG POST BLOCKS (CMS Integration)
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_post_blocks (
    blog_post_block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,
    content_block_id UUID NOT NULL,

    block_override_config JSONB NULL,
    custom_content TEXT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bpb_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_bpb_block FOREIGN KEY (content_block_id) REFERENCES cms.content_blocks(content_block_id),
    CONSTRAINT uq_post_block UNIQUE (blog_post_id, content_block_id, sort_order)
);

CREATE INDEX ix_bpb_post ON blog.blog_post_blocks(blog_post_id);
CREATE INDEX ix_bpb_block ON blog.blog_post_blocks(content_block_id);

-- ============================================================
-- 22.10 RELATED PRODUCTS
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_post_products (
    blog_post_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    relation_type VARCHAR(30) NOT NULL DEFAULT 'MENTIONED',
    custom_description TEXT NULL,
    cta_text VARCHAR(200) NULL,
    cta_url VARCHAR(500) NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bpp_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_bpp_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_bpp_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_bpp_relation CHECK (relation_type IN ('MENTIONED', 'REVIEWED', 'FEATURED', 'RECOMMENDED', 'COMPARED'))
);

CREATE INDEX ix_bpp_post ON blog.blog_post_products(blog_post_id);
CREATE INDEX ix_bpp_product ON blog.blog_post_products(product_id);

-- ============================================================
-- 22.11 RELATED POSTS & RELATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_post_relations (
    blog_post_relation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,
    related_blog_post_id UUID NOT NULL,
    blog_post_relation_type_id UUID NOT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bpr_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_bpr_related FOREIGN KEY (related_blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_bpr_type FOREIGN KEY (blog_post_relation_type_id) REFERENCES blog.blog_post_relation_type_lookup(blog_post_relation_type_id),
    CONSTRAINT uq_post_relation UNIQUE (blog_post_id, related_blog_post_id, blog_post_relation_type_id),
    CONSTRAINT ck_bpr_not_self CHECK (blog_post_id <> related_blog_post_id)
);

CREATE INDEX ix_bpr_post ON blog.blog_post_relations(blog_post_id);
CREATE INDEX ix_bpr_related ON blog.blog_post_relations(related_blog_post_id);

-- ============================================================
-- 22.12 BLOG SERIES
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_series (
    blog_series_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_site_id UUID NOT NULL,

    series_name VARCHAR(300) NOT NULL,
    slug VARCHAR(300) NOT NULL,
    description TEXT NULL,

    image_url VARCHAR(500) NULL,
    total_parts INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_bsrs_site FOREIGN KEY (blog_site_id) REFERENCES blog.blog_sites(blog_site_id),
    CONSTRAINT uq_series_slug UNIQUE (blog_site_id, slug)
);

CREATE INDEX ix_bsrs_site ON blog.blog_series(blog_site_id);

-- Blog Series Posts
CREATE TABLE IF NOT EXISTS blog.blog_series_posts (
    blog_series_post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_series_id UUID NOT NULL,
    blog_post_id UUID NOT NULL,

    part_number INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bsp_series FOREIGN KEY (blog_series_id) REFERENCES blog.blog_series(blog_series_id) ON DELETE CASCADE,
    CONSTRAINT fk_bsp_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT uq_series_post UNIQUE (blog_series_id, blog_post_id),
    CONSTRAINT uq_series_part UNIQUE (blog_series_id, part_number)
);

CREATE INDEX ix_bsp_series ON blog.blog_series_posts(blog_series_id);
CREATE INDEX ix_bsp_post ON blog.blog_series_posts(blog_post_id);

-- ============================================================
-- 22.14 COMMENTS & MODERATION
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_comments (
    blog_comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,
    blog_comment_status_id UUID NOT NULL DEFAULT (SELECT blog_comment_status_id FROM blog.blog_comment_status_lookup WHERE code = 'PENDING_MODERATION'),
    parent_comment_id UUID NULL,

    customer_id UUID NULL,
    user_id UUID NULL,

    author_name VARCHAR(200) NOT NULL,
    author_email VARCHAR(300) NULL,
    author_website VARCHAR(500) NULL,

    comment_text TEXT NOT NULL,

    ip_address INET NULL,
    user_agent TEXT NULL,

    is_spam BOOLEAN NOT NULL DEFAULT FALSE,
    spam_score NUMERIC(5,2) NULL,

    like_count INTEGER NOT NULL DEFAULT 0,
    reply_count INTEGER NOT NULL DEFAULT 0,

    moderated_by_user_id UUID NULL,
    moderated_at TIMESTAMPTZ NULL,
    moderation_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bcm_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_bcm_status FOREIGN KEY (blog_comment_status_id) REFERENCES blog.blog_comment_status_lookup(blog_comment_status_id),
    CONSTRAINT fk_bcm_parent FOREIGN KEY (parent_comment_id) REFERENCES blog.blog_comments(blog_comment_id) ON DELETE CASCADE,
    CONSTRAINT fk_bcm_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_bcm_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id)
);

CREATE INDEX ix_bcm_post ON blog.blog_comments(blog_post_id);
CREATE INDEX ix_bcm_status ON blog.blog_comments(blog_comment_status_id);
CREATE INDEX ix_bcm_customer ON blog.blog_comments(customer_id);

-- ============================================================
-- 22.15 BLOG POST SEO
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_post_seo (
    blog_post_seo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,

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

    structured_data JSONB NULL,
    sitemap_priority NUMERIC(3,2) NULL,
    exclude_from_sitemap BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_bpseo_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT uq_post_seo UNIQUE (blog_post_id)
);

-- ============================================================
-- 22.16 BLOG POST STATISTICS
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_post_statistics (
    blog_post_statistic_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,

    stat_date DATE NOT NULL,

    view_count INTEGER NOT NULL DEFAULT 0,
    unique_view_count INTEGER NOT NULL DEFAULT 0,
    like_count INTEGER NOT NULL DEFAULT 0,
    share_count INTEGER NOT NULL DEFAULT 0,
    comment_count INTEGER NOT NULL DEFAULT 0,

    avg_time_on_page_seconds INTEGER NULL,
    bounce_rate NUMERIC(5,2) NULL,

    product_click_count INTEGER NOT NULL DEFAULT 0,
    conversion_count INTEGER NOT NULL DEFAULT 0,
    conversion_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    traffic_source_organic INTEGER NOT NULL DEFAULT 0,
    traffic_source_social INTEGER NOT NULL DEFAULT 0,
    traffic_source_direct INTEGER NOT NULL DEFAULT 0,
    traffic_source_referral INTEGER NOT NULL DEFAULT 0,
    traffic_source_email INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bps_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT uq_post_stat UNIQUE (blog_post_id, stat_date)
);

CREATE INDEX ix_bps_post ON blog.blog_post_statistics(blog_post_id);
CREATE INDEX ix_bps_date ON blog.blog_post_statistics(stat_date DESC);

-- ============================================================
-- 22.17 PUBLISHING HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS blog.blog_publishing_history (
    blog_publishing_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blog_post_id UUID NOT NULL,

    action VARCHAR(30) NOT NULL,
    from_status VARCHAR(30) NULL,
    to_status VARCHAR(30) NOT NULL,
    version_number INTEGER NULL,

    performed_by_user_id UUID NULL,
    notes TEXT NULL,

    performed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bph_post FOREIGN KEY (blog_post_id) REFERENCES blog.blog_posts(blog_post_id) ON DELETE CASCADE,
    CONSTRAINT ck_bph_action CHECK (action IN ('CREATE', 'SUBMIT_REVIEW', 'REQUEST_CHANGES', 'APPROVE', 'REJECT', 'SCHEDULE', 'PUBLISH', 'UNPUBLISH', 'ARCHIVE', 'RESTORE', 'REVISION'))
);

CREATE INDEX ix_bph_post ON blog.blog_publishing_history(blog_post_id);
CREATE INDEX ix_bph_performed ON blog.blog_publishing_history(performed_at DESC);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_blog_site_id UUID;
    v_cms_site_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT site_id INTO v_cms_site_id FROM cms.sites WHERE company_id = v_company_id AND is_default = TRUE LIMIT 1;

    -- Create default blog site
    INSERT INTO blog.blog_sites (company_id, site_id, blog_code, blog_name, description, base_url)
    SELECT v_company_id, v_cms_site_id, 'MAIN-BLOG', 'eStore Blog', 'Official blog of eStore Pakistan.', 'https://www.estore.pk/blog'
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_sites WHERE company_id = v_company_id AND blog_code = 'MAIN-BLOG')
    RETURNING blog_site_id INTO v_blog_site_id;

    IF v_blog_site_id IS NULL THEN
        SELECT blog_site_id INTO v_blog_site_id FROM blog.blog_sites WHERE company_id = v_company_id AND blog_code = 'MAIN-BLOG';
    END IF;

    -- Create default blog categories
    INSERT INTO blog.blog_categories (blog_site_id, category_code, category_name, slug, sort_order)
    SELECT v_blog_site_id, 'PRODUCT-NEWS', 'Product News', 'product-news', 10
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_categories WHERE blog_site_id = v_blog_site_id AND category_code = 'PRODUCT-NEWS');

    INSERT INTO blog.blog_categories (blog_site_id, category_code, category_name, slug, sort_order)
    SELECT v_blog_site_id, 'TUTORIALS', 'Tutorials & Guides', 'tutorials', 20
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_categories WHERE blog_site_id = v_blog_site_id AND category_code = 'TUTORIALS');

    INSERT INTO blog.blog_categories (blog_site_id, category_code, category_name, slug, sort_order)
    SELECT v_blog_site_id, 'REVIEWS', 'Product Reviews', 'reviews', 30
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_categories WHERE blog_site_id = v_blog_site_id AND category_code = 'REVIEWS');

    INSERT INTO blog.blog_categories (blog_site_id, category_code, category_name, slug, sort_order)
    SELECT v_blog_site_id, 'COMPANY-NEWS', 'Company News', 'company-news', 40
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_categories WHERE blog_site_id = v_blog_site_id AND category_code = 'COMPANY-NEWS');

    INSERT INTO blog.blog_categories (blog_site_id, category_code, category_name, slug, sort_order)
    SELECT v_blog_site_id, 'TECH-TIPS', 'Tech Tips', 'tech-tips', 50
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_categories WHERE blog_site_id = v_blog_site_id AND category_code = 'TECH-TIPS');

    -- Create default blog tags
    INSERT INTO blog.blog_tags (blog_site_id, tag_code, tag_name, slug)
    SELECT v_blog_site_id, 'NEW-ARRIVAL', 'New Arrival', 'new-arrival'
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_tags WHERE blog_site_id = v_blog_site_id AND tag_code = 'NEW-ARRIVAL');

    INSERT INTO blog.blog_tags (blog_site_id, tag_code, tag_name, slug)
    SELECT v_blog_site_id, 'SALE', 'Sale', 'sale'
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_tags WHERE blog_site_id = v_blog_site_id AND tag_code = 'SALE');

    INSERT INTO blog.blog_tags (blog_site_id, tag_code, tag_name, slug)
    SELECT v_blog_site_id, 'HOW-TO', 'How To', 'how-to'
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_tags WHERE blog_site_id = v_blog_site_id AND tag_code = 'HOW-TO');

    INSERT INTO blog.blog_tags (blog_site_id, tag_code, tag_name, slug)
    SELECT v_blog_site_id, 'COMPARISON', 'Comparison', 'comparison'
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_tags WHERE blog_site_id = v_blog_site_id AND tag_code = 'COMPARISON');

    -- Create a sample blog author
    INSERT INTO blog.blog_authors (company_id, author_code, display_name, bio, is_active)
    SELECT v_company_id, 'AUTHOR-001', 'eStore Editorial Team', 'Official editorial team of eStore Pakistan.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_authors WHERE company_id = v_company_id AND author_code = 'AUTHOR-001');

    -- Create a sample blog series
    INSERT INTO blog.blog_series (blog_site_id, series_name, slug, description, total_parts)
    SELECT v_blog_site_id, 'Getting Started Guide', 'getting-started-guide', 'A complete guide for new customers.', 4
    WHERE NOT EXISTS (SELECT 1 FROM blog.blog_series WHERE blog_site_id = v_blog_site_id AND slug = 'getting-started-guide');

END $$;

COMMIT;