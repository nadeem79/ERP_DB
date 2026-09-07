BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 17 — AFFILIATE MARKETING & PARTNER MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Components:
--   17.1  Affiliate Programs
--   17.2  Affiliate Types & Statuses
--   17.3  Affiliates
--   17.4  Affiliate Applications
--   17.5  Affiliate Tiers
--   17.6  Affiliate Links
--   17.7  Affiliate Coupons
--   17.8  Click Tracking
--   17.9  Tracking Sessions
--   17.10 Attribution Rules & Attributions
--   17.11 Commission Rules
--   17.12 Commissions
--   17.13 Commission Adjustments
--   17.14 Fraud Controls
--   17.15 Affiliate Balances
--   17.16 Payout Requests & Items
--   17.17 Performance Summary
-- ============================================================

CREATE SCHEMA IF NOT EXISTS affiliate;

-- ============================================================
-- 17.2 AFFILIATE LOOKUPS
-- ============================================================

-- Affiliate Type
CREATE TABLE IF NOT EXISTS affiliate.affiliate_type_lookup (
    affiliate_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.affiliate_type_lookup (code, name, description, sort_order) VALUES
    ('INDIVIDUAL', 'Individual', 'Individual person promoting products.', 10),
    ('BUSINESS', 'Business', 'Business entity promoting products.', 20),
    ('INFLUENCER', 'Influencer', 'Social media influencer.', 30),
    ('NETWORK', 'Network', 'Affiliate network managing multiple affiliates.', 40),
    ('CONTENT_CREATOR', 'Content Creator', 'Blogger, YouTuber, podcaster.', 50),
    ('MEDIA_BUYER', 'Media Buyer', 'Paid advertising specialist.', 60),
    ('PARTNER', 'Strategic Partner', 'Long-term business partner.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Affiliate Status
CREATE TABLE IF NOT EXISTS affiliate.affiliate_status_lookup (
    affiliate_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.affiliate_status_lookup (code, name, description, sort_order) VALUES
    ('APPLICATION_PENDING', 'Application Pending', 'Application submitted, awaiting review.', 10),
    ('APPROVED', 'Approved', 'Application approved, affiliate active.', 20),
    ('ACTIVE', 'Active', 'Affiliate is actively promoting.', 30),
    ('ON_HOLD', 'On Hold', 'Affiliate temporarily paused.', 40),
    ('SUSPENDED', 'Suspended', 'Affiliate suspended due to violation.', 50),
    ('TERMINATED', 'Terminated', 'Affiliate relationship ended.', 60),
    ('REJECTED', 'Rejected', 'Application rejected.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Affiliate Tier
CREATE TABLE IF NOT EXISTS affiliate.affiliate_tier_lookup (
    affiliate_tier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.affiliate_tier_lookup (code, name, description, sort_order) VALUES
    ('BRONZE', 'Bronze', 'Entry-level affiliate.', 10),
    ('SILVER', 'Silver', 'Mid-level affiliate with good performance.', 20),
    ('GOLD', 'Gold', 'High-performing affiliate.', 30),
    ('PLATINUM', 'Platinum', 'Top-tier affiliate with premium benefits.', 40),
    ('DIAMOND', 'Diamond', 'Elite affiliate with exclusive benefits.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Commission Type
CREATE TABLE IF NOT EXISTS affiliate.commission_type_lookup (
    commission_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.commission_type_lookup (code, name, description, sort_order) VALUES
    ('PERCENTAGE', 'Percentage', 'Commission as percentage of order value.', 10),
    ('FIXED', 'Fixed Amount', 'Fixed commission per order.', 20),
    ('PERCENTAGE_PER_ITEM', 'Percentage Per Item', 'Percentage per item sold.', 30),
    ('FIXED_PER_ITEM', 'Fixed Per Item', 'Fixed amount per item sold.', 40),
    ('TIERED', 'Tiered', 'Commission rate varies by volume.', 50),
    ('CPA', 'CPA (Cost Per Action)', 'Commission per specific action (signup, etc.).', 60),
    ('HYBRID', 'Hybrid', 'Combination of percentage and fixed.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Commission Status
CREATE TABLE IF NOT EXISTS affiliate.commission_status_lookup (
    commission_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.commission_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Commission calculated, awaiting return window.', 10),
    ('LOCKED', 'Locked', 'Return window passed, commission locked.', 20),
    ('APPROVED', 'Approved', 'Commission approved for payout.', 30),
    ('PAID', 'Paid', 'Commission has been paid.', 40),
    ('REVERSED', 'Reversed', 'Commission reversed due to return/cancellation.', 50),
    ('REJECTED', 'Rejected', 'Commission rejected (fraud, policy).', 60),
    ('DISPUTED', 'Disputed', 'Commission under dispute.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Payout Status
CREATE TABLE IF NOT EXISTS affiliate.payout_status_lookup (
    payout_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.payout_status_lookup (code, name, description, sort_order) VALUES
    ('REQUESTED', 'Requested', 'Payout requested by affiliate.', 10),
    ('APPROVED', 'Approved', 'Payout approved by admin.', 20),
    ('PROCESSING', 'Processing', 'Payout being processed.', 30),
    ('PAID', 'Paid', 'Payout completed.', 40),
    ('FAILED', 'Failed', 'Payout failed.', 50),
    ('CANCELLED', 'Cancelled', 'Payout cancelled.', 60),
    ('ON_HOLD', 'On Hold', 'Payout on hold pending review.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Payout Method
CREATE TABLE IF NOT EXISTS affiliate.payout_method_lookup (
    payout_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.payout_method_lookup (code, name, description, sort_order) VALUES
    ('BANK_TRANSFER', 'Bank Transfer', 'Direct bank transfer.', 10),
    ('WALLET', 'Digital Wallet', 'JazzCash, EasyPaisa, etc.', 20),
    ('CHECK', 'Check', 'Physical check.', 30),
    ('PAYPAL', 'PayPal', 'PayPal transfer.', 40),
    ('CASH', 'Cash', 'Cash payment.', 50),
    ('CREDIT_NOTE', 'Credit Note', 'Store credit.', 60),
    ('CRYPTO', 'Cryptocurrency', 'Crypto wallet transfer.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Attribution Model
CREATE TABLE IF NOT EXISTS affiliate.attribution_model_lookup (
    attribution_model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.attribution_model_lookup (code, name, description, sort_order) VALUES
    ('FIRST_CLICK', 'First Click', 'Credit to first affiliate touchpoint.', 10),
    ('LAST_CLICK', 'Last Click', 'Credit to last affiliate touchpoint.', 20),
    ('LINEAR', 'Linear', 'Equal credit to all touchpoints.', 30),
    ('TIME_DECAY', 'Time Decay', 'More credit to recent touchpoints.', 40),
    ('LAST_NON_DIRECT', 'Last Non-Direct', 'Last affiliate before direct visit.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Fraud Flag Type
CREATE TABLE IF NOT EXISTS affiliate.fraud_flag_type_lookup (
    fraud_flag_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO affiliate.fraud_flag_type_lookup (code, name, description, severity, sort_order) VALUES
    ('SELF_PURCHASE', 'Self-Purchase', 'Affiliate purchasing through own link.', 'HIGH', 10),
    ('COOKIE_STUFFING', 'Cookie Stuffing', 'Manipulating tracking cookies.', 'CRITICAL', 20),
    ('FAKE_CLICKS', 'Fake Clicks', 'Bot or artificial click generation.', 'HIGH', 30),
    ('BRAND_BIDDING', 'Brand Bidding', 'Bidding on brand keywords.', 'MEDIUM', 40),
    ('COUPON_LEAK', 'Coupon Leak', 'Sharing exclusive coupons publicly.', 'MEDIUM', 50),
    ('MULTIPLE_ACCOUNTS', 'Multiple Accounts', 'Operating multiple affiliate accounts.', 'HIGH', 60),
    ('INCENTIVIZED_TRAFFIC', 'Incentivized Traffic', 'Paying users to click/buy.', 'MEDIUM', 70),
    ('MISLEADING_CONTENT', 'Misleading Content', 'False advertising or claims.', 'HIGH', 80),
    ('INVALID_RETURNS', 'Invalid Returns', 'Suspicious return patterns.', 'HIGH', 90),
    ('ACCOUNT_SHARING', 'Account Sharing', 'Sharing affiliate account credentials.', 'MEDIUM', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, severity = EXCLUDED.severity, sort_order = EXCLUDED.sort_order;

-- ============================================================
-- 17.1 AFFILIATE PROGRAMS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_programs (
    affiliate_program_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    commission_type_id UUID NOT NULL,
    attribution_model_id UUID NOT NULL DEFAULT (SELECT attribution_model_id FROM affiliate.attribution_model_lookup WHERE code = 'LAST_CLICK'),

    program_code VARCHAR(50) NOT NULL,
    program_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    default_commission_rate NUMERIC(7,4) NOT NULL DEFAULT 0,
    minimum_payout_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    payout_cycle_days INTEGER NOT NULL DEFAULT 30,
    return_window_days INTEGER NOT NULL DEFAULT 14,
    cookie_duration_days INTEGER NOT NULL DEFAULT 30,

    allows_self_referral BOOLEAN NOT NULL DEFAULT FALSE,
    allows_coupon_sites BOOLEAN NOT NULL DEFAULT FALSE,
    allows_cashback_sites BOOLEAN NOT NULL DEFAULT FALSE,
    requires_approval BOOLEAN NOT NULL DEFAULT TRUE,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,

    terms_and_conditions TEXT NULL,
    start_date DATE NULL,
    end_date DATE NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ap_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ap_commission_type FOREIGN KEY (commission_type_id) REFERENCES affiliate.commission_type_lookup(commission_type_id),
    CONSTRAINT fk_ap_attribution FOREIGN KEY (attribution_model_id) REFERENCES affiliate.attribution_model_lookup(attribution_model_id),
    CONSTRAINT uq_program_code UNIQUE (company_id, program_code),
    CONSTRAINT ck_ap_commission_rate CHECK (default_commission_rate >= 0 AND default_commission_rate <= 100),
    CONSTRAINT ck_ap_payout CHECK (minimum_payout_amount >= 0),
    CONSTRAINT ck_ap_cookie CHECK (cookie_duration_days >= 1),
    CONSTRAINT ck_ap_return_window CHECK (return_window_days >= 0)
);

CREATE INDEX ix_ap_company ON affiliate.affiliate_programs(company_id);

-- ============================================================
-- 17.3 AFFILIATES
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliates (
    affiliate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_program_id UUID NOT NULL,
    affiliate_type_id UUID NOT NULL,
    affiliate_status_id UUID NOT NULL DEFAULT (SELECT affiliate_status_id FROM affiliate.affiliate_status_lookup WHERE code = 'APPLICATION_PENDING'),
    affiliate_tier_id UUID NULL,
    customer_id UUID NULL,
    parent_affiliate_id UUID NULL,
    referred_by_affiliate_id UUID NULL,
    assigned_to_employee_id UUID NULL,

    affiliate_code VARCHAR(50) NOT NULL,
    display_name VARCHAR(200) NOT NULL,
    first_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    business_name VARCHAR(200) NULL,
    email VARCHAR(300) NOT NULL,
    phone VARCHAR(50) NULL,
    website_url VARCHAR(500) NULL,
    social_media_urls JSONB NULL,

    tax_number VARCHAR(100) NULL,
    national_id VARCHAR(100) NULL,
    company_registration_number VARCHAR(100) NULL,

    preferred_payout_method_id UUID NULL,
    bank_name VARCHAR(200) NULL,
    bank_account_number VARCHAR(100) NULL,
    bank_account_title VARCHAR(200) NULL,
    bank_iban VARCHAR(50) NULL,
    wallet_number VARCHAR(100) NULL,

    total_clicks BIGINT NOT NULL DEFAULT 0,
    total_orders BIGINT NOT NULL DEFAULT 0,
    total_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_commission NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_paid NUMERIC(19,4) NOT NULL DEFAULT 0,
    current_balance NUMERIC(19,4) NOT NULL DEFAULT 0,

    conversion_rate NUMERIC(7,4) NOT NULL DEFAULT 0,
    average_order_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    joined_at TIMESTAMPTZ NULL,
    approved_at TIMESTAMPTZ NULL,
    suspended_at TIMESTAMPTZ NULL,
    terminated_at TIMESTAMPTZ NULL,
    suspension_reason TEXT NULL,
    termination_reason TEXT NULL,

    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_aff_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_aff_program FOREIGN KEY (affiliate_program_id) REFERENCES affiliate.affiliate_programs(affiliate_program_id),
    CONSTRAINT fk_aff_type FOREIGN KEY (affiliate_type_id) REFERENCES affiliate.affiliate_type_lookup(affiliate_type_id),
    CONSTRAINT fk_aff_status FOREIGN KEY (affiliate_status_id) REFERENCES affiliate.affiliate_status_lookup(affiliate_status_id),
    CONSTRAINT fk_aff_tier FOREIGN KEY (affiliate_tier_id) REFERENCES affiliate.affiliate_tier_lookup(affiliate_tier_id),
    CONSTRAINT fk_aff_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_aff_parent FOREIGN KEY (parent_affiliate_id) REFERENCES affiliate.affiliates(affiliate_id),
    CONSTRAINT fk_aff_referred_by FOREIGN KEY (referred_by_affiliate_id) REFERENCES affiliate.affiliates(affiliate_id),
    CONSTRAINT fk_aff_employee FOREIGN KEY (assigned_to_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_aff_payout_method FOREIGN KEY (preferred_payout_method_id) REFERENCES affiliate.payout_method_lookup(payout_method_id),
    CONSTRAINT uq_affiliate_code UNIQUE (company_id, affiliate_code),
    CONSTRAINT ck_aff_balance CHECK (current_balance >= 0)
);

CREATE INDEX ix_aff_company ON affiliate.affiliates(company_id);
CREATE INDEX ix_aff_program ON affiliate.affiliates(affiliate_program_id);
CREATE INDEX ix_aff_status ON affiliate.affiliates(affiliate_status_id);
CREATE INDEX ix_aff_customer ON affiliate.affiliates(customer_id);
CREATE INDEX ix_aff_email ON affiliate.affiliates(email);

-- ============================================================
-- 17.4 AFFILIATE APPLICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_applications (
    affiliate_application_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_program_id UUID NOT NULL,
    affiliate_id UUID NULL,

    application_number VARCHAR(50) NOT NULL,
    applicant_name VARCHAR(200) NOT NULL,
    applicant_email VARCHAR(300) NOT NULL,
    applicant_phone VARCHAR(50) NULL,
    applicant_type VARCHAR(50) NOT NULL DEFAULT 'INDIVIDUAL',

    website_url VARCHAR(500) NULL,
    social_media_profiles JSONB NULL,
    promotion_methods TEXT NULL,
    expected_monthly_traffic INTEGER NULL,
    previous_experience TEXT NULL,
    reason_for_joining TEXT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED',
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMPTZ NULL,
    reviewed_by_user_id UUID NULL,
    review_notes TEXT NULL,
    rejection_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_aa_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_aa_program FOREIGN KEY (affiliate_program_id) REFERENCES affiliate.affiliate_programs(affiliate_program_id),
    CONSTRAINT fk_aa_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id),
    CONSTRAINT uq_application_number UNIQUE (company_id, application_number),
    CONSTRAINT ck_aa_status CHECK (status IN ('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
    CONSTRAINT ck_aa_type CHECK (applicant_type IN ('INDIVIDUAL', 'BUSINESS', 'INFLUENCER', 'NETWORK', 'CONTENT_CREATOR', 'MEDIA_BUYER', 'PARTNER'))
);

CREATE INDEX ix_aa_company ON affiliate.affiliate_applications(company_id);
CREATE INDEX ix_aa_status ON affiliate.affiliate_applications(status);

-- ============================================================
-- 17.5 AFFILIATE TIERS (with thresholds)
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_tier_rules (
    affiliate_tier_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_tier_id UUID NOT NULL,
    affiliate_program_id UUID NOT NULL,

    minimum_orders INTEGER NOT NULL DEFAULT 0,
    minimum_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,
    minimum_clicks BIGINT NOT NULL DEFAULT 0,

    commission_rate_override NUMERIC(7,4) NULL,
    bonus_percent NUMERIC(5,2) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_atr_tier FOREIGN KEY (affiliate_tier_id) REFERENCES affiliate.affiliate_tier_lookup(affiliate_tier_id),
    CONSTRAINT fk_atr_program FOREIGN KEY (affiliate_program_id) REFERENCES affiliate.affiliate_programs(affiliate_program_id)
);

-- ============================================================
-- 17.6 AFFILIATE LINKS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_links (
    affiliate_link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID NOT NULL,
    campaign_id UUID NULL,
    product_id UUID NULL,
    product_variant_id UUID NULL,

    link_code VARCHAR(100) NOT NULL UNIQUE,
    link_name VARCHAR(300) NOT NULL,
    destination_url VARCHAR(2000) NOT NULL,
    short_url VARCHAR(500) NULL,
    qr_code_url VARCHAR(500) NULL,

    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,
    utm_content VARCHAR(200) NULL,
    utm_term VARCHAR(200) NULL,

    total_clicks BIGINT NOT NULL DEFAULT 0,
    total_conversions BIGINT NOT NULL DEFAULT 0,
    conversion_rate NUMERIC(7,4) NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_al_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id) ON DELETE CASCADE,
    CONSTRAINT fk_al_campaign FOREIGN KEY (campaign_id) REFERENCES marketing.campaigns(campaign_id),
    CONSTRAINT fk_al_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id)
);

CREATE INDEX ix_al_affiliate ON affiliate.affiliate_links(affiliate_id);
CREATE INDEX ix_al_code ON affiliate.affiliate_links(link_code);

-- ============================================================
-- 17.7 AFFILIATE COUPONS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_coupons (
    affiliate_coupon_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID NOT NULL,
    coupon_id UUID NOT NULL,

    is_exclusive BOOLEAN NOT NULL DEFAULT FALSE,
    usage_limit_per_customer INTEGER NULL,
    total_usage_count BIGINT NOT NULL DEFAULT 0,
    total_revenue_generated NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_commission_generated NUMERIC(19,4) NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_affiliate_coupon UNIQUE (affiliate_id, coupon_id),
    CONSTRAINT fk_ac_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id) ON DELETE CASCADE,
    CONSTRAINT fk_ac_coupon FOREIGN KEY (coupon_id) REFERENCES pricing.coupons(coupon_id)
);

-- ============================================================
-- 17.8 CLICK TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_clicks (
    affiliate_click_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID NOT NULL,
    affiliate_link_id UUID NOT NULL,
    customer_id UUID NULL,

    click_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET NULL,
    user_agent TEXT NULL,
    referrer_url VARCHAR(2000) NULL,
    landing_url VARCHAR(2000) NULL,
    device_type VARCHAR(30) NULL,
    country_code VARCHAR(10) NULL,
    city VARCHAR(100) NULL,

    session_id VARCHAR(200) NULL,
    is_unique BOOLEAN NOT NULL DEFAULT TRUE,
    is_bot BOOLEAN NOT NULL DEFAULT FALSE,
    bot_score NUMERIC(5,2) NULL,

    converted BOOLEAN NOT NULL DEFAULT FALSE,
    converted_at TIMESTAMPTZ NULL,
    order_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_aclick_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id) ON DELETE CASCADE,
    CONSTRAINT fk_aclick_link FOREIGN KEY (affiliate_link_id) REFERENCES affiliate.affiliate_links(affiliate_link_id) ON DELETE CASCADE,
    CONSTRAINT fk_aclick_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_aclick_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT ck_aclick_device CHECK (device_type IS NULL OR device_type IN ('DESKTOP', 'MOBILE', 'TABLET', 'UNKNOWN'))
);

CREATE INDEX ix_aclick_affiliate ON affiliate.affiliate_clicks(affiliate_id);
CREATE INDEX ix_aclick_link ON affiliate.affiliate_clicks(affiliate_link_id);
CREATE INDEX ix_aclick_date ON affiliate.affiliate_clicks(click_date DESC);
CREATE INDEX ix_aclick_customer ON affiliate.affiliate_clicks(customer_id);
CREATE INDEX ix_aclick_order ON affiliate.affiliate_clicks(order_id);

-- ============================================================
-- 17.9 TRACKING SESSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_tracking_sessions (
    tracking_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID NOT NULL,
    affiliate_link_id UUID NOT NULL,
    customer_id UUID NULL,

    session_token VARCHAR(200) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ NULL,

    click_count INTEGER NOT NULL DEFAULT 0,
    page_views INTEGER NOT NULL DEFAULT 0,
    cart_added BOOLEAN NOT NULL DEFAULT FALSE,
    checkout_started BOOLEAN NOT NULL DEFAULT FALSE,
    order_completed BOOLEAN NOT NULL DEFAULT FALSE,
    order_id UUID NULL,

    ip_address INET NULL,
    user_agent TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ats_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id) ON DELETE CASCADE,
    CONSTRAINT fk_ats_link FOREIGN KEY (affiliate_link_id) REFERENCES affiliate.affiliate_links(affiliate_link_id) ON DELETE CASCADE,
    CONSTRAINT fk_ats_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ats_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT ck_ats_expiry CHECK (expires_at > started_at)
);

CREATE INDEX ix_ats_affiliate ON affiliate.affiliate_tracking_sessions(affiliate_id);
CREATE INDEX ix_ats_token ON affiliate.affiliate_tracking_sessions(session_token);
CREATE INDEX ix_ats_customer ON affiliate.affiliate_tracking_sessions(customer_id);

-- ============================================================
-- 17.10 ATTRIBUTION RULES & ATTRIBUTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.attribution_rules (
    attribution_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_program_id UUID NOT NULL,
    attribution_model_id UUID NOT NULL,

    rule_name VARCHAR(200) NOT NULL,
    cookie_window_days INTEGER NOT NULL DEFAULT 30,
    post_click_window_days INTEGER NOT NULL DEFAULT 30,
    post_view_window_days INTEGER NULL,
    priority INTEGER NOT NULL DEFAULT 0,

    applies_to_new_customers BOOLEAN NOT NULL DEFAULT TRUE,
    applies_to_existing_customers BOOLEAN NOT NULL DEFAULT FALSE,
    excludes_self_referral BOOLEAN NOT NULL DEFAULT TRUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ar_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ar_program FOREIGN KEY (affiliate_program_id) REFERENCES affiliate.affiliate_programs(affiliate_program_id) ON DELETE CASCADE,
    CONSTRAINT fk_ar_model FOREIGN KEY (attribution_model_id) REFERENCES affiliate.attribution_model_lookup(attribution_model_id)
);

CREATE TABLE IF NOT EXISTS affiliate.attributions (
    attribution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    order_id UUID NULL,
    affiliate_click_id UUID NULL,
    tracking_session_id UUID NULL,
    attribution_model_id UUID NOT NULL,

    attribution_type VARCHAR(30) NOT NULL DEFAULT 'ORDER',
    attribution_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    attributed_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    attribution_weight NUMERIC(5,4) NOT NULL DEFAULT 1.0,

    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    is_valid BOOLEAN NOT NULL DEFAULT TRUE,
    invalidated_at TIMESTAMPTZ NULL,
    invalidation_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_attr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_attr_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id),
    CONSTRAINT fk_attr_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_attr_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_attr_click FOREIGN KEY (affiliate_click_id) REFERENCES affiliate.affiliate_clicks(affiliate_click_id),
    CONSTRAINT fk_attr_session FOREIGN KEY (tracking_session_id) REFERENCES affiliate.affiliate_tracking_sessions(tracking_session_id),
    CONSTRAINT fk_attr_model FOREIGN KEY (attribution_model_id) REFERENCES affiliate.attribution_model_lookup(attribution_model_id),
    CONSTRAINT fk_attr_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_attr_type CHECK (attribution_type IN ('ORDER', 'SIGNUP', 'LEAD', 'SUBSCRIPTION', 'OTHER')),
    CONSTRAINT ck_attr_amount CHECK (attributed_amount >= 0),
    CONSTRAINT ck_attr_weight CHECK (attribution_weight >= 0 AND attribution_weight <= 1)
);

CREATE INDEX ix_attr_affiliate ON affiliate.attributions(affiliate_id);
CREATE INDEX ix_attr_customer ON affiliate.attributions(customer_id);
CREATE INDEX ix_attr_order ON affiliate.attributions(order_id);

-- ============================================================
-- 17.11 COMMISSION RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.commission_rules (
    commission_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_program_id UUID NOT NULL,
    commission_type_id UUID NOT NULL,
    affiliate_tier_id UUID NULL,
    product_category_id UUID NULL,
    product_id UUID NULL,

    rule_name VARCHAR(200) NOT NULL,
    commission_rate NUMERIC(7,4) NULL,
    fixed_amount NUMERIC(19,4) NULL,
    minimum_order_amount NUMERIC(19,4) NULL,
    maximum_commission_amount NUMERIC(19,4) NULL,

    applies_to_subtotal BOOLEAN NOT NULL DEFAULT TRUE,
    applies_to_tax BOOLEAN NOT NULL DEFAULT FALSE,
    applies_to_shipping BOOLEAN NOT NULL DEFAULT FALSE,
    excludes_discounted_items BOOLEAN NOT NULL DEFAULT FALSE,

    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    start_date DATE NULL,
    end_date DATE NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cr_program FOREIGN KEY (affiliate_program_id) REFERENCES affiliate.affiliate_programs(affiliate_program_id) ON DELETE CASCADE,
    CONSTRAINT fk_cr_type FOREIGN KEY (commission_type_id) REFERENCES affiliate.commission_type_lookup(commission_type_id),
    CONSTRAINT fk_cr_tier FOREIGN KEY (affiliate_tier_id) REFERENCES affiliate.affiliate_tier_lookup(affiliate_tier_id),
    CONSTRAINT ck_cr_rate CHECK (commission_rate IS NULL OR (commission_rate >= 0 AND commission_rate <= 100)),
    CONSTRAINT ck_cr_fixed CHECK (fixed_amount IS NULL OR fixed_amount >= 0)
);

-- ============================================================
-- 17.12 COMMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.commissions (
    commission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_id UUID NOT NULL,
    order_id UUID NOT NULL,
    attribution_id UUID NULL,
    commission_rule_id UUID NULL,
    commission_status_id UUID NOT NULL DEFAULT (SELECT commission_status_id FROM affiliate.commission_status_lookup WHERE code = 'PENDING'),

    commission_number VARCHAR(50) NOT NULL,
    order_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    commission_rate NUMERIC(7,4) NULL,
    commission_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    adjustment_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    final_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    calculated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    locked_at TIMESTAMPTZ NULL,
    approved_at TIMESTAMPTZ NULL,
    approved_by_user_id UUID NULL,
    paid_at TIMESTAMPTZ NULL,
    reversed_at TIMESTAMPTZ NULL,
    reversal_reason TEXT NULL,

    return_window_ends_at TIMESTAMPTZ NULL,
    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_comm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_comm_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id),
    CONSTRAINT fk_comm_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_comm_attribution FOREIGN KEY (attribution_id) REFERENCES affiliate.attributions(attribution_id),
    CONSTRAINT fk_comm_rule FOREIGN KEY (commission_rule_id) REFERENCES affiliate.commission_rules(commission_rule_id),
    CONSTRAINT fk_comm_status FOREIGN KEY (commission_status_id) REFERENCES affiliate.commission_status_lookup(commission_status_id),
    CONSTRAINT fk_comm_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_commission_number UNIQUE (company_id, commission_number),
    CONSTRAINT ck_comm_amounts CHECK (order_amount >= 0 AND commission_amount >= 0 AND final_amount >= 0)
);

CREATE INDEX ix_comm_affiliate ON affiliate.commissions(affiliate_id);
CREATE INDEX ix_comm_order ON affiliate.commissions(order_id);
CREATE INDEX ix_comm_status ON affiliate.commissions(commission_status_id);
CREATE INDEX ix_comm_return_window ON affiliate.commissions(return_window_ends_at);

-- ============================================================
-- 17.13 COMMISSION ADJUSTMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.commission_adjustments (
    commission_adjustment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commission_id UUID NOT NULL,
    return_request_id UUID NULL,

    adjustment_type VARCHAR(30) NOT NULL,
    adjustment_amount NUMERIC(19,4) NOT NULL,
    reason TEXT NOT NULL,
    adjusted_by_user_id UUID NULL,
    adjusted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ca_commission FOREIGN KEY (commission_id) REFERENCES affiliate.commissions(commission_id) ON DELETE CASCADE,
    CONSTRAINT fk_ca_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id),
    CONSTRAINT ck_ca_type CHECK (adjustment_type IN ('RETURN', 'CANCELLATION', 'FRAUD', 'MANUAL', 'DISPUTE', 'CORRECTION')),
    CONSTRAINT ck_ca_amount CHECK (adjustment_amount <> 0)
);

-- ============================================================
-- 17.14 FRAUD CONTROLS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.fraud_flags (
    fraud_flag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_id UUID NOT NULL,
    fraud_flag_type_id UUID NOT NULL,
    order_id UUID NULL,
    commission_id UUID NULL,

    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    description TEXT NOT NULL,
    evidence_json JSONB NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    detected_by VARCHAR(50) NOT NULL DEFAULT 'SYSTEM',

    status VARCHAR(30) NOT NULL DEFAULT 'FLAGGED',
    reviewed_at TIMESTAMPTZ NULL,
    reviewed_by_user_id UUID NULL,
    resolution_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ff_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ff_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id),
    CONSTRAINT fk_ff_type FOREIGN KEY (fraud_flag_type_id) REFERENCES affiliate.fraud_flag_type_lookup(fraud_flag_type_id),
    CONSTRAINT fk_ff_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_ff_commission FOREIGN KEY (commission_id) REFERENCES affiliate.commissions(commission_id),
    CONSTRAINT ck_ff_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_ff_status CHECK (status IN ('FLAGGED', 'INVESTIGATING', 'CONFIRMED', 'DISMISSED', 'RESOLVED'))
);

CREATE INDEX ix_ff_affiliate ON affiliate.fraud_flags(affiliate_id);
CREATE INDEX ix_ff_status ON affiliate.fraud_flags(status);

-- ============================================================
-- 17.15 AFFILIATE BALANCES
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_balance_transactions (
    balance_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID NOT NULL,
    commission_id UUID NULL,
    payout_request_id UUID NULL,

    transaction_type VARCHAR(30) NOT NULL,
    amount NUMERIC(19,4) NOT NULL,
    balance_before NUMERIC(19,4) NOT NULL,
    balance_after NUMERIC(19,4) NOT NULL,
    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_abt_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id) ON DELETE CASCADE,
    CONSTRAINT fk_abt_commission FOREIGN KEY (commission_id) REFERENCES affiliate.commissions(commission_id),
    CONSTRAINT ck_abt_type CHECK (transaction_type IN ('COMMISSION_EARNED', 'COMMISSION_REVERSED', 'PAYOUT_DEDUCTED', 'BONUS', 'MANUAL_ADJUSTMENT')),
    CONSTRAINT ck_abt_amount CHECK (amount <> 0),
    CONSTRAINT ck_abt_balance CHECK (balance_after >= 0)
);

CREATE INDEX ix_abt_affiliate ON affiliate.affiliate_balance_transactions(affiliate_id);

-- ============================================================
-- 17.16 PAYOUT REQUESTS & ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.payout_requests (
    payout_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    affiliate_id UUID NOT NULL,
    payout_status_id UUID NOT NULL DEFAULT (SELECT payout_status_id FROM affiliate.payout_status_lookup WHERE code = 'REQUESTED'),
    payout_method_id UUID NOT NULL,

    payout_number VARCHAR(50) NOT NULL,
    requested_amount NUMERIC(19,4) NOT NULL,
    approved_amount NUMERIC(19,4) NULL,
    paid_amount NUMERIC(19,4) NULL,
    processing_fee NUMERIC(19,4) NOT NULL DEFAULT 0,
    net_amount NUMERIC(19,4) NULL,
    currency_id UUID NOT NULL,

    bank_name VARCHAR(200) NULL,
    bank_account_number VARCHAR(100) NULL,
    bank_account_title VARCHAR(200) NULL,
    wallet_number VARCHAR(100) NULL,

    requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMPTZ NULL,
    approved_by_user_id UUID NULL,
    processed_at TIMESTAMPTZ NULL,
    paid_at TIMESTAMPTZ NULL,
    payment_reference VARCHAR(200) NULL,
    rejection_reason TEXT NULL,

    related_expense_claim_id UUID NULL,

    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pr_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id),
    CONSTRAINT fk_pr_status FOREIGN KEY (payout_status_id) REFERENCES affiliate.payout_status_lookup(payout_status_id),
    CONSTRAINT fk_pr_method FOREIGN KEY (payout_method_id) REFERENCES affiliate.payout_method_lookup(payout_method_id),
    CONSTRAINT fk_pr_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_payout_number UNIQUE (company_id, payout_number),
    CONSTRAINT ck_pr_amounts CHECK (requested_amount > 0 AND (approved_amount IS NULL OR approved_amount >= 0) AND (paid_amount IS NULL OR paid_amount >= 0))
);

CREATE INDEX ix_pr_affiliate ON affiliate.payout_requests(affiliate_id);
CREATE INDEX ix_pr_status ON affiliate.payout_requests(payout_status_id);

CREATE TABLE IF NOT EXISTS affiliate.payout_items (
    payout_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payout_request_id UUID NOT NULL,
    commission_id UUID NOT NULL,
    amount NUMERIC(19,4) NOT NULL,
    CONSTRAINT fk_pi_payout FOREIGN KEY (payout_request_id) REFERENCES affiliate.payout_requests(payout_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_pi_commission FOREIGN KEY (commission_id) REFERENCES affiliate.commissions(commission_id),
    CONSTRAINT ck_pi_amount CHECK (amount > 0)
);

-- ============================================================
-- 17.17 PERFORMANCE SUMMARY (Cache Table)
-- ============================================================

CREATE TABLE IF NOT EXISTS affiliate.affiliate_performance_summary (
    performance_summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    period_type VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',

    total_clicks BIGINT NOT NULL DEFAULT 0,
    unique_clicks BIGINT NOT NULL DEFAULT 0,
    total_conversions BIGINT NOT NULL DEFAULT 0,
    conversion_rate NUMERIC(7,4) NOT NULL DEFAULT 0,
    total_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_commission NUMERIC(19,4) NOT NULL DEFAULT 0,
    average_order_value NUMERIC(19,4) NOT NULL DEFAULT 0,
    earnings_per_click NUMERIC(19,4) NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_performance UNIQUE (affiliate_id, period_start, period_type),
    CONSTRAINT fk_ps_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliate.affiliates(affiliate_id) ON DELETE CASCADE,
    CONSTRAINT ck_ps_type CHECK (period_type IN ('DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY')),
    CONSTRAINT ck_ps_dates CHECK (period_end >= period_start)
);

CREATE INDEX ix_ps_affiliate ON affiliate.affiliate_performance_summary(affiliate_id);
CREATE INDEX ix_ps_period ON affiliate.affiliate_performance_summary(period_start);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_currency_id UUID;
    v_program_id UUID;
    v_commission_pct UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;
    SELECT commission_type_id INTO v_commission_pct FROM affiliate.commission_type_lookup WHERE code = 'PERCENTAGE';

    -- Create default affiliate program
    INSERT INTO affiliate.affiliate_programs (company_id, program_code, program_name, description, commission_type_id, default_commission_rate, minimum_payout_amount, payout_cycle_days, return_window_days, cookie_duration_days)
    SELECT v_company_id, 'AFF-PROG-001', 'Standard Affiliate Program', 'Default affiliate program for eStore.',
           v_commission_pct, 5.0000, 5000.0000, 30, 14, 30
    WHERE NOT EXISTS (SELECT 1 FROM affiliate.affiliate_programs WHERE company_id = v_company_id AND program_code = 'AFF-PROG-001')
    RETURNING affiliate_program_id INTO v_program_id;

    IF v_program_id IS NULL THEN
        SELECT affiliate_program_id INTO v_program_id FROM affiliate.affiliate_programs WHERE company_id = v_company_id AND program_code = 'AFF-PROG-001';
    END IF;

    -- Create default commission rule
    INSERT INTO affiliate.commission_rules (company_id, affiliate_program_id, commission_type_id, rule_name, commission_rate, priority)
    SELECT v_company_id, v_program_id, v_commission_pct, 'Standard 5% Commission', 5.0000, 0
    WHERE NOT EXISTS (SELECT 1 FROM affiliate.commission_rules WHERE company_id = v_company_id AND rule_name = 'Standard 5% Commission');

    -- Create default attribution rule
    INSERT INTO affiliate.attribution_rules (company_id, affiliate_program_id, attribution_model_id, rule_name, cookie_window_days)
    SELECT v_company_id, v_program_id,
           (SELECT attribution_model_id FROM affiliate.attribution_model_lookup WHERE code = 'LAST_CLICK'),
           'Default Last-Click Attribution', 30
    WHERE NOT EXISTS (SELECT 1 FROM affiliate.attribution_rules WHERE company_id = v_company_id AND rule_name = 'Default Last-Click Attribution');

    -- Create tier rules for the program
    INSERT INTO affiliate.affiliate_tier_rules (affiliate_tier_id, affiliate_program_id, minimum_orders, minimum_revenue, commission_rate_override)
    SELECT t.affiliate_tier_id, v_program_id,
        CASE t.code WHEN 'BRONZE' THEN 0 WHEN 'SILVER' THEN 10 WHEN 'GOLD' THEN 50 WHEN 'PLATINUM' THEN 200 ELSE 500 END,
        CASE t.code WHEN 'BRONZE' THEN 0 WHEN 'SILVER' THEN 50000 WHEN 'GOLD' THEN 500000 WHEN 'PLATINUM' THEN 2000000 ELSE 5000000 END,
        CASE t.code WHEN 'BRONZE' THEN 5.0 WHEN 'SILVER' THEN 6.0 WHEN 'GOLD' THEN 7.0 WHEN 'PLATINUM' THEN 8.0 ELSE 10.0 END
    FROM affiliate.affiliate_tier_lookup t
    WHERE NOT EXISTS (SELECT 1 FROM affiliate.affiliate_tier_rules atr WHERE atr.affiliate_tier_id = t.affiliate_tier_id AND atr.affiliate_program_id = v_program_id);

END $$;

COMMIT;