BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 16 — MARKETING & CAMPAIGN MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Components:
--   16.1  Marketing Channels
--   16.2  Campaigns & Campaign Types
--   16.3  Campaign Budgets & Expenses
--   16.4  Campaign Targets / Audiences
--   16.5  Campaign Products
--   16.6  Campaign Coupons (links to existing pricing.coupons)
--   16.7  Campaign Content / Templates
--   16.8  Campaign Schedules
--   16.9  Campaign Recipients & Events
--   16.10 Campaign Conversions
--   16.11 Marketing Automation Rules
--   16.12 Abandoned Cart Rules
--   16.13 Customer Journeys
--   16.14 UTM & Attribution
--   16.15 Attribution Models
-- ============================================================

CREATE SCHEMA IF NOT EXISTS marketing;

-- ============================================================
-- 16.1 MARKETING CHANNELS
-- ============================================================

CREATE TABLE IF NOT EXISTS marketing.marketing_channel_lookup (
    marketing_channel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO marketing.marketing_channel_lookup (code, name, description, sort_order) VALUES
    ('EMAIL', 'Email', 'Email marketing campaigns.', 10),
    ('SMS', 'SMS', 'SMS/text message campaigns.', 20),
    ('WHATSAPP', 'WhatsApp', 'WhatsApp marketing campaigns.', 30),
    ('PUSH', 'Push Notification', 'Mobile/web push notifications.', 40),
    ('IN_APP', 'In-App Message', 'In-app banners and messages.', 50),
    ('SOCIAL_FACEBOOK', 'Facebook/Instagram', 'Social media ads on Meta platforms.', 60),
    ('SOCIAL_GOOGLE', 'Google Ads', 'Google search/display ads.', 70),
    ('SOCIAL_TIKTOK', 'TikTok', 'TikTok marketing.', 80),
    ('AFFILIATE', 'Affiliate', 'Affiliate/partner marketing.', 90),
    ('REFERRAL', 'Referral', 'Customer referral programs.', 100),
    ('POS', 'POS / In-Store', 'Point-of-sale promotions.', 110),
    ('WEBSITE', 'Website', 'On-site banners, popups.', 120),
    ('TELEMARKETING', 'Telemarketing', 'Phone-based marketing.', 130),
    ('DIRECT_MAIL', 'Direct Mail', 'Physical mail marketing.', 140),
    ('OTHER', 'Other', 'Other marketing channels.', 150)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- ============================================================
-- 16.2 CAMPAIGN LOOKUPS
-- ============================================================

-- Campaign Status
CREATE TABLE IF NOT EXISTS marketing.campaign_status_lookup (
    campaign_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO marketing.campaign_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Campaign is being designed.', 10),
    ('SCHEDULED', 'Scheduled', 'Campaign is scheduled to launch.', 20),
    ('ACTIVE', 'Active', 'Campaign is currently running.', 30),
    ('PAUSED', 'Paused', 'Campaign is temporarily paused.', 40),
    ('COMPLETED', 'Completed', 'Campaign has finished.', 50),
    ('CANCELLED', 'Cancelled', 'Campaign was cancelled.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Campaign Type
CREATE TABLE IF NOT EXISTS marketing.campaign_type_lookup (
    campaign_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO marketing.campaign_type_lookup (code, name, description, sort_order) VALUES
    ('ONE_TIME', 'One-Time', 'Single broadcast campaign.', 10),
    ('RECURRING', 'Recurring', 'Repeats on a schedule.', 20),
    ('TRIGGERED', 'Triggered', 'Fires on customer event.', 30),
    ('ABANDONED_CART', 'Abandoned Cart', 'Targets customers who abandoned cart.', 40),
    ('JOURNEY', 'Journey', 'Multi-step customer journey.', 50),
    ('SEASONAL', 'Seasonal', 'Holiday/seasonal promotion.', 60),
    ('LOYALTY', 'Loyalty', 'Customer retention/loyalty campaign.', 70),
    ('RE_ACTIVATION', 'Re-activation', 'Win-back inactive customers.', 80),
    ('CROSS_SELL', 'Cross-Sell', 'Promote related products.', 90),
    ('UP_SELL', 'Up-Sell', 'Promote premium products.', 100),
    ('FLASH_SALE', 'Flash Sale', 'Limited-time sale.', 110),
    ('PRODUCT_LAUNCH', 'Product Launch', 'New product announcement.', 120),
    ('NEWSLETTER', 'Newsletter', 'Regular newsletter.', 130)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Audience Type
CREATE TABLE IF NOT EXISTS marketing.audience_type_lookup (
    audience_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO marketing.audience_type_lookup (code, name, description, sort_order) VALUES
    ('ALL', 'All Customers', 'All active customers.', 10),
    ('SEGMENT', 'Customer Segment', 'Based on customer group/segment.', 20),
    ('TAG', 'Tag-Based', 'Based on customer tags.', 30),
    ('CUSTOM', 'Custom List', 'Manually selected customer list.', 40),
    ('BEHAVIOR', 'Behavior-Based', 'Based on purchase/interaction behavior.', 50),
    ('RFM', 'RFM-Based', 'Recency, Frequency, Monetary segments.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Campaign Event Type
CREATE TABLE IF NOT EXISTS marketing.campaign_event_type_lookup (
    campaign_event_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO marketing.campaign_event_type_lookup (code, name, description, sort_order) VALUES
    ('SENT', 'Sent', 'Message sent to recipient.', 10),
    ('DELIVERED', 'Delivered', 'Message delivered successfully.', 20),
    ('OPENED', 'Opened', 'Message opened/read.', 30),
    ('CLICKED', 'Clicked', 'Link clicked in message.', 40),
    ('CONVERTED', 'Converted', 'Recipient completed target action.', 50),
    ('UNSUBSCRIBED', 'Unsubscribed', 'Recipient unsubscribed.', 60),
    ('BOUNCED', 'Bounced', 'Message bounced/failed.', 70),
    ('COMPLAINED', 'Complained', 'Recipient marked as spam.', 80),
    ('FORWARDED', 'Forwarded', 'Message forwarded.', 90),
    ('FAILED', 'Failed', 'Message delivery failed.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Automation Trigger Type
CREATE TABLE IF NOT EXISTS marketing.automation_trigger_lookup (
    automation_trigger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO marketing.automation_trigger_lookup (code, name, description, sort_order) VALUES
    ('CUSTOMER_REGISTERED', 'Customer Registered', 'New customer signs up.', 10),
    ('ORDER_COMPLETED', 'Order Completed', 'Customer completes an order.', 20),
    ('PAYMENT_COMPLETED', 'Payment Completed', 'Payment successfully processed.', 30),
    ('SHIPMENT_DELIVERED', 'Shipment Delivered', 'Order delivered to customer.', 40),
    ('RETURN_COMPLETED', 'Return Completed', 'Return/refund processed.', 50),
    ('CART_ABANDONED', 'Cart Abandoned', 'Customer abandons cart.', 60),
    ('PRODUCT_BACK_IN_STOCK', 'Product Back In Stock', 'Out-of-stock product available.', 70),
    ('PRICE_CHANGED', 'Price Changed', 'Product price changes.', 80),
    ('REVIEW_CREATED', 'Review Created', 'Customer posts a review.', 90),
    ('BIRTHDAY', 'Birthday', 'Customer birthday.', 100),
    ('ANNIVERSARY', 'Anniversary', 'Customer registration anniversary.', 110),
    ('INACTIVE_DAYS', 'Inactive Days', 'No activity for X days.', 120),
    ('VIP_THRESHOLD', 'VIP Threshold', 'Customer reaches VIP spend level.', 130),
    ('COUPON_EXPIRING', 'Coupon Expiring', 'Customer coupon about to expire.', 140)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Attribution Model
CREATE TABLE IF NOT EXISTS marketing.attribution_model_lookup (
    attribution_model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO marketing.attribution_model_lookup (code, name, description, sort_order) VALUES
    ('FIRST_TOUCH', 'First Touch', '100% credit to first interaction.', 10),
    ('LAST_TOUCH', 'Last Touch', '100% credit to last interaction.', 20),
    ('LINEAR', 'Linear', 'Equal credit to all touchpoints.', 30),
    ('TIME_DECAY', 'Time Decay', 'More credit to recent touchpoints.', 40),
    ('POSITION_BASED', 'Position-Based', '40% first, 40% last, 20% middle.', 50),
    ('DATA_DRIVEN', 'Data-Driven', 'ML-based attribution.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- ============================================================
-- 16.2 MARKETING CAMPAIGNS (MAIN TABLE)
-- ============================================================

CREATE TABLE IF NOT EXISTS marketing.campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    campaign_status_id UUID NOT NULL DEFAULT (SELECT campaign_status_id FROM marketing.campaign_status_lookup WHERE code = 'DRAFT'),
    campaign_type_id UUID NOT NULL,
    marketing_channel_id UUID NOT NULL,
    audience_type_id UUID NOT NULL DEFAULT (SELECT audience_type_id FROM marketing.audience_type_lookup WHERE code = 'ALL'),
    attribution_model_id UUID NULL,
    assigned_to_employee_id UUID NULL,
    assigned_to_user_id UUID NULL,
    parent_campaign_id UUID NULL,

    campaign_code VARCHAR(50) NOT NULL,
    campaign_name VARCHAR(300) NOT NULL,
    description TEXT NULL,
    objective TEXT NULL,

    start_date DATE NULL,
    end_date DATE NULL,
    scheduled_launch_at TIMESTAMPTZ NULL,
    actual_launch_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,

    currency_id UUID NOT NULL,
    target_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,
    target_orders INTEGER NOT NULL DEFAULT 0,
    target_recipients INTEGER NOT NULL DEFAULT 0,

    actual_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,
    actual_orders INTEGER NOT NULL DEFAULT 0,
    total_recipients INTEGER NOT NULL DEFAULT 0,
    total_sent INTEGER NOT NULL DEFAULT 0,
    total_delivered INTEGER NOT NULL DEFAULT 0,
    total_opened INTEGER NOT NULL DEFAULT 0,
    total_clicked INTEGER NOT NULL DEFAULT 0,
    total_converted INTEGER NOT NULL DEFAULT 0,
    total_unsubscribed INTEGER NOT NULL DEFAULT 0,
    total_bounced INTEGER NOT NULL DEFAULT 0,

    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_campaign_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_campaign_status FOREIGN KEY (campaign_status_id) REFERENCES marketing.campaign_status_lookup(campaign_status_id),
    CONSTRAINT fk_campaign_type FOREIGN KEY (campaign_type_id) REFERENCES marketing.campaign_type_lookup(campaign_type_id),
    CONSTRAINT fk_campaign_channel FOREIGN KEY (marketing_channel_id) REFERENCES marketing.marketing_channel_lookup(marketing_channel_id),
    CONSTRAINT fk_campaign_audience FOREIGN KEY (audience_type_id) REFERENCES marketing.audience_type_lookup(audience_type_id),
    CONSTRAINT fk_campaign_attribution FOREIGN KEY (attribution_model_id) REFERENCES marketing.attribution_model_lookup(attribution_model_id),
    CONSTRAINT fk_campaign_employee FOREIGN KEY (assigned_to_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_campaign_parent FOREIGN KEY (parent_campaign_id) REFERENCES marketing.campaigns(campaign_id),
    CONSTRAINT fk_campaign_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_campaign_code UNIQUE (company_id, campaign_code),
    CONSTRAINT ck_campaign_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX ix_campaign_company ON marketing.campaigns(company_id);
CREATE INDEX ix_campaign_status ON marketing.campaigns(campaign_status_id);
CREATE INDEX ix_campaign_type ON marketing.campaigns(campaign_type_id);
CREATE INDEX ix_campaign_channel ON marketing.campaigns(marketing_channel_id);
CREATE INDEX ix_campaign_dates ON marketing.campaigns(start_date, end_date);

-- ============================================================
-- 16.3 CAMPAIGN BUDGETS & EXPENSES
-- ============================================================

CREATE TABLE IF NOT EXISTS marketing.campaign_budgets (
    campaign_budget_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL,
    budget_type VARCHAR(50) NOT NULL DEFAULT 'TOTAL',
    allocated_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    spent_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT fk_cb_campaign FOREIGN KEY (campaign_id) REFERENCES marketing.campaigns(campaign_id) ON DELETE CASCADE,
    CONSTRAINT fk_cb_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_cb_budget_type CHECK (budget_type IN ('TOTAL', 'MEDIA', 'CREATIVE', 'DISCOUNTS', 'LABOR', 'OTHER')),
    CONSTRAINT ck_cb_amounts CHECK (allocated_amount >= 0 AND spent_amount >= 0)
);

CREATE TABLE IF NOT EXISTS marketing.campaign_expenses (
    campaign_expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL,
    company_id UUID NOT NULL,
    expense_category VARCHAR(50) NOT NULL DEFAULT 'MEDIA',
    description TEXT NULL,
    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    vendor_name VARCHAR(200) NULL,
    reference_number VARCHAR(100) NULL,
    related_expense_claim_id UUID NULL,
    notes TEXT NULL,
