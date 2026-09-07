BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 21 — CMS / WEBSITE PAGES / CONTENT BLOCKS
-- DATABASE TABLES
-- ============================================================
-- Architecture Principles:
--   1. CMS is NOT an ERP database — it references other modules
--   2. Reusable blocks — blocks used across multiple pages
--   3. Version everything important
--   4. Draft must never accidentally become public
--   5. Preview is first-class (Next.js preview mode)
--   6. CMS is headless (.NET stores, Next.js renders)
-- ============================================================
-- Components:
--   21.1  Sites & Domains
--   21.2  Pages & Page Types
--   21.3  Page Versions & Revisions
--   21.4  Page Sections
--   21.5  Content Blocks & Block Types
--   21.6  Content Translations
--   21.7  Navigation / Menus / Menu Items
--   21.8  Landing Pages
--   21.9  Forms / Fields / Submissions
--   21.10 Redirects
--   21.11 Page SEO Metadata
--   21.12 Publishing Workflow & History
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cms;

-- ============================================================
-- 21.0 CMS LOOKUPS
-- ============================================================

-- Site Status
CREATE TABLE IF NOT EXISTS cms.site_status_lookup (
    site_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.site_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Site is live and accessible.', 10),
    ('MAINTENANCE', 'Maintenance', 'Site is under maintenance.', 20),
    ('INACTIVE', 'Inactive', 'Site is disabled.', 30),
    ('COMING_SOON', 'Coming Soon', 'Site is in pre-launch.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Page Status
CREATE TABLE IF NOT EXISTS cms.page_status_lookup (
    page_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.page_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Page is being edited.', 10),
    ('REVIEW', 'In Review', 'Page submitted for review.', 20),
    ('APPROVED', 'Approved', 'Page approved for publishing.', 30),
    ('PUBLISHED', 'Published', 'Page is live on the website.', 40),
    ('UNPUBLISHED', 'Unpublished', 'Page was taken offline.', 50),
    ('ARCHIVED', 'Archived', 'Page archived.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Page Type
CREATE TABLE IF NOT EXISTS cms.page_type_lookup (
    page_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.page_type_lookup (code, name, description, is_system, sort_order) VALUES
    ('HOME', 'Home Page', 'Main landing/home page.', TRUE, 10),
    ('ABOUT', 'About Us', 'Company about page.', FALSE, 20),
    ('CONTACT', 'Contact', 'Contact information page.', FALSE, 30),
    ('PRODUCT', 'Product Page', 'Individual product display.', TRUE, 40),
    ('CATEGORY', 'Category Page', 'Product category listing.', TRUE, 50),
    ('COLLECTION', 'Collection', 'Curated product collection.', FALSE, 60),
    ('BLOG', 'Blog', 'Blog listing page.', FALSE, 70),
    ('BLOG_POST', 'Blog Post', 'Individual blog article.', FALSE, 80),
    ('LANDING', 'Landing Page', 'Marketing landing page.', FALSE, 90),
    ('LEGAL', 'Legal', 'Terms, privacy, policies.', FALSE, 100),
    ('FAQ', 'FAQ', 'Frequently asked questions.', FALSE, 110),
    ('SEARCH', 'Search Results', 'Search results page.', TRUE, 120),
    ('ACCOUNT', 'Account', 'Customer account pages.', TRUE, 130),
    ('CART', 'Cart', 'Shopping cart page.', TRUE, 140),
    ('CHECKOUT', 'Checkout', 'Checkout process pages.', TRUE, 150),
    ('ERROR_404', '404 Error', 'Page not found.', TRUE, 160),
    ('ERROR_500', '500 Error', 'Server error page.', TRUE, 170),
    ('CUSTOM', 'Custom', 'Custom content page.', FALSE, 180)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Block Type
CREATE TABLE IF NOT EXISTS cms.block_type_lookup (
    block_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    icon_url VARCHAR(500) NULL,
    default_config JSONB NULL,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.block_type_lookup (code, name, description, is_system, sort_order) VALUES
    ('HERO', 'Hero Banner', 'Large hero section with image/video and CTA.', TRUE, 10),
    ('TEXT', 'Text Block', 'Rich text content block.', TRUE, 20),
    ('IMAGE', 'Image', 'Single image block.', TRUE, 30),
    ('IMAGE_TEXT', 'Image + Text', 'Image with text side by side.', TRUE, 40),
    ('VIDEO', 'Video', 'Embedded video block.', TRUE, 50),
    ('PRODUCT_GRID', 'Product Grid', 'Grid of featured products.', TRUE, 60),
    ('PRODUCT_CAROUSEL', 'Product Carousel', 'Scrollable product showcase.', TRUE, 70),
    ('CATEGORY_GRID', 'Category Grid', 'Grid of product categories.', TRUE, 80),
    ('TESTIMONIAL', 'Testimonial', 'Customer testimonial block.', TRUE, 90),
    ('FAQ', 'FAQ Accordion', 'Frequently asked questions accordion.', TRUE, 100),
    ('BANNER', 'Promotional Banner', 'Promotional/sale banner.', TRUE, 110),
    ('CTA', 'Call to Action', 'CTA button section.', TRUE, 120),
    ('NEWSLETTER_SIGNUP', 'Newsletter Signup', 'Email subscription form.', TRUE, 130),
    ('SOCIAL_FEED', 'Social Feed', 'Social media feed embed.', TRUE, 140),
    ('FEATURES', 'Features Grid', 'Feature highlights grid.', TRUE, 150),
    ('STATS', 'Statistics', 'Numbers/statistics display.', TRUE, 160),
    ('TIMELINE', 'Timeline', 'Timeline/history display.', FALSE, 170),
    ('TEAM', 'Team Members', 'Team member profiles.', FALSE, 180),
    ('GALLERY', 'Image Gallery', 'Image gallery grid.', FALSE, 190),
    ('CUSTOM_HTML', 'Custom HTML', 'Raw HTML content.', FALSE, 200),
    ('DIVIDER', 'Divider', 'Visual separator.', TRUE, 210),
    ('SPACER', 'Spacer', 'Vertical spacing.', TRUE, 220)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Menu Item Link Type
CREATE TABLE IF NOT EXISTS cms.menu_link_type_lookup (
    menu_link_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.menu_link_type_lookup (code, name, description, sort_order) VALUES
    ('URL', 'External URL', 'Direct URL link.', 10),
    ('PAGE', 'CMS Page', 'Link to a CMS page.', 20),
    ('PRODUCT', 'Product', 'Link to a product.', 30),
    ('CATEGORY', 'Category', 'Link to a product category.', 40),
    ('COLLECTION', 'Collection', 'Link to a collection.', 50),
    ('BLOG', 'Blog', 'Link to blog listing.', 60),
    ('BLOG_POST', 'Blog Post', 'Link to specific blog post.', 70),
    ('SEARCH', 'Search', 'Link to search page.', 80),
    ('CUSTOM', 'Custom Route', 'Custom frontend route.', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Form Field Type
CREATE TABLE IF NOT EXISTS cms.form_field_type_lookup (
    form_field_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.form_field_type_lookup (code, name, description, sort_order) VALUES
    ('TEXT', 'Text Input', 'Single line text input.', 10),
    ('TEXTAREA', 'Text Area', 'Multi-line text input.', 20),
    ('EMAIL', 'Email', 'Email address input.', 30),
    ('PHONE', 'Phone', 'Phone number input.', 40),
    ('NUMBER', 'Number', 'Numeric input.', 50),
    ('DATE', 'Date', 'Date picker.', 60),
    ('SELECT', 'Dropdown', 'Dropdown selection.', 70),
    ('RADIO', 'Radio Buttons', 'Radio button group.', 80),
    ('CHECKBOX', 'Checkbox', 'Checkbox input.', 90),
    ('FILE', 'File Upload', 'File upload field.', 100),
    ('HIDDEN', 'Hidden', 'Hidden field.', 110)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Form Submission Status
CREATE TABLE IF NOT EXISTS cms.form_submission_status_lookup (
    form_submission_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.form_submission_status_lookup (code, name, description, sort_order) VALUES
    ('NEW', 'New', 'Newly submitted.', 10),
    ('IN_PROGRESS', 'In Progress', 'Being processed.', 20),
    ('COMPLETED', 'Completed', 'Processing complete.', 30),
    ('SPAM', 'Spam', 'Identified as spam.', 40),
    ('ARCHIVED', 'Archived', 'Archived.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Redirect Status
CREATE TABLE IF NOT EXISTS cms.redirect_status_lookup (
    redirect_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.redirect_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Redirect is active.', 10),
    ('INACTIVE', 'Inactive', 'Redirect is disabled.', 20),
    ('EXPIRED', 'Expired', 'Redirect has expired.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Content Block Status
CREATE TABLE IF NOT EXISTS cms.content_block_status_lookup (
    content_block_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cms.content_block_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Block is being edited.', 10),
    ('ACTIVE', 'Active', 'Block is active and usable.', 20),
    ('ARCHIVED', 'Archived', 'Block is archived.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 21.1 SITES & DOMAINS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.sites (
    site_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_status_id UUID NOT NULL DEFAULT (SELECT site_status_id FROM cms.site_status_lookup WHERE code = 'ACTIVE'),

    site_code VARCHAR(50) NOT NULL,
    site_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    primary_domain VARCHAR(300) NOT NULL,
    default_language_code VARCHAR(10) NOT NULL DEFAULT 'en',
    default_currency_id UUID NULL,
    timezone VARCHAR(100) NOT NULL DEFAULT 'Asia/Karachi',

    logo_url VARCHAR(500) NULL,
    favicon_url VARCHAR(500) NULL,
    theme_name VARCHAR(100) NULL,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_site_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_site_status FOREIGN KEY (site_status_id) REFERENCES cms.site_status_lookup(site_status_id),
    CONSTRAINT fk_site_currency FOREIGN KEY (default_currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_site_code UNIQUE (company_id, site_code)
);

CREATE INDEX ix_site_company ON cms.sites(company_id);
CREATE INDEX ix_site_domain ON cms.sites(primary_domain);

-- Site Domains
CREATE TABLE IF NOT EXISTS cms.site_domains (
    site_domain_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL,

    domain VARCHAR(300) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    ssl_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    verified_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sd_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id) ON DELETE CASCADE,
    CONSTRAINT uq_domain UNIQUE (domain)
);

CREATE INDEX ix_sd_site ON cms.site_domains(site_id);

-- ============================================================
-- 21.2 PAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.pages (
    page_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL,
    company_id UUID NOT NULL,
    page_type_id UUID NOT NULL,
    page_status_id UUID NOT NULL DEFAULT (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'DRAFT'),
    parent_page_id UUID NULL,

    page_code VARCHAR(100) NOT NULL,
    page_title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) NOT NULL,
    description TEXT NULL,

    template_name VARCHAR(200) NULL,
    layout_config JSONB NULL,

    featured_image_url VARCHAR(500) NULL,
    featured_image_alt VARCHAR(300) NULL,

    published_version INTEGER NULL,
    current_version INTEGER NOT NULL DEFAULT 1,

    published_at TIMESTAMPTZ NULL,
    published_by_user_id UUID NULL,
    scheduled_publish_at TIMESTAMPTZ NULL,
    scheduled_unpublish_at TIMESTAMPTZ NULL,
    unpublished_at TIMESTAMPTZ NULL,

    is_homepage BOOLEAN NOT NULL DEFAULT FALSE,
    is_searchable BOOLEAN NOT NULL DEFAULT TRUE,
    is_footer_page BOOLEAN NOT NULL DEFAULT FALSE,
    requires_authentication BOOLEAN NOT NULL DEFAULT FALSE,

    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_page_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_page_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_page_type FOREIGN KEY (page_type_id) REFERENCES cms.page_type_lookup(page_type_id),
    CONSTRAINT fk_page_status FOREIGN KEY (page_status_id) REFERENCES cms.page_status_lookup(page_status_id),
    CONSTRAINT fk_page_parent FOREIGN KEY (parent_page_id) REFERENCES cms.pages(page_id),
    CONSTRAINT uq_page_slug UNIQUE (site_id, slug),
    CONSTRAINT uq_page_code UNIQUE (site_id, page_code)
);

CREATE INDEX ix_page_site ON cms.pages(site_id);
CREATE INDEX ix_page_status ON cms.pages(page_status_id);
CREATE INDEX ix_page_type ON cms.pages(page_type_id);
CREATE INDEX ix_page_parent ON cms.pages(parent_page_id);
CREATE INDEX ix_page_slug ON cms.pages(site_id, slug);

-- ============================================================
-- 21.3 PAGE VERSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.page_versions (
    page_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id UUID NOT NULL,

    version_number INTEGER NOT NULL,
    page_title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) NULL,
    content_snapshot JSONB NULL,
    layout_config JSONB NULL,

    change_description TEXT NULL,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_pv_page FOREIGN KEY (page_id) REFERENCES cms.pages(page_id) ON DELETE CASCADE,
    CONSTRAINT uq_page_version UNIQUE (page_id, version_number)
);

CREATE INDEX ix_pv_page ON cms.page_versions(page_id);

-- ============================================================
-- 21.4 PAGE SECTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.page_sections (
    page_section_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id UUID NOT NULL,

    section_code VARCHAR(100) NOT NULL,
    section_name VARCHAR(200) NOT NULL,
    section_type VARCHAR(50) NOT NULL DEFAULT 'CONTENT',

    layout_config JSONB NULL,
    style_config JSONB NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ps_page FOREIGN KEY (page_id) REFERENCES cms.pages(page_id) ON DELETE CASCADE,
    CONSTRAINT uq_section UNIQUE (page_id, section_code),
    CONSTRAINT ck_ps_type CHECK (section_type IN ('HEADER', 'HERO', 'CONTENT', 'SIDEBAR', 'FOOTER', 'BANNER', 'CUSTOM'))
);

CREATE INDEX ix_ps_page ON cms.page_sections(page_id);

-- ============================================================
-- 21.5 CONTENT BLOCKS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.content_blocks (
    content_block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    block_type_id UUID NOT NULL,
    content_block_status_id UUID NOT NULL DEFAULT (SELECT content_block_status_id FROM cms.content_block_status_lookup WHERE code = 'DRAFT'),

    block_code VARCHAR(100) NOT NULL,
    block_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    html_content TEXT NULL,
    text_content TEXT NULL,
    json_content JSONB NULL,

    image_url VARCHAR(500) NULL,
    image_alt VARCHAR(300) NULL,
    video_url VARCHAR(500) NULL,
    link_url VARCHAR(500) NULL,
    cta_text VARCHAR(200) NULL,

    style_config JSONB NULL,
    settings_config JSONB NULL,

    is_reusable BOOLEAN NOT NULL DEFAULT TRUE,
    is_system_block BOOLEAN NOT NULL DEFAULT FALSE,

    current_version INTEGER NOT NULL DEFAULT 1,
    published_version INTEGER NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cb_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cb_type FOREIGN KEY (block_type_id) REFERENCES cms.block_type_lookup(block_type_id),
    CONSTRAINT fk_cb_status FOREIGN KEY (content_block_status_id) REFERENCES cms.content_block_status_lookup(content_block_status_id),
    CONSTRAINT uq_block_code UNIQUE (company_id, block_code)
);

CREATE INDEX ix_cb_company ON cms.content_blocks(company_id);
CREATE INDEX ix_cb_type ON cms.content_blocks(block_type_id);
CREATE INDEX ix_cb_status ON cms.content_blocks(content_block_status_id);

-- Content Block Versions
CREATE TABLE IF NOT EXISTS cms.content_block_versions (
    content_block_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_block_id UUID NOT NULL,

    version_number INTEGER NOT NULL,
    html_content TEXT NULL,
    text_content TEXT NULL,
    json_content JSONB NULL,

    change_description TEXT NULL,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_cbv_block FOREIGN KEY (content_block_id) REFERENCES cms.content_blocks(content_block_id) ON DELETE CASCADE,
    CONSTRAINT uq_block_version UNIQUE (content_block_id, version_number)
);

CREATE INDEX ix_cbv_block ON cms.content_block_versions(content_block_id);

-- Page Blocks (linking blocks to pages/sections)
CREATE TABLE IF NOT EXISTS cms.page_blocks (
    page_block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_section_id UUID NOT NULL,
    content_block_id UUID NOT NULL,

    block_override_config JSONB NULL,
    custom_content TEXT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pb_section FOREIGN KEY (page_section_id) REFERENCES cms.page_sections(page_section_id) ON DELETE CASCADE,
    CONSTRAINT fk_pb_block FOREIGN KEY (content_block_id) REFERENCES cms.content_blocks(content_block_id),
    CONSTRAINT uq_page_block UNIQUE (page_section_id, content_block_id, sort_order)
);

CREATE INDEX ix_pb_section ON cms.page_blocks(page_section_id);
CREATE INDEX ix_pb_block ON cms.page_blocks(content_block_id);

-- ============================================================
-- 21.6 CONTENT TRANSLATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.content_translations (
    content_translation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(30) NOT NULL,
    entity_id UUID NOT NULL,

    language_code VARCHAR(10) NOT NULL,
    translated_title VARCHAR(500) NULL,
    translated_slug VARCHAR(500) NULL,
    translated_content TEXT NULL,
    translated_meta JSONB NULL,

    is_published BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_translation UNIQUE (entity_type, entity_id, language_code),
    CONSTRAINT ck_ct_entity CHECK (entity_type IN ('PAGE', 'BLOCK', 'MENU_ITEM'))
);

CREATE INDEX ix_ct_entity ON cms.content_translations(entity_type, entity_id);
CREATE INDEX ix_ct_language ON cms.content_translations(language_code);

-- ============================================================
-- 21.7 NAVIGATION / MENUS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.menus (
    menu_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL,

    menu_code VARCHAR(100) NOT NULL,
    menu_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    menu_location VARCHAR(50) NOT NULL DEFAULT 'HEADER',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_menu_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id) ON DELETE CASCADE,
    CONSTRAINT uq_menu_code UNIQUE (site_id, menu_code),
    CONSTRAINT ck_menu_location CHECK (menu_location IN ('HEADER', 'FOOTER', 'SIDEBAR', 'MOBILE', 'BREADCRUMB', 'CUSTOM'))
);

CREATE INDEX ix_menu_site ON cms.menus(site_id);

-- Menu Items
CREATE TABLE IF NOT EXISTS cms.menu_items (
    menu_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_id UUID NOT NULL,
    parent_menu_item_id UUID NULL,
    menu_link_type_id UUID NOT NULL,

    label VARCHAR(300) NOT NULL,
    url VARCHAR(1000) NULL,
    page_id UUID NULL,
    product_id UUID NULL,
    category_id UUID NULL,

    icon_url VARCHAR(500) NULL,
    css_class VARCHAR(200) NULL,
    target VARCHAR(20) NULL,

    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    is_mega_menu BOOLEAN NOT NULL DEFAULT FALSE,

    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_mi_menu FOREIGN KEY (menu_id) REFERENCES cms.menus(menu_id) ON DELETE CASCADE,
    CONSTRAINT fk_mi_parent FOREIGN KEY (parent_menu_item_id) REFERENCES cms.menu_items(menu_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_mi_link_type FOREIGN KEY (menu_link_type_id) REFERENCES cms.menu_link_type_lookup(menu_link_type_id),
    CONSTRAINT fk_mi_page FOREIGN KEY (page_id) REFERENCES cms.pages(page_id) ON DELETE SET NULL,
    CONSTRAINT fk_mi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE SET NULL,
    CONSTRAINT ck_mi_target CHECK (target IS NULL OR target IN ('_SELF', '_BLANK', '_PARENT'))
);

CREATE INDEX ix_mi_menu ON cms.menu_items(menu_id);
CREATE INDEX ix_mi_parent ON cms.menu_items(parent_menu_item_id);

-- ============================================================
-- 21.8 LANDING PAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.landing_pages (
    landing_page_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id UUID NOT NULL,
    site_id UUID NOT NULL,
    marketing_campaign_id UUID NULL,

    campaign_code VARCHAR(100) NULL,
    goal_type VARCHAR(50) NULL,
    goal_url VARCHAR(500) NULL,

    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    ab_test_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ab_test_config JSONB NULL,

    total_visits INTEGER NOT NULL DEFAULT 0,
    total_conversions INTEGER NOT NULL DEFAULT 0,
    conversion_rate NUMERIC(7,4) NULL,

    start_date DATE NULL,
    end_date DATE NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_lp_page FOREIGN KEY (page_id) REFERENCES cms.pages(page_id) ON DELETE CASCADE,
    CONSTRAINT fk_lp_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_lp_campaign FOREIGN KEY (marketing_campaign_id) REFERENCES marketing.campaigns(campaign_id),
    CONSTRAINT ck_lp_goal CHECK (goal_type IS NULL OR goal_type IN ('PURCHASE', 'SIGNUP', 'DOWNLOAD', 'LEAD', 'CONTACT', 'OTHER'))
);

CREATE INDEX ix_lp_page ON cms.landing_pages(page_id);
CREATE INDEX ix_lp_site ON cms.landing_pages(site_id);
CREATE INDEX ix_lp_campaign ON cms.landing_pages(marketing_campaign_id);

-- ============================================================
-- 21.9 FORMS / FIELDS / SUBMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.cms_forms (
    cms_form_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL,

    form_code VARCHAR(100) NOT NULL,
    form_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    submit_action VARCHAR(500) NULL,
    success_message TEXT NULL,
    failure_message TEXT NULL,
    redirect_url VARCHAR(500) NULL,

    send_email_notification BOOLEAN NOT NULL DEFAULT FALSE,
    notification_email VARCHAR(300) NULL,
    create_crm_lead BOOLEAN NOT NULL DEFAULT FALSE,

    captcha_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    honeypot_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    total_submissions INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cf_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT uq_form_code UNIQUE (site_id, form_code)
);

CREATE INDEX ix_cf_site ON cms.cms_forms(site_id);

-- Form Fields
CREATE TABLE IF NOT EXISTS cms.cms_form_fields (
    cms_form_field_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cms_form_id UUID NOT NULL,
    form_field_type_id UUID NOT NULL,

    field_name VARCHAR(100) NOT NULL,
    field_label VARCHAR(300) NOT NULL,
    placeholder VARCHAR(300) NULL,
    help_text VARCHAR(500) NULL,

    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    validation_rules JSONB NULL,
    options JSONB NULL,
    default_value TEXT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cff_form FOREIGN KEY (cms_form_id) REFERENCES cms.cms_forms(cms_form_id) ON DELETE CASCADE,
    CONSTRAINT fk_cff_type FOREIGN KEY (form_field_type_id) REFERENCES cms.form_field_type_lookup(form_field_type_id),
    CONSTRAINT uq_form_field UNIQUE (cms_form_id, field_name)
);

CREATE INDEX ix_cff_form ON cms.cms_form_fields(cms_form_id);

-- Form Submissions
CREATE TABLE IF NOT EXISTS cms.cms_form_submissions (
    cms_form_submission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cms_form_id UUID NOT NULL,
    form_submission_status_id UUID NOT NULL DEFAULT (SELECT form_submission_status_id FROM cms.form_submission_status_lookup WHERE code = 'NEW'),

    person_id UUID NULL,
    customer_id UUID NULL,
    lead_id UUID NULL,

    email VARCHAR(300) NULL,
    phone VARCHAR(50) NULL,
    form_data JSONB NOT NULL,

    ip_address INET NULL,
    user_agent TEXT NULL,
    referrer_url VARCHAR(1000) NULL,

    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    is_spam BOOLEAN NOT NULL DEFAULT FALSE,
    spam_score NUMERIC(5,2) NULL,

    processed_at TIMESTAMPTZ NULL,
    notes TEXT NULL,

    submitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cfs_form FOREIGN KEY (cms_form_id) REFERENCES cms.cms_forms(cms_form_id),
    CONSTRAINT fk_cfs_status FOREIGN KEY (form_submission_status_id) REFERENCES cms.form_submission_status_lookup(form_submission_status_id),
    CONSTRAINT fk_cfs_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id)
);

CREATE INDEX ix_cfs_form ON cms.cms_form_submissions(cms_form_id);
CREATE INDEX ix_cfs_status ON cms.cms_form_submissions(form_submission_status_id);
CREATE INDEX ix_cfs_submitted ON cms.cms_form_submissions(submitted_at DESC);

-- ============================================================
-- 21.10 REDIRECTS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.redirects (
    redirect_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL,
    redirect_status_id UUID NOT NULL DEFAULT (SELECT redirect_status_id FROM cms.redirect_status_lookup WHERE code = 'ACTIVE'),

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

    CONSTRAINT fk_red_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_red_status FOREIGN KEY (redirect_status_id) REFERENCES cms.redirect_status_lookup(redirect_status_id),
    CONSTRAINT uq_redirect UNIQUE (site_id, source_path),
    CONSTRAINT ck_red_type CHECK (redirect_type IN (301, 302, 307, 308))
);

CREATE INDEX ix_red_site ON cms.redirects(site_id);
CREATE INDEX ix_red_source ON cms.redirects(site_id, source_path);

-- ============================================================
-- 21.11 PAGE SEO METADATA
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.page_seo (
    page_seo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id UUID NOT NULL,

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
    sitemap_change_frequency VARCHAR(20) NULL,
    exclude_from_sitemap BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pseo_page FOREIGN KEY (page_id) REFERENCES cms.pages(page_id) ON DELETE CASCADE,
    CONSTRAINT uq_page_seo UNIQUE (page_id),
    CONSTRAINT ck_pseo_robots CHECK (robots_directive IS NULL OR robots_directive IN ('index,follow', 'noindex,follow', 'index,nofollow', 'noindex,nofollow')),
    CONSTRAINT ck_pseo_priority CHECK (sitemap_priority IS NULL OR (sitemap_priority >= 0 AND sitemap_priority <= 1)),
    CONSTRAINT ck_pseo_frequency CHECK (sitemap_change_frequency IS NULL OR sitemap_change_frequency IN ('always', 'hourly', 'daily', 'weekly', 'monthly', 'yearly', 'never'))
);

-- ============================================================
-- 21.12 PUBLISHING HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS cms.publishing_history (
    publishing_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id UUID NOT NULL,

    action VARCHAR(30) NOT NULL,
    from_status VARCHAR(30) NULL,
    to_status VARCHAR(30) NOT NULL,
    version_number INTEGER NULL,

    performed_by_user_id UUID NULL,
    notes TEXT NULL,

    performed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ph_page FOREIGN KEY (page_id) REFERENCES cms.pages(page_id) ON DELETE CASCADE,
    CONSTRAINT ck_ph_action CHECK (action IN ('CREATE', 'SUBMIT_REVIEW', 'APPROVE', 'REJECT', 'PUBLISH', 'UNPUBLISH', 'SCHEDULE', 'ARCHIVE', 'RESTORE', 'REVISION'))
);

CREATE INDEX ix_ph_page ON cms.publishing_history(page_id);
CREATE INDEX ix_ph_performed ON cms.publishing_history(performed_at DESC);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_site_id UUID;
    v_currency_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;

    -- Create default site
    INSERT INTO cms.sites (company_id, site_code, site_name, description, primary_domain, default_currency_id, is_default)
    SELECT v_company_id, 'MAIN-SITE', 'eStore Main Website', 'Primary e-commerce website.',
           'www.estore.pk', v_currency_id, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM cms.sites WHERE company_id = v_company_id AND site_code = 'MAIN-SITE')
    RETURNING site_id INTO v_site_id;

    IF v_site_id IS NULL THEN
        SELECT site_id INTO v_site_id FROM cms.sites WHERE company_id = v_company_id AND site_code = 'MAIN-SITE';
    END IF;

    -- Create site domain
    INSERT INTO cms.site_domains (site_id, domain, is_primary)
    SELECT v_site_id, 'www.estore.pk', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM cms.site_domains WHERE domain = 'www.estore.pk');

    INSERT INTO cms.site_domains (site_id, domain, is_primary)
    SELECT v_site_id, 'estore.pk', FALSE
    WHERE NOT EXISTS (SELECT 1 FROM cms.site_domains WHERE domain = 'estore.pk');

    -- Create default pages
    INSERT INTO cms.pages (site_id, company_id, page_type_id, page_code, page_title, slug, is_homepage, page_status_id)
    SELECT v_site_id, v_company_id,
           (SELECT page_type_id FROM cms.page_type_lookup WHERE code = 'HOME'),
           'HOME', 'Home', '/', TRUE,
           (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'PUBLISHED')
    WHERE NOT EXISTS (SELECT 1 FROM cms.pages WHERE site_id = v_site_id AND page_code = 'HOME');

    INSERT INTO cms.pages (site_id, company_id, page_type_id, page_code, page_title, slug, page_status_id)
    SELECT v_site_id, v_company_id,
           (SELECT page_type_id FROM cms.page_type_lookup WHERE code = 'ABOUT'),
           'ABOUT-US', 'About Us', '/about-us',
           (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'PUBLISHED')
    WHERE NOT EXISTS (SELECT 1 FROM cms.pages WHERE site_id = v_site_id AND page_code = 'ABOUT-US');

    INSERT INTO cms.pages (site_id, company_id, page_type_id, page_code, page_title, slug, page_status_id)
    SELECT v_site_id, v_company_id,
           (SELECT page_type_id FROM cms.page_type_lookup WHERE code = 'CONTACT'),
           'CONTACT-US', 'Contact Us', '/contact-us',
           (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'PUBLISHED')
    WHERE NOT EXISTS (SELECT 1 FROM cms.pages WHERE site_id = v_site_id AND page_code = 'CONTACT-US');

    INSERT INTO cms.pages (site_id, company_id, page_type_id, page_code, page_title, slug, page_status_id)
    SELECT v_site_id, v_company_id,
           (SELECT page_type_id FROM cms.page_type_lookup WHERE code = 'LEGAL'),
           'PRIVACY-POLICY', 'Privacy Policy', '/privacy-policy',
           (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'PUBLISHED')
    WHERE NOT EXISTS (SELECT 1 FROM cms.pages WHERE site_id = v_site_id AND page_code = 'PRIVACY-POLICY');

    INSERT INTO cms.pages (site_id, company_id, page_type_id, page_code, page_title, slug, page_status_id)
    SELECT v_site_id, v_company_id,
           (SELECT page_type_id FROM cms.page_type_lookup WHERE code = 'LEGAL'),
           'TERMS-CONDITIONS', 'Terms & Conditions', '/terms-conditions',
           (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'PUBLISHED')
    WHERE NOT EXISTS (SELECT 1 FROM cms.pages WHERE site_id = v_site_id AND page_code = 'TERMS-CONDITIONS');

    INSERT INTO cms.pages (site_id, company_id, page_type_id, page_code, page_title, slug, page_status_id)
    SELECT v_site_id, v_company_id,
           (SELECT page_type_id FROM cms.page_type_lookup WHERE code = 'FAQ'),
           'FAQ', 'FAQ', '/faq',
           (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'PUBLISHED')
    WHERE NOT EXISTS (SELECT 1 FROM cms.pages WHERE site_id = v_site_id AND page_code = 'FAQ');

    INSERT INTO cms.pages (site_id, company_id, page_type_id, page_code, page_title, slug, page_status_id)
    SELECT v_site_id, v_company_id,
           (SELECT page_type_id FROM cms.page_type_lookup WHERE code = 'ERROR_404'),
           'ERROR-404', 'Page Not Found', '/404',
           (SELECT page_status_id FROM cms.page_status_lookup WHERE code = 'PUBLISHED')
    WHERE NOT EXISTS (SELECT 1 FROM cms.pages WHERE site_id = v_site_id AND page_code = 'ERROR-404');

    -- Create default menus
    INSERT INTO cms.menus (site_id, menu_code, menu_name, menu_location)
    SELECT v_site_id, 'MAIN-NAV', 'Main Navigation', 'HEADER'
    WHERE NOT EXISTS (SELECT 1 FROM cms.menus WHERE site_id = v_site_id AND menu_code = 'MAIN-NAV');

    INSERT INTO cms.menus (site_id, menu_code, menu_name, menu_location)
    SELECT v_site_id, 'FOOTER-NAV', 'Footer Navigation', 'FOOTER'
    WHERE NOT EXISTS (SELECT 1 FROM cms.menus WHERE site_id = v_site_id AND menu_code = 'FOOTER-NAV');

    INSERT INTO cms.menus (site_id, menu_code, menu_name, menu_location)
    SELECT v_site_id, 'MOBILE-NAV', 'Mobile Navigation', 'MOBILE'
    WHERE NOT EXISTS (SELECT 1 FROM cms.menus WHERE site_id = v_site_id AND menu_code = 'MOBILE-NAV');

    -- Create default menu items
    INSERT INTO cms.menu_items (menu_id, menu_link_type_id, label, url, sort_order)
    SELECT m.menu_id,
           (SELECT menu_link_type_id FROM cms.menu_link_type_lookup WHERE code = 'PAGE'),
           'Home', '/', 10
    FROM cms.menus m
    WHERE m.site_id = v_site_id AND m.menu_code = 'MAIN-NAV'
      AND NOT EXISTS (SELECT 1 FROM cms.menu_items mi WHERE mi.menu_id = m.menu_id AND mi.label = 'Home');

    INSERT INTO cms.menu_items (menu_id, menu_link_type_id, label, url, sort_order)
    SELECT m.menu_id,
           (SELECT menu_link_type_id FROM cms.menu_link_type_lookup WHERE code = 'CATEGORY'),
           'Shop', '/shop', 20
    FROM cms.menus m
    WHERE m.site_id = v_site_id AND m.menu_code = 'MAIN-NAV'
      AND NOT EXISTS (SELECT 1 FROM cms.menu_items mi WHERE mi.menu_id = m.menu_id AND mi.label = 'Shop');

    INSERT INTO cms.menu_items (menu_id, menu_link_type_id, label, url, sort_order)
    SELECT m.menu_id,
           (SELECT menu_link_type_id FROM cms.menu_link_type_lookup WHERE code = 'PAGE'),
           'About Us', '/about-us', 30
    FROM cms.menus m
    WHERE m.site_id = v_site_id AND m.menu_code = 'MAIN-NAV'
      AND NOT EXISTS (SELECT 1 FROM cms.menu_items mi WHERE mi.menu_id = m.menu_id AND mi.label = 'About Us');

    INSERT INTO cms.menu_items (menu_id, menu_link_type_id, label, url, sort_order)
    SELECT m.menu_id,
           (SELECT menu_link_type_id FROM cms.menu_link_type_lookup WHERE code = 'PAGE'),
           'Contact', '/contact-us', 40
    FROM cms.menus m
    WHERE m.site_id = v_site_id AND m.menu_code = 'MAIN-NAV'
      AND NOT EXISTS (SELECT 1 FROM cms.menu_items mi WHERE mi.menu_id = m.menu_id AND mi.label = 'Contact');

    -- Create default content blocks
    INSERT INTO cms.content_blocks (company_id, block_type_id, block_code, block_name, description, is_reusable)
    SELECT v_company_id,
           (SELECT block_type_id FROM cms.block_type_lookup WHERE code = 'HERO'),
           'DEFAULT-HERO', 'Default Hero Banner', 'Default homepage hero banner.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM cms.content_blocks WHERE company_id = v_company_id AND block_code = 'DEFAULT-HERO');

    INSERT INTO cms.content_blocks (company_id, block_type_id, block_code, block_name, description, is_reusable)
    SELECT v_company_id,
           (SELECT block_type_id FROM cms.block_type_lookup WHERE code = 'NEWSLETTER_SIGNUP'),
           'NEWSLETTER-SIGNUP', 'Newsletter Signup Block', 'Newsletter subscription form block.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM cms.content_blocks WHERE company_id = v_company_id AND block_code = 'NEWSLETTER-SIGNUP');

    INSERT INTO cms.content_blocks (company_id, block_type_id, block_code, block_name, description, is_reusable)
    SELECT v_company_id,
           (SELECT block_type_id FROM cms.block_type_lookup WHERE code = 'FOOTER'),
           'DEFAULT-FOOTER', 'Default Footer', 'Standard website footer.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM cms.content_blocks WHERE company_id = v_company_id AND block_code = 'DEFAULT-FOOTER');

    -- Create default forms
    INSERT INTO cms.cms_forms (site_id, form_code, form_name, description, create_crm_lead, send_email_notification, notification_email)
    SELECT v_site_id, 'CONTACT-FORM', 'Contact Us Form', 'General contact inquiry form.', TRUE, TRUE, 'support@estore.pk'
    WHERE NOT EXISTS (SELECT 1 FROM cms.cms_forms WHERE site_id = v_site_id AND form_code = 'CONTACT-FORM');

    INSERT INTO cms.cms_forms (site_id, form_code, form_name, description, create_crm_lead)
    SELECT v_site_id, 'WHOLESALE-INQUIRY', 'Wholesale Inquiry Form', 'Wholesale/B2B inquiry form.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM cms.cms_forms WHERE site_id = v_site_id AND form_code = 'WHOLESALE-INQUIRY');

    -- Create default redirects
    INSERT INTO cms.redirects (site_id, source_path, target_path, redirect_type)
    SELECT v_site_id, '/old-home', '/', 301
    WHERE NOT EXISTS (SELECT 1 FROM cms.redirects WHERE site_id = v_site_id AND source_path = '/old-home');

    INSERT INTO cms.redirects (site_id, source_path, target_path, redirect_type)
    SELECT v_site_id, '/index.html', '/', 301
    WHERE NOT EXISTS (SELECT 1 FROM cms.redirects WHERE site_id = v_site_id AND source_path = '/index.html');

END $$;

COMMIT;