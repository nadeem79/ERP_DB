BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 20 — NEWSLETTER & EMAIL MARKETING
-- DATABASE TABLES
-- ============================================================
-- Architecture Principle:
--   Newsletter = Content / Publishing module
--   Delivery   = Module 19 (Notification Engine)
--   Attribution = Module 16 (Marketing) → Orders → Accounting
--   No duplicate order/revenue/payment system here.
-- ============================================================
-- Components:
--   20.1  Newsletter Lists & Subscribers
--   20.2  Subscription Preferences & Sources
--   20.3  Newsletter Templates & Versions
--   20.4  Content Blocks (Reusable)
--   20.5  Newsletter Campaigns
--   20.6  Newsletter Issues (Individual Sends)
--   20.7  Issue Content & Products
--   20.8  Issue Recipients & Events
--   20.9  Issue Statistics
--   20.10 Segments & Segment Rules
--   20.11 A/B Testing
--   20.12 Scheduling & Automation
--   20.13 Newsletter Archive
-- ============================================================

CREATE SCHEMA IF NOT EXISTS newsletter;

-- ============================================================
-- 20.0 NEWSLETTER LOOKUPS
-- ============================================================

-- Newsletter Status
CREATE TABLE IF NOT EXISTS newsletter.newsletter_status_lookup (
    newsletter_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.newsletter_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Newsletter is being created.', 10),
    ('REVIEW', 'In Review', 'Newsletter is under review.', 20),
    ('APPROVED', 'Approved', 'Newsletter approved for sending.', 30),
    ('SCHEDULED', 'Scheduled', 'Newsletter scheduled for future send.', 40),
    ('SENDING', 'Sending', 'Newsletter is currently being sent.', 50),
    ('SENT', 'Sent', 'Newsletter has been sent.', 60),
    ('ARCHIVED', 'Archived', 'Newsletter archived.', 70),
    ('CANCELLED', 'Cancelled', 'Newsletter was cancelled.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Newsletter Type
CREATE TABLE IF NOT EXISTS newsletter.newsletter_type_lookup (
    newsletter_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.newsletter_type_lookup (code, name, description, sort_order) VALUES
    ('REGULAR', 'Regular Newsletter', 'Standard periodic newsletter.', 10),
    ('PROMOTIONAL', 'Promotional', 'Sales and promotional content.', 20),
    ('PRODUCT_UPDATE', 'Product Update', 'New product announcements.', 30),
    ('ANNOUNCEMENT', 'Announcement', 'Company announcements.', 40),
    ('DIGEST', 'Digest', 'Content digest/summary.', 50),
    ('AUTOMATED', 'Automated', 'Trigger-based automated newsletter.', 60),
    ('WELCOME', 'Welcome', 'Welcome newsletter for new subscribers.', 70),
    ('RE_ENGAGEMENT', 'Re-engagement', 'Win-back inactive subscribers.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Subscriber Status
CREATE TABLE IF NOT EXISTS newsletter.subscriber_status_lookup (
    subscriber_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.subscriber_status_lookup (code, name, description, sort_order) VALUES
    ('SUBSCRIBED', 'Subscribed', 'Active subscriber.', 10),
    ('PENDING', 'Pending Confirmation', 'Awaiting double opt-in confirmation.', 20),
    ('UNSUBSCRIBED', 'Unsubscribed', 'Subscriber opted out.', 30),
    ('BOUNCED', 'Bounced', 'Email address hard bounced.', 40),
    ('COMPLAINED', 'Complained', 'Subscriber marked as spam.', 50),
    ('INACTIVE', 'Inactive', 'No engagement for extended period.', 60),
    ('SUPPRESSED', 'Suppressed', 'Manually suppressed by admin.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Subscription Source
CREATE TABLE IF NOT EXISTS newsletter.subscription_source_lookup (
    subscription_source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.subscription_source_lookup (code, name, description, sort_order) VALUES
    ('WEBSITE', 'Website Signup', 'Subscribed via website form.', 10),
    ('CHECKOUT', 'Checkout Opt-in', 'Subscribed during checkout.', 20),
    ('IMPORT', 'CSV Import', 'Imported from file.', 30),
    ('MANUAL', 'Manual Entry', 'Added manually by admin.', 40),
    ('API', 'API', 'Added via API integration.', 50),
    ('SOCIAL_MEDIA', 'Social Media', 'Subscribed via social media.', 60),
    ('POS', 'POS Signup', 'Subscribed at point of sale.', 70),
    ('MIGRATION', 'Migration', 'Migrated from legacy system.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Content Block Type
CREATE TABLE IF NOT EXISTS newsletter.content_block_type_lookup (
    content_block_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.content_block_type_lookup (code, name, description, sort_order) VALUES
    ('HEADER', 'Header', 'Newsletter header with logo.', 10),
    ('HERO_IMAGE', 'Hero Image', 'Large hero/banner image.', 20),
    ('TEXT', 'Text Block', 'Rich text content.', 30),
    ('IMAGE', 'Image', 'Single image block.', 40),
    ('IMAGE_TEXT', 'Image + Text', 'Image with text side by side.', 50),
    ('PRODUCT_GRID', 'Product Grid', 'Grid of featured products.', 60),
    ('PRODUCT_CAROUSEL', 'Product Carousel', 'Scrollable product showcase.', 70),
    ('BUTTON', 'Call-to-Action Button', 'CTA button.', 80),
    ('DIVIDER', 'Divider', 'Visual separator.', 90),
    ('SOCIAL_LINKS', 'Social Links', 'Social media links.', 100),
    ('FOOTER', 'Footer', 'Newsletter footer.', 110),
    ('BANNER', 'Promotional Banner', 'Promotional banner.', 120),
    ('COUPON', 'Coupon Code', 'Coupon code display.', 130),
    ('TESTIMONIAL', 'Testimonial', 'Customer testimonial.', 140),
    ('VIDEO', 'Video', 'Embedded video thumbnail.', 150)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- A/B Test Status
CREATE TABLE IF NOT EXISTS newsletter.ab_test_status_lookup (
    ab_test_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.ab_test_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Test is being configured.', 10),
    ('RUNNING', 'Running', 'Test is in progress.', 20),
    ('COMPLETED', 'Completed', 'Test completed with winner.', 30),
    ('CANCELLED', 'Cancelled', 'Test was cancelled.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- A/B Test Winner Criteria
CREATE TABLE IF NOT EXISTS newsletter.ab_test_criteria_lookup (
    ab_test_criteria_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.ab_test_criteria_lookup (code, name, description, sort_order) VALUES
    ('OPEN_RATE', 'Open Rate', 'Winner determined by open rate.', 10),
    ('CLICK_RATE', 'Click Rate', 'Winner determined by click rate.', 20),
    ('CONVERSION_RATE', 'Conversion Rate', 'Winner determined by conversions.', 30),
    ('REVENUE', 'Revenue', 'Winner determined by revenue generated.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Subscriber Event Type
CREATE TABLE IF NOT EXISTS newsletter.subscriber_event_type_lookup (
    subscriber_event_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO newsletter.subscriber_event_type_lookup (code, name, description, sort_order) VALUES
    ('SUBSCRIBED', 'Subscribed', 'Subscriber joined a list.', 10),
    ('CONFIRMED', 'Confirmed', 'Double opt-in confirmed.', 20),
    ('UNSUBSCRIBED', 'Unsubscribed', 'Subscriber opted out.', 30),
    ('BOUNCED', 'Bounced', 'Email bounced.', 40),
    ('COMPLAINED', 'Complained', 'Marked as spam.', 50),
    ('OPENED', 'Opened', 'Newsletter opened.', 60),
    ('CLICKED', 'Clicked', 'Link clicked in newsletter.', 70),
    ('FORWARDED', 'Forwarded', 'Newsletter forwarded.', 80),
    ('RE_ENGAGED', 'Re-engaged', 'Inactive subscriber re-engaged.', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 20.1 NEWSLETTER LISTS
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.newsletter_lists (
    newsletter_list_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    list_code VARCHAR(50) NOT NULL,
    list_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    default_from_email VARCHAR(300) NULL,
    default_from_name VARCHAR(200) NULL,
    default_reply_to_email VARCHAR(300) NULL,

    double_opt_in_required BOOLEAN NOT NULL DEFAULT FALSE,
    confirmation_email_template_id UUID NULL,
    welcome_email_template_id UUID NULL,

    subscriber_count INTEGER NOT NULL DEFAULT 0,
    active_subscriber_count INTEGER NOT NULL DEFAULT 0,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_nl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_list_code UNIQUE (company_id, list_code)
);

CREATE INDEX ix_nl_company ON newsletter.newsletter_lists(company_id);
CREATE INDEX ix_nl_active ON newsletter.newsletter_lists(is_active, is_default);

-- ============================================================
-- 20.2 SUBSCRIBERS
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.subscribers (
    subscriber_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    subscriber_status_id UUID NOT NULL DEFAULT (SELECT subscriber_status_id FROM newsletter.subscriber_status_lookup WHERE code = 'PENDING'),
    subscription_source_id UUID NULL,
    customer_id UUID NULL,

    subscriber_code VARCHAR(50) NOT NULL,
    email_address VARCHAR(300) NOT NULL,
    first_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    display_name VARCHAR(200) NULL,
    phone VARCHAR(50) NULL,

    language_code VARCHAR(10) NULL,
    timezone VARCHAR(100) NULL,

    subscribed_at TIMESTAMPTZ NULL,
    confirmed_at TIMESTAMPTZ NULL,
    unsubscribed_at TIMESTAMPTZ NULL,
    bounced_at TIMESTAMPTZ NULL,
    complained_at TIMESTAMPTZ NULL,
    last_engaged_at TIMESTAMPTZ NULL,

    unsubscribe_reason TEXT NULL,
    notes TEXT NULL,

    total_emails_sent INTEGER NOT NULL DEFAULT 0,
    total_emails_opened INTEGER NOT NULL DEFAULT 0,
    total_emails_clicked INTEGER NOT NULL DEFAULT 0,
    engagement_score NUMERIC(7,4) NOT NULL DEFAULT 0,

    ip_address INET NULL,
    user_agent TEXT NULL,
    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sub_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sub_status FOREIGN KEY (subscriber_status_id) REFERENCES newsletter.subscriber_status_lookup(subscriber_status_id),
    CONSTRAINT fk_sub_source FOREIGN KEY (subscription_source_id) REFERENCES newsletter.subscription_source_lookup(subscription_source_id),
    CONSTRAINT fk_sub_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT uq_subscriber_code UNIQUE (company_id, subscriber_code),
    CONSTRAINT uq_subscriber_email UNIQUE (company_id, email_address)
);

CREATE INDEX ix_sub_company ON newsletter.subscribers(company_id);
CREATE INDEX ix_sub_status ON newsletter.subscribers(subscriber_status_id);
CREATE INDEX ix_sub_email ON newsletter.subscribers(email_address);
CREATE INDEX ix_sub_customer ON newsletter.subscribers(customer_id);
CREATE INDEX ix_sub_engagement ON newsletter.subscribers(engagement_score DESC);

-- List Subscribers (Many-to-Many)
CREATE TABLE IF NOT EXISTS newsletter.list_subscribers (
    list_subscriber_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_list_id UUID NOT NULL,
    subscriber_id UUID NOT NULL,

    subscribed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unsubscribed_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ls_list FOREIGN KEY (newsletter_list_id) REFERENCES newsletter.newsletter_lists(newsletter_list_id) ON DELETE CASCADE,
    CONSTRAINT fk_ls_subscriber FOREIGN KEY (subscriber_id) REFERENCES newsletter.subscribers(subscriber_id) ON DELETE CASCADE,
    CONSTRAINT uq_list_subscriber UNIQUE (newsletter_list_id, subscriber_id)
);

CREATE INDEX ix_ls_list ON newsletter.list_subscribers(newsletter_list_id);
CREATE INDEX ix_ls_subscriber ON newsletter.list_subscribers(subscriber_id);
CREATE INDEX ix_ls_active ON newsletter.list_subscribers(is_active);

-- Subscription Preferences
CREATE TABLE IF NOT EXISTS newsletter.subscription_preferences (
    subscription_preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscriber_id UUID NOT NULL,
    newsletter_list_id UUID NULL,

    email_frequency VARCHAR(20) NOT NULL DEFAULT 'WEEKLY',
    preferred_day_of_week INTEGER NULL,
    preferred_send_time TIME NULL,

    wants_product_updates BOOLEAN NOT NULL DEFAULT TRUE,
    wants_promotions BOOLEAN NOT NULL DEFAULT TRUE,
    wants_company_news BOOLEAN NOT NULL DEFAULT TRUE,
    wants_tips_content BOOLEAN NOT NULL DEFAULT TRUE,

    html_format_preferred BOOLEAN NOT NULL DEFAULT TRUE,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sp_subscriber FOREIGN KEY (subscriber_id) REFERENCES newsletter.subscribers(subscriber_id) ON DELETE CASCADE,
    CONSTRAINT fk_sp_list FOREIGN KEY (newsletter_list_id) REFERENCES newsletter.newsletter_lists(newsletter_list_id) ON DELETE CASCADE,
    CONSTRAINT ck_sp_frequency CHECK (email_frequency IN ('DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY')),
    CONSTRAINT ck_sp_dow CHECK (preferred_day_of_week IS NULL OR (preferred_day_of_week >= 1 AND preferred_day_of_week <= 7))
);

CREATE INDEX ix_sp_subscriber ON newsletter.subscription_preferences(subscriber_id);

-- ============================================================
-- 20.3 NEWSLETTER TEMPLATES
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.newsletter_templates (
    newsletter_template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    subject_template VARCHAR(500) NULL,
    preheader_template VARCHAR(300) NULL,
    html_template TEXT NULL,
    text_template TEXT NULL,

    header_image_url VARCHAR(500) NULL,
    footer_html TEXT NULL,
    primary_color VARCHAR(20) NULL,
    secondary_color VARCHAR(20) NULL,
    font_family VARCHAR(100) NULL,

    is_responsive BOOLEAN NOT NULL DEFAULT TRUE,
    current_version INTEGER NOT NULL DEFAULT 1,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_nt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_template_code UNIQUE (company_id, template_code)
);

CREATE INDEX ix_nt_company ON newsletter.newsletter_templates(company_id);
CREATE INDEX ix_nt_active ON newsletter.newsletter_templates(is_active, is_default);

-- Template Versions
CREATE TABLE IF NOT EXISTS newsletter.template_versions (
    template_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_template_id UUID NOT NULL,

    version_number INTEGER NOT NULL,
    subject_template VARCHAR(500) NULL,
    html_template TEXT NULL,
    text_template TEXT NULL,

    change_description TEXT NULL,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_tv_template FOREIGN KEY (newsletter_template_id) REFERENCES newsletter.newsletter_templates(newsletter_template_id) ON DELETE CASCADE,
    CONSTRAINT uq_template_version UNIQUE (newsletter_template_id, version_number)
);

CREATE INDEX ix_tv_template ON newsletter.template_versions(newsletter_template_id);

-- ============================================================
-- 20.4 CONTENT BLOCKS (Reusable)
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.content_blocks (
    content_block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    content_block_type_id UUID NOT NULL,

    block_code VARCHAR(100) NOT NULL,
    block_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    html_content TEXT NULL,
    text_content TEXT NULL,
    image_url VARCHAR(500) NULL,
    link_url VARCHAR(500) NULL,
    cta_text VARCHAR(200) NULL,

    configuration_json JSONB NULL,

    is_reusable BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cb_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cb_type FOREIGN KEY (content_block_type_id) REFERENCES newsletter.content_block_type_lookup(content_block_type_id),
    CONSTRAINT uq_block_code UNIQUE (company_id, block_code)
);

CREATE INDEX ix_cb_company ON newsletter.content_blocks(company_id);
CREATE INDEX ix_cb_type ON newsletter.content_blocks(content_block_type_id);

-- ============================================================
-- 20.5 NEWSLETTER CAMPAIGNS
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.newsletter_campaigns (
    newsletter_campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    marketing_campaign_id UUID NULL,

    campaign_code VARCHAR(50) NOT NULL,
    campaign_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    start_date DATE NULL,
    end_date DATE NULL,

    total_issues_sent INTEGER NOT NULL DEFAULT 0,
    total_subscribers_reached INTEGER NOT NULL DEFAULT 0,
    total_opens INTEGER NOT NULL DEFAULT 0,
    total_clicks INTEGER NOT NULL DEFAULT 0,
    total_conversions INTEGER NOT NULL DEFAULT 0,
    total_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_nc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_nc_marketing FOREIGN KEY (marketing_campaign_id) REFERENCES marketing.campaigns(campaign_id),
    CONSTRAINT uq_campaign_code UNIQUE (company_id, campaign_code)
);

CREATE INDEX ix_nc_company ON newsletter.newsletter_campaigns(company_id);

-- ============================================================
-- 20.6 NEWSLETTER ISSUES
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.newsletter_issues (
    newsletter_issue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    newsletter_list_id UUID NOT NULL,
    newsletter_template_id UUID NULL,
    newsletter_campaign_id UUID NULL,
    newsletter_status_id UUID NOT NULL DEFAULT (SELECT newsletter_status_id FROM newsletter.newsletter_status_lookup WHERE code = 'DRAFT'),
    newsletter_type_id UUID NOT NULL DEFAULT (SELECT newsletter_type_id FROM newsletter.newsletter_type_lookup WHERE code = 'REGULAR'),
    ab_test_id UUID NULL,

    issue_number VARCHAR(50) NOT NULL,
    issue_name VARCHAR(300) NOT NULL,
    subject VARCHAR(500) NOT NULL,
    preheader VARCHAR(300) NULL,

    from_email VARCHAR(300) NOT NULL,
    from_name VARCHAR(200) NOT NULL,
    reply_to_email VARCHAR(300) NULL,

    html_content TEXT NULL,
    text_content TEXT NULL,

    target_segment_id UUID NULL,
    target_filter_json JSONB NULL,

    scheduled_at TIMESTAMPTZ NULL,
    sent_at TIMESTAMPTZ NULL,
    sending_started_at TIMESTAMPTZ NULL,
    sending_completed_at TIMESTAMPTZ NULL,

    total_recipients INTEGER NOT NULL DEFAULT 0,
    total_sent INTEGER NOT NULL DEFAULT 0,
    total_delivered INTEGER NOT NULL DEFAULT 0,
    total_opened INTEGER NOT NULL DEFAULT 0,
    total_clicked INTEGER NOT NULL DEFAULT 0,
    total_bounced INTEGER NOT NULL DEFAULT 0,
    total_unsubscribed INTEGER NOT NULL DEFAULT 0,
    total_complained INTEGER NOT NULL DEFAULT 0,
    total_conversions INTEGER NOT NULL DEFAULT 0,
    total_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    open_rate NUMERIC(7,4) NULL,
    click_rate NUMERIC(7,4) NULL,
    bounce_rate NUMERIC(7,4) NULL,
    unsubscribe_rate NUMERIC(7,4) NULL,
    conversion_rate NUMERIC(7,4) NULL,

    notification_id UUID NULL,

    review_notes TEXT NULL,
    reviewed_by_user_id UUID NULL,
    reviewed_at TIMESTAMPTZ NULL,
    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,

    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ni_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ni_list FOREIGN KEY (newsletter_list_id) REFERENCES newsletter.newsletter_lists(newsletter_list_id),
    CONSTRAINT fk_ni_template FOREIGN KEY (newsletter_template_id) REFERENCES newsletter.newsletter_templates(newsletter_template_id),
    CONSTRAINT fk_ni_campaign FOREIGN KEY (newsletter_campaign_id) REFERENCES newsletter.newsletter_campaigns(newsletter_campaign_id),
    CONSTRAINT fk_ni_status FOREIGN KEY (newsletter_status_id) REFERENCES newsletter.newsletter_status_lookup(newsletter_status_id),
    CONSTRAINT fk_ni_type FOREIGN KEY (newsletter_type_id) REFERENCES newsletter.newsletter_type_lookup(newsletter_type_id),
    CONSTRAINT uq_issue_number UNIQUE (company_id, issue_number)
);

CREATE INDEX ix_ni_company ON newsletter.newsletter_issues(company_id);
CREATE INDEX ix_ni_list ON newsletter.newsletter_issues(newsletter_list_id);
CREATE INDEX ix_ni_status ON newsletter.newsletter_issues(newsletter_status_id);
CREATE INDEX ix_ni_campaign ON newsletter.newsletter_issues(newsletter_campaign_id);
CREATE INDEX ix_ni_scheduled ON newsletter.newsletter_issues(scheduled_at) WHERE newsletter_status_id = (SELECT newsletter_status_id FROM newsletter.newsletter_status_lookup WHERE code = 'SCHEDULED');

-- ============================================================
-- 20.7 ISSUE CONTENT & PRODUCTS
-- ============================================================

-- Issue Content Blocks
CREATE TABLE IF NOT EXISTS newsletter.issue_content_blocks (
    issue_content_block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_issue_id UUID NOT NULL,
    content_block_id UUID NULL,
    content_block_type_id UUID NOT NULL,

    block_title VARCHAR(300) NULL,
    html_content TEXT NULL,
    text_content TEXT NULL,
    image_url VARCHAR(500) NULL,
    image_alt_text VARCHAR(300) NULL,
    link_url VARCHAR(500) NULL,
    cta_text VARCHAR(200) NULL,

    configuration_json JSONB NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_icb_issue FOREIGN KEY (newsletter_issue_id) REFERENCES newsletter.newsletter_issues(newsletter_issue_id) ON DELETE CASCADE,
    CONSTRAINT fk_icb_block FOREIGN KEY (content_block_id) REFERENCES newsletter.content_blocks(content_block_id),
    CONSTRAINT fk_icb_type FOREIGN KEY (content_block_type_id) REFERENCES newsletter.content_block_type_lookup(content_block_type_id)
);

CREATE INDEX ix_icb_issue ON newsletter.issue_content_blocks(newsletter_issue_id);

-- Issue Products (Featured Products)
CREATE TABLE IF NOT EXISTS newsletter.issue_products (
    issue_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_issue_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    display_name VARCHAR(300) NULL,
    custom_price NUMERIC(19,4) NULL,
    discount_percentage NUMERIC(5,2) NULL,
    custom_image_url VARCHAR(500) NULL,
    custom_description TEXT NULL,
    cta_url VARCHAR(500) NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,

    click_count INTEGER NOT NULL DEFAULT 0,
    conversion_count INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ip_issue FOREIGN KEY (newsletter_issue_id) REFERENCES newsletter.newsletter_issues(newsletter_issue_id) ON DELETE CASCADE,
    CONSTRAINT fk_ip_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ip_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id)
);

CREATE INDEX ix_ip_issue ON newsletter.issue_products(newsletter_issue_id);
CREATE INDEX ix_ip_product ON newsletter.issue_products(product_id);

-- Issue Links (for click tracking)
CREATE TABLE IF NOT EXISTS newsletter.issue_links (
    issue_link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_issue_id UUID NOT NULL,

    link_url VARCHAR(1000) NOT NULL,
    link_text VARCHAR(300) NULL,
    link_position VARCHAR(50) NULL,

    tracking_code VARCHAR(100) NOT NULL,
    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,
    utm_content VARCHAR(200) NULL,

    total_clicks INTEGER NOT NULL DEFAULT 0,
    unique_clicks INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_il_issue FOREIGN KEY (newsletter_issue_id) REFERENCES newsletter.newsletter_issues(newsletter_issue_id) ON DELETE CASCADE,
    CONSTRAINT uq_tracking_code UNIQUE (newsletter_issue_id, tracking_code)
);

CREATE INDEX ix_il_issue ON newsletter.issue_links(newsletter_issue_id);

-- ============================================================
-- 20.8 ISSUE RECIPIENTS & EVENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.issue_recipients (
    issue_recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_issue_id UUID NOT NULL,
    subscriber_id UUID NOT NULL,
    notification_delivery_id UUID NULL,

    sent_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,
    first_opened_at TIMESTAMPTZ NULL,
    last_opened_at TIMESTAMPTZ NULL,
    first_clicked_at TIMESTAMPTZ NULL,
    last_clicked_at TIMESTAMPTZ NULL,
    bounced_at TIMESTAMPTZ NULL,
    unsubscribed_at TIMESTAMPTZ NULL,
    complained_at TIMESTAMPTZ NULL,

    open_count INTEGER NOT NULL DEFAULT 0,
    click_count INTEGER NOT NULL DEFAULT 0,

    converted BOOLEAN NOT NULL DEFAULT FALSE,
    converted_at TIMESTAMPTZ NULL,
    order_id UUID NULL,
    conversion_value NUMERIC(19,4) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ir_issue FOREIGN KEY (newsletter_issue_id) REFERENCES newsletter.newsletter_issues(newsletter_issue_id) ON DELETE CASCADE,
    CONSTRAINT fk_ir_subscriber FOREIGN KEY (subscriber_id) REFERENCES newsletter.subscribers(subscriber_id) ON DELETE CASCADE,
    CONSTRAINT fk_ir_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT uq_issue_subscriber UNIQUE (newsletter_issue_id, subscriber_id)
);

CREATE INDEX ix_ir_issue ON newsletter.issue_recipients(newsletter_issue_id);
CREATE INDEX ix_ir_subscriber ON newsletter.issue_recipients(subscriber_id);
CREATE INDEX ix_ir_converted ON newsletter.issue_recipients(converted, converted_at);

-- Subscriber Events (Granular Tracking)
CREATE TABLE IF NOT EXISTS newsletter.subscriber_events (
    subscriber_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscriber_id UUID NOT NULL,
    newsletter_issue_id UUID NULL,
    newsletter_list_id UUID NULL,
    subscriber_event_type_id UUID NOT NULL,

    event_data JSONB NULL,
    link_url VARCHAR(1000) NULL,
    issue_link_id UUID NULL,

    ip_address INET NULL,
    user_agent TEXT NULL,
    device_type VARCHAR(20) NULL,

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_se_subscriber FOREIGN KEY (subscriber_id) REFERENCES newsletter.subscribers(subscriber_id) ON DELETE CASCADE,
    CONSTRAINT fk_se_issue FOREIGN KEY (newsletter_issue_id) REFERENCES newsletter.newsletter_issues(newsletter_issue_id) ON DELETE SET NULL,
    CONSTRAINT fk_se_list FOREIGN KEY (newsletter_list_id) REFERENCES newsletter.newsletter_lists(newsletter_list_id) ON DELETE SET NULL,
    CONSTRAINT fk_se_type FOREIGN KEY (subscriber_event_type_id) REFERENCES newsletter.subscriber_event_type_lookup(subscriber_event_type_id),
    CONSTRAINT fk_se_link FOREIGN KEY (issue_link_id) REFERENCES newsletter.issue_links(issue_link_id)
);

CREATE INDEX ix_se_subscriber ON newsletter.subscriber_events(subscriber_id);
CREATE INDEX ix_se_issue ON newsletter.subscriber_events(newsletter_issue_id);
CREATE INDEX ix_se_type ON newsletter.subscriber_events(subscriber_event_type_id);
CREATE INDEX ix_se_occurred ON newsletter.subscriber_events(occurred_at DESC);

-- ============================================================
-- 20.10 SEGMENTS & SEGMENT RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.newsletter_segments (
    newsletter_segment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    segment_code VARCHAR(50) NOT NULL,
    segment_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_dynamic BOOLEAN NOT NULL DEFAULT TRUE,
    estimated_size INTEGER NOT NULL DEFAULT 0,
    last_calculated_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ns_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_segment_code UNIQUE (company_id, segment_code)
);

CREATE INDEX ix_ns_company ON newsletter.newsletter_segments(company_id);

-- Segment Rules
CREATE TABLE IF NOT EXISTS newsletter.segment_rules (
    segment_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_segment_id UUID NOT NULL,

    field_name VARCHAR(100) NOT NULL,
    operator VARCHAR(30) NOT NULL,
    field_value TEXT NULL,
    logic_operator VARCHAR(10) NOT NULL DEFAULT 'AND',
    rule_group INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sr_segment FOREIGN KEY (newsletter_segment_id) REFERENCES newsletter.newsletter_segments(newsletter_segment_id) ON DELETE CASCADE,
    CONSTRAINT ck_sr_operator CHECK (operator IN ('EQUALS', 'NOT_EQUALS', 'CONTAINS', 'NOT_CONTAINS', 'GREATER_THAN', 'LESS_THAN', 'BETWEEN', 'IN', 'NOT_IN', 'IS_NULL', 'IS_NOT_NULL', 'BEFORE', 'AFTER'))
);

CREATE INDEX ix_sr_segment ON newsletter.segment_rules(newsletter_segment_id);

-- Segment Members (for static segments or cached dynamic)
CREATE TABLE IF NOT EXISTS newsletter.segment_members (
    segment_member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_segment_id UUID NOT NULL,
    subscriber_id UUID NOT NULL,

    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_sm_segment FOREIGN KEY (newsletter_segment_id) REFERENCES newsletter.newsletter_segments(newsletter_segment_id) ON DELETE CASCADE,
    CONSTRAINT fk_sm_subscriber FOREIGN KEY (subscriber_id) REFERENCES newsletter.subscribers(subscriber_id) ON DELETE CASCADE,
    CONSTRAINT uq_segment_subscriber UNIQUE (newsletter_segment_id, subscriber_id)
);

CREATE INDEX ix_sm_segment ON newsletter.segment_members(newsletter_segment_id);
CREATE INDEX ix_sm_subscriber ON newsletter.segment_members(subscriber_id);

-- ============================================================
-- 20.11 A/B TESTING
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.ab_tests (
    ab_test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    newsletter_issue_id UUID NOT NULL,
    ab_test_status_id UUID NOT NULL DEFAULT (SELECT ab_test_status_id FROM newsletter.ab_test_status_lookup WHERE code = 'DRAFT'),
    ab_test_criteria_id UUID NOT NULL,

    test_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    test_type VARCHAR(30) NOT NULL DEFAULT 'SUBJECT',
    sample_size_percent NUMERIC(5,2) NOT NULL DEFAULT 10,
    test_duration_hours INTEGER NOT NULL DEFAULT 24,

    winner_variant_id UUID NULL,
    winner_selected_at TIMESTAMPTZ NULL,

    started_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_abt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_abt_issue FOREIGN KEY (newsletter_issue_id) REFERENCES newsletter.newsletter_issues(newsletter_issue_id) ON DELETE CASCADE,
    CONSTRAINT fk_abt_status FOREIGN KEY (ab_test_status_id) REFERENCES newsletter.ab_test_status_lookup(ab_test_status_id),
    CONSTRAINT fk_abt_criteria FOREIGN KEY (ab_test_criteria_id) REFERENCES newsletter.ab_test_criteria_lookup(ab_test_criteria_id),
    CONSTRAINT ck_abt_type CHECK (test_type IN ('SUBJECT', 'CONTENT', 'SEND_TIME', 'FROM_NAME')),
    CONSTRAINT ck_abt_sample CHECK (sample_size_percent > 0 AND sample_size_percent <= 50)
);

CREATE INDEX ix_abt_issue ON newsletter.ab_tests(newsletter_issue_id);
CREATE INDEX ix_abt_status ON newsletter.ab_tests(ab_test_status_id);

-- A/B Test Variants
CREATE TABLE IF NOT EXISTS newsletter.ab_test_variants (
    ab_test_variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ab_test_id UUID NOT NULL,

    variant_code VARCHAR(10) NOT NULL,
    variant_name VARCHAR(100) NOT NULL,

    subject VARCHAR(500) NULL,
    html_content TEXT NULL,
    from_name VARCHAR(200) NULL,
    send_time_offset_minutes INTEGER NULL,

    total_recipients INTEGER NOT NULL DEFAULT 0,
    total_sent INTEGER NOT NULL DEFAULT 0,
    total_opened INTEGER NOT NULL DEFAULT 0,
    total_clicked INTEGER NOT NULL DEFAULT 0,
    total_converted INTEGER NOT NULL DEFAULT 0,
    total_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    open_rate NUMERIC(7,4) NULL,
    click_rate NUMERIC(7,4) NULL,
    conversion_rate NUMERIC(7,4) NULL,

    is_winner BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_abtv_test FOREIGN KEY (ab_test_id) REFERENCES newsletter.ab_tests(ab_test_id) ON DELETE CASCADE,
    CONSTRAINT uq_variant UNIQUE (ab_test_id, variant_code)
);

CREATE INDEX ix_abtv_test ON newsletter.ab_test_variants(ab_test_id);

-- ============================================================
-- 20.12 AUTOMATION RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.automation_rules (
    automation_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    newsletter_list_id UUID NULL,
    newsletter_template_id UUID NULL,

    rule_name VARCHAR(300) NOT NULL,
    description TEXT NULL,
    trigger_event VARCHAR(50) NOT NULL,
    trigger_conditions JSONB NULL,

    delay_minutes INTEGER NOT NULL DEFAULT 0,
    send_time TIME NULL,
    send_days INTEGER[] NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    execution_count INTEGER NOT NULL DEFAULT 0,
    last_executed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ar_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ar_list FOREIGN KEY (newsletter_list_id) REFERENCES newsletter.newsletter_lists(newsletter_list_id),
    CONSTRAINT fk_ar_template FOREIGN KEY (newsletter_template_id) REFERENCES newsletter.newsletter_templates(newsletter_template_id),
    CONSTRAINT ck_ar_trigger CHECK (trigger_event IN (
        'SUBSCRIBER_JOINED', 'SUBSCRIBER_CONFIRMED', 'SUBSCRIBER_INACTIVE',
        'ORDER_COMPLETED', 'CART_ABANDONED', 'PRODUCT_VIEWED',
        'BIRTHDAY', 'ANNIVERSARY', 'CUSTOM_DATE'
    ))
);

CREATE INDEX ix_ar_company ON newsletter.automation_rules(company_id);
CREATE INDEX ix_ar_active ON newsletter.automation_rules(is_active, trigger_event);

-- ============================================================
-- 20.13 NEWSLETTER ARCHIVE
-- ============================================================

CREATE TABLE IF NOT EXISTS newsletter.newsletter_archive (
    newsletter_archive_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    newsletter_issue_id UUID NOT NULL,

    archived_html TEXT NULL,
    archived_text TEXT NULL,
    web_view_url VARCHAR(500) NULL,

    archived_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    archived_by_user_id UUID NULL,

    CONSTRAINT fk_na_issue FOREIGN KEY (newsletter_issue_id) REFERENCES newsletter.newsletter_issues(newsletter_issue_id) ON DELETE CASCADE,
    CONSTRAINT uq_archive_issue UNIQUE (newsletter_issue_id)
);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_default_list UUID;
    v_default_template UUID;
    v_regular_type UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT newsletter_type_id INTO v_regular_type FROM newsletter.newsletter_type_lookup WHERE code = 'REGULAR';

    -- Create default newsletter list
    INSERT INTO newsletter.newsletter_lists (company_id, list_code, list_name, description, default_from_email, default_from_name, is_default)
    SELECT v_company_id, 'MAIN-LIST', 'Main Newsletter List', 'Primary newsletter list for all subscribers.',
           'newsletter@estore.pk', 'eStore Pakistan', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_lists WHERE company_id = v_company_id AND list_code = 'MAIN-LIST')
    RETURNING newsletter_list_id INTO v_default_list;

    IF v_default_list IS NULL THEN
        SELECT newsletter_list_id INTO v_default_list FROM newsletter.newsletter_lists WHERE company_id = v_company_id AND list_code = 'MAIN-LIST';
    END IF;

    -- Create a promotional list
    INSERT INTO newsletter.newsletter_lists (company_id, list_code, list_name, description, default_from_email, default_from_name)
    SELECT v_company_id, 'PROMO-LIST', 'Promotions & Deals', 'Subscribers who want promotional content and deals.',
           'deals@estore.pk', 'eStore Deals'
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_lists WHERE company_id = v_company_id AND list_code = 'PROMO-LIST');

    -- Create a VIP list
    INSERT INTO newsletter.newsletter_lists (company_id, list_code, list_name, description, default_from_email, default_from_name)
    SELECT v_company_id, 'VIP-LIST', 'VIP Subscribers', 'Exclusive content for VIP subscribers.',
           'vip@estore.pk', 'eStore VIP'
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_lists WHERE company_id = v_company_id AND list_code = 'VIP-LIST');

    -- Create default newsletter template
    INSERT INTO newsletter.newsletter_templates (company_id, template_code, template_name, description, subject_template, is_default)
    SELECT v_company_id, 'STANDARD-NEWSLETTER', 'Standard Newsletter Template', 'Default responsive newsletter template.',
           '{{subject}}', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_templates WHERE company_id = v_company_id AND template_code = 'STANDARD-NEWSLETTER')
    RETURNING newsletter_template_id INTO v_default_template;

    -- Create promotional template
    INSERT INTO newsletter.newsletter_templates (company_id, template_code, template_name, description, subject_template)
    SELECT v_company_id, 'PROMO-TEMPLATE', 'Promotional Template', 'Template optimized for promotions and sales.',
           '🔥 {{subject}}'
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_templates WHERE company_id = v_company_id AND template_code = 'PROMO-TEMPLATE');

    -- Create welcome template
    INSERT INTO newsletter.newsletter_templates (company_id, template_code, template_name, description, subject_template)
    SELECT v_company_id, 'WELCOME-TEMPLATE', 'Welcome Email Template', 'Welcome email for new subscribers.',
           'Welcome to eStore, {{first_name}}! 🎉'
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_templates WHERE company_id = v_company_id AND template_code = 'WELCOME-TEMPLATE');

    -- Create sample segments
    INSERT INTO newsletter.newsletter_segments (company_id, segment_code, segment_name, description, is_dynamic)
    SELECT v_company_id, 'NEW-SUBSCRIBERS', 'New Subscribers (Last 30 Days)', 'Subscribers who joined in the last 30 days.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_segments WHERE company_id = v_company_id AND segment_code = 'NEW-SUBSCRIBERS');

    INSERT INTO newsletter.newsletter_segments (company_id, segment_code, segment_name, description, is_dynamic)
    SELECT v_company_id, 'HIGH-ENGAGEMENT', 'High Engagement Subscribers', 'Subscribers with engagement score above 70.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_segments WHERE company_id = v_company_id AND segment_code = 'HIGH-ENGAGEMENT');

    INSERT INTO newsletter.newsletter_segments (company_id, segment_code, segment_name, description, is_dynamic)
    SELECT v_company_id, 'INACTIVE-90D', 'Inactive Subscribers (90+ Days)', 'Subscribers with no engagement for 90+ days.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_segments WHERE company_id = v_company_id AND segment_code = 'INACTIVE-90D');

    INSERT INTO newsletter.newsletter_segments (company_id, segment_code, segment_name, description, is_dynamic)
    SELECT v_company_id, 'VIP-CUSTOMERS', 'VIP Customers', 'Customers with VIP status.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_segments WHERE company_id = v_company_id AND segment_code = 'VIP-CUSTOMERS');

    -- Create sample content blocks
    INSERT INTO newsletter.content_blocks (company_id, content_block_type_id, block_code, block_name, description, is_reusable)
    SELECT v_company_id,
           (SELECT content_block_type_id FROM newsletter.content_block_type_lookup WHERE code = 'HEADER'),
           'DEFAULT-HEADER', 'Standard Header', 'Standard newsletter header with logo.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.content_blocks WHERE company_id = v_company_id AND block_code = 'DEFAULT-HEADER');

    INSERT INTO newsletter.content_blocks (company_id, content_block_type_id, block_code, block_name, description, is_reusable)
    SELECT v_company_id,
           (SELECT content_block_type_id FROM newsletter.content_block_type_lookup WHERE code = 'FOOTER'),
           'DEFAULT-FOOTER', 'Standard Footer', 'Standard newsletter footer with unsubscribe link.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.content_blocks WHERE company_id = v_company_id AND block_code = 'DEFAULT-FOOTER');

    INSERT INTO newsletter.content_blocks (company_id, content_block_type_id, block_code, block_name, description, is_reusable)
    SELECT v_company_id,
           (SELECT content_block_type_id FROM newsletter.content_block_type_lookup WHERE code = 'SOCIAL_LINKS'),
           'SOCIAL-LINKS', 'Social Media Links', 'Social media follow buttons.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.content_blocks WHERE company_id = v_company_id AND block_code = 'SOCIAL-LINKS');

    -- Create welcome automation
    INSERT INTO newsletter.automation_rules (company_id, newsletter_list_id, newsletter_template_id, rule_name, description, trigger_event, delay_minutes)
    SELECT v_company_id, v_default_list,
           (SELECT newsletter_template_id FROM newsletter.newsletter_templates WHERE company_id = v_company_id AND template_code = 'WELCOME-TEMPLATE'),
           'Welcome Email', 'Send welcome email to new subscribers.', 'SUBSCRIBER_CONFIRMED', 0
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.automation_rules WHERE company_id = v_company_id AND rule_name = 'Welcome Email');

    -- Create re-engagement automation
    INSERT INTO newsletter.automation_rules (company_id, newsletter_list_id, rule_name, description, trigger_event, delay_minutes)
    SELECT v_company_id, v_default_list,
           'Re-engagement Campaign', 'Send re-engagement email to inactive subscribers.', 'SUBSCRIBER_INACTIVE', 0
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.automation_rules WHERE company_id = v_company_id AND rule_name = 'Re-engagement Campaign');

    -- Create a sample newsletter campaign
    INSERT INTO newsletter.newsletter_campaigns (company_id, campaign_code, campaign_name, description, start_date, end_date)
    SELECT v_company_id, 'NL-CAMP-2026-Q1', 'Q1 2026 Newsletter Campaign', 'First quarter newsletter campaign.',
           '2026-01-01', '2026-03-31'
    WHERE NOT EXISTS (SELECT 1 FROM newsletter.newsletter_campaigns WHERE company_id = v_company_id AND campaign_code = 'NL-CAMP-2026-Q1');

END $$;

COMMIT;