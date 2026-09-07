BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 27 — RECOMMENDATIONS & PRODUCT DISCOVERY
-- DATABASE TABLES
-- ============================================================
-- Design Decisions:
--   1. Recommendations reference products — don't duplicate product data
--   2. Recommendations use existing inventory — don't create separate inventory
--   3. Recommendations use existing pricing — don't create separate pricing
--   4. Recommendations use existing orders — don't create separate order system
--   5. Recommendations use existing customers — don't create separate customer system
--   6. Recommendations are event-driven — use existing event system
--   7. Recommendations are eventually consistent — acceptable for discovery
--   8. Recommendations respect privacy — anonymous visitors use session IDs
--   9. Recommendations are testable — A/B testing support
--   10. Recommendations are measurable — analytics tracking
-- ============================================================
-- Components:
--   27.1  Recommendation Types & Strategies
--   27.2  Recommendation Rules
--   27.3  Product Relations
--   27.4  Affinity Matrix
--   27.5  Recommendation Campaigns (A/B Testing)
--   27.6  Recommendation Events
--   27.7  Impressions & Clicks
--   27.8  Conversions
--   27.9  Merchandising & Manual Placement
--   27.10 Exclusions
--   27.11 Analytics
-- ============================================================

CREATE SCHEMA IF NOT EXISTS recommendations;

-- ============================================================
-- 27.0 RECOMMENDATION LOOKUPS
-- ============================================================

-- Recommendation Type
CREATE TABLE IF NOT EXISTS recommendations.recommendation_type_lookup (
    recommendation_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO recommendations.recommendation_type_lookup (code, name, description, sort_order) VALUES
    ('RELATED', 'Related Products', 'Products related to current product.', 10),
    ('SIMILAR', 'Similar Products', 'Products similar to current product.', 20),
    ('FREQUENTLY_BOUGHT_TOGETHER', 'Frequently Bought Together', 'Products often purchased together.', 30),
    ('ALSO_BOUGHT', 'Customers Also Bought', 'Products other customers bought.', 40),
    ('ALSO_VIEWED', 'Customers Also Viewed', 'Products other customers viewed.', 50),
    ('UPSELL', 'Upsell', 'Higher-value alternatives.', 60),
    ('CROSS_SELL', 'Cross-Sell', 'Complementary products.', 70),
    ('RECENTLY_VIEWED', 'Recently Viewed', 'Products recently viewed by customer.', 80),
    ('RECENTLY_PURCHASED', 'Recently Purchased', 'Products recently purchased by customer.', 90),
    ('TRENDING', 'Trending Products', 'Currently trending products.', 100),
    ('BEST_SELLER', 'Best Sellers', 'Top selling products.', 110),
    ('NEW_ARRIVAL', 'New Arrivals', 'Recently added products.', 120),
    ('PERSONALIZED', 'Personalized', 'Personalized recommendations.', 130),
    ('CATEGORY', 'Category Recommendations', 'Products from same category.', 140),
    ('HOMEPAGE', 'Homepage Recommendations', 'Homepage featured products.', 150),
    ('CART', 'Cart Recommendations', 'Cart page recommendations.', 160),
    ('CHECKOUT', 'Checkout Recommendations', 'Checkout page recommendations.', 170),
    ('POST_PURCHASE', 'Post-Purchase', 'Post-purchase recommendations.', 180)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Recommendation Strategy
CREATE TABLE IF NOT EXISTS recommendations.recommendation_strategy_lookup (
    recommendation_strategy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO recommendations.recommendation_strategy_lookup (code, name, description, sort_order) VALUES
    ('RULE_BASED', 'Rule-Based', 'Recommendations based on predefined rules.', 10),
    ('COLLABORATIVE_FILTERING', 'Collaborative Filtering', 'Based on similar customer behavior.', 20),
    ('CONTENT_BASED', 'Content-Based', 'Based on product attributes.', 30),
    ('HYBRID', 'Hybrid', 'Combination of multiple strategies.', 40),
    ('TREND_BASED', 'Trend-Based', 'Based on trending products.', 50),
    ('MANUAL', 'Manual', 'Manually curated recommendations.', 60),
    ('POPULARITY', 'Popularity', 'Based on popularity metrics.', 70),
    ('RECENCY', 'Recency', 'Based on recent activity.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Recommendation Status
CREATE TABLE IF NOT EXISTS recommendations.recommendation_status_lookup (
    recommendation_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO recommendations.recommendation_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Recommendation pending activation.', 10),
    ('ACTIVE', 'Active', 'Recommendation is active.', 20),
    ('INACTIVE', 'Inactive', 'Recommendation is inactive.', 30),
    ('EXPIRED', 'Expired', 'Recommendation has expired.', 40),
    ('ARCHIVED', 'Archived', 'Recommendation archived.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Recommendation Placement
CREATE TABLE IF NOT EXISTS recommendations.recommendation_placement_lookup (
    recommendation_placement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO recommendations.recommendation_placement_lookup (code, name, description, sort_order) VALUES
    ('PRODUCT_PAGE', 'Product Page', 'Product detail page.', 10),
    ('PRODUCT_PAGE_RELATED', 'Product Page - Related', 'Related products section.', 20),
    ('PRODUCT_PAGE_UPSELL', 'Product Page - Upsell', 'Upsell section.', 30),
    ('PRODUCT_PAGE_CROSS_SELL', 'Product Page - Cross-Sell', 'Cross-sell section.', 40),
    ('CATEGORY_PAGE', 'Category Page', 'Category listing page.', 50),
    ('CART_PAGE', 'Cart Page', 'Shopping cart page.', 60),
    ('CHECKOUT_PAGE', 'Checkout Page', 'Checkout page.', 70),
    ('HOMEPAGE', 'Homepage', 'Website homepage.', 80),
    ('HOMEPAGE_HERO', 'Homepage Hero', 'Homepage hero section.', 90),
    ('HOMEPAGE_TRENDING', 'Homepage Trending', 'Homepage trending section.', 100),
    ('HOMEPAGE_NEW', 'Homepage New Arrivals', 'Homepage new arrivals section.', 110),
    ('SEARCH_RESULTS', 'Search Results', 'Search results page.', 120),
    ('POST_PURCHASE', 'Post-Purchase', 'Post-purchase page.', 130),
    ('EMAIL', 'Email', 'Email campaigns.', 140),
    ('NEWSLETTER', 'Newsletter', 'Newsletter content.', 150)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Campaign Status
CREATE TABLE IF NOT EXISTS recommendations.recommendation_campaign_status_lookup (
    recommendation_campaign_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO recommendations.recommendation_campaign_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Campaign is being configured.', 10),
    ('ACTIVE', 'Active', 'Campaign is running.', 20),
    ('PAUSED', 'Paused', 'Campaign is paused.', 30),
    ('COMPLETED', 'Completed', 'Campaign completed.', 40),
    ('CANCELLED', 'Cancelled', 'Campaign cancelled.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Recommendation Event Type
CREATE TABLE IF NOT EXISTS recommendations.recommendation_event_type_lookup (
    recommendation_event_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO recommendations.recommendation_event_type_lookup (code, name, description, sort_order) VALUES
    ('VIEW', 'View', 'Product viewed.', 10),
    ('ADD_TO_CART', 'Add to Cart', 'Product added to cart.', 20),
    ('PURCHASE', 'Purchase', 'Product purchased.', 30),
    ('CLICK', 'Click', 'Recommendation clicked.', 40),
    ('IMPRESSION', 'Impression', 'Recommendation displayed.', 50),
    ('DISMISS', 'Dismiss', 'Recommendation dismissed.', 60),
    ('SHARE', 'Share', 'Product shared.', 70),
    ('WISHLIST', 'Wishlist', 'Product added to wishlist.', 80),
    ('REVIEW', 'Review', 'Product reviewed.', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 27.2 RECOMMENDATION RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_rules (
    recommendation_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_type_id UUID NOT NULL,
    recommendation_strategy_id UUID NOT NULL,
    recommendation_status_id UUID NOT NULL DEFAULT (SELECT recommendation_status_id FROM recommendations.recommendation_status_lookup WHERE code = 'PENDING'),

    rule_code VARCHAR(50) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    priority INTEGER NOT NULL DEFAULT 0,
    max_results INTEGER NOT NULL DEFAULT 10,
    min_results INTEGER NOT NULL DEFAULT 1,

    -- Targeting
    target_entity_type VARCHAR(30) NOT NULL DEFAULT 'PRODUCT',
    target_entity_id UUID NULL,
    target_category_id UUID NULL,
    target_product_id UUID NULL,

    -- Conditions (JSON)
    conditions JSONB NULL,

    -- Scoring weights
    relevance_weight NUMERIC(5,2) NOT NULL DEFAULT 1.0,
    popularity_weight NUMERIC(5,2) NOT NULL DEFAULT 0.5,
    recency_weight NUMERIC(5,2) NOT NULL DEFAULT 0.3,
    margin_weight NUMERIC(5,2) NOT NULL DEFAULT 0.0,

    -- Display settings
    display_title VARCHAR(200) NULL,
    display_subtitle VARCHAR(300) NULL,

    -- Validity
    start_date DATE NULL,
    end_date DATE NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rr_type FOREIGN KEY (recommendation_type_id) REFERENCES recommendations.recommendation_type_lookup(recommendation_type_id),
    CONSTRAINT fk_rr_strategy FOREIGN KEY (recommendation_strategy_id) REFERENCES recommendations.recommendation_strategy_lookup(recommendation_strategy_id),
    CONSTRAINT fk_rr_status FOREIGN KEY (recommendation_status_id) REFERENCES recommendations.recommendation_status_lookup(recommendation_status_id),
    CONSTRAINT fk_rr_category FOREIGN KEY (target_category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT fk_rr_product FOREIGN KEY (target_product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT uq_rule_code UNIQUE (company_id, rule_code),
    CONSTRAINT ck_rr_target CHECK (target_entity_type IN ('PRODUCT', 'CATEGORY', 'COLLECTION', 'GLOBAL', 'CUSTOMER', 'CART', 'SESSION')),
    CONSTRAINT ck_rr_results CHECK (max_results >= min_results AND min_results >= 0)
);

CREATE INDEX ix_rr_company ON recommendations.recommendation_rules(company_id);
CREATE INDEX ix_rr_type ON recommendations.recommendation_rules(recommendation_type_id);
CREATE INDEX ix_rr_status ON recommendations.recommendation_rules(recommendation_status_id);
CREATE INDEX ix_rr_active ON recommendations.recommendation_rules(is_active, priority DESC);

-- Rule Conditions (detailed conditions)
CREATE TABLE IF NOT EXISTS recommendations.recommendation_rule_conditions (
    rule_condition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recommendation_rule_id UUID NOT NULL,

    condition_field VARCHAR(100) NOT NULL,
    condition_operator VARCHAR(30) NOT NULL,
    condition_value TEXT NULL,
    condition_value_json JSONB NULL,

    logic_operator VARCHAR(10) NOT NULL DEFAULT 'AND',
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rrc_rule FOREIGN KEY (recommendation_rule_id) REFERENCES recommendations.recommendation_rules(recommendation_rule_id) ON DELETE CASCADE,
    CONSTRAINT ck_rrc_operator CHECK (condition_operator IN ('EQUALS', 'NOT_EQUALS', 'CONTAINS', 'NOT_CONTAINS', 'GREATER_THAN', 'LESS_THAN', 'BETWEEN', 'IN', 'NOT_IN', 'IS_NULL', 'IS_NOT_NULL')),
    CONSTRAINT ck_rrc_logic CHECK (logic_operator IN ('AND', 'OR'))
);

CREATE INDEX ix_rrc_rule ON recommendations.recommendation_rule_conditions(recommendation_rule_id);

-- ============================================================
-- 27.3 PRODUCT RELATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.product_relations (
    product_relation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_type_id UUID NOT NULL,

    source_product_id UUID NOT NULL,
    source_variant_id UUID NULL,
    target_product_id UUID NOT NULL,
    target_variant_id UUID NULL,

    relation_strength NUMERIC(5,4) NOT NULL DEFAULT 0.5,
    relation_reason VARCHAR(200) NULL,

    is_manual BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    start_date DATE NULL,
    end_date DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pr_type FOREIGN KEY (recommendation_type_id) REFERENCES recommendations.recommendation_type_lookup(recommendation_type_id),
    CONSTRAINT fk_pr_source FOREIGN KEY (source_product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pr_source_variant FOREIGN KEY (source_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_pr_target FOREIGN KEY (target_product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pr_target_variant FOREIGN KEY (target_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT uq_product_relation UNIQUE (company_id, recommendation_type_id, source_product_id, target_product_id),
    CONSTRAINT ck_pr_strength CHECK (relation_strength >= 0 AND relation_strength <= 1),
    CONSTRAINT ck_pr_not_self CHECK (source_product_id <> target_product_id)
);

CREATE INDEX ix_pr_source ON recommendations.product_relations(source_product_id);
CREATE INDEX ix_pr_target ON recommendations.product_relations(target_product_id);
CREATE INDEX ix_pr_type ON recommendations.product_relations(recommendation_type_id);
CREATE INDEX ix_pr_active ON recommendations.product_relations(is_active);

-- ============================================================
-- 27.4 AFFINITY MATRIX
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.product_affinity (
    product_affinity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    product_a_id UUID NOT NULL,
    product_b_id UUID NOT NULL,

    -- Co-occurrence metrics
    co_purchase_count INTEGER NOT NULL DEFAULT 0,
    co_view_count INTEGER NOT NULL DEFAULT 0,
    co_cart_count INTEGER NOT NULL DEFAULT 0,

    -- Affinity scores
    purchase_affinity NUMERIC(7,4) NOT NULL DEFAULT 0,
    view_affinity NUMERIC(7,4) NOT NULL DEFAULT 0,
    cart_affinity NUMERIC(7,4) NOT NULL DEFAULT 0,
    overall_affinity NUMERIC(7,4) NOT NULL DEFAULT 0,

    -- Support/confidence/lift (market basket analysis)
    support NUMERIC(7,4) NULL,
    confidence NUMERIC(7,4) NULL,
    lift NUMERIC(7,4) NULL,

    last_calculated_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pa_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pa_product_a FOREIGN KEY (product_a_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pa_product_b FOREIGN KEY (product_b_id) REFERENCES catalog.products(product_id),
    CONSTRAINT uq_product_affinity UNIQUE (company_id, product_a_id, product_b_id),
    CONSTRAINT ck_pa_not_self CHECK (product_a_id <> product_b_id),
    CONSTRAINT ck_pa_affinity CHECK (purchase_affinity >= 0 AND view_affinity >= 0 AND cart_affinity >= 0 AND overall_affinity >= 0)
);

CREATE INDEX ix_pa_product_a ON recommendations.product_affinity(product_a_id);
CREATE INDEX ix_pa_product_b ON recommendations.product_affinity(product_b_id);
CREATE INDEX ix_pa_affinity ON recommendations.product_affinity(overall_affinity DESC);

-- Customer Affinity (for personalization)
CREATE TABLE IF NOT EXISTS recommendations.customer_affinity (
    customer_affinity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,

    product_id UUID NOT NULL,
    category_id UUID NULL,

    affinity_score NUMERIC(7,4) NOT NULL DEFAULT 0,
    interaction_count INTEGER NOT NULL DEFAULT 0,
    last_interaction_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ca_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ca_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ca_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ca_category FOREIGN KEY (category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT uq_customer_affinity UNIQUE (company_id, COALESCE(customer_id, '00000000-0000-0000-0000-000000000000'), COALESCE(session_id, 'NO_SESSION'), product_id)
);

CREATE INDEX ix_ca_customer ON recommendations.customer_affinity(customer_id);
CREATE INDEX ix_ca_session ON recommendations.customer_affinity(session_id);
CREATE INDEX ix_ca_product ON recommendations.customer_affinity(product_id);
CREATE INDEX ix_ca_score ON recommendations.customer_affinity(affinity_score DESC);

-- ============================================================
-- 27.5 RECOMMENDATION CAMPAIGNS (A/B TESTING)
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_campaigns (
    recommendation_campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_campaign_status_id UUID NOT NULL DEFAULT (SELECT recommendation_campaign_status_id FROM recommendations.recommendation_campaign_status_lookup WHERE code = 'DRAFT'),

    campaign_code VARCHAR(50) NOT NULL,
    campaign_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    campaign_type VARCHAR(30) NOT NULL DEFAULT 'AB_TEST',
    traffic_allocation_percent NUMERIC(5,2) NOT NULL DEFAULT 100,

    -- Targeting
    target_placement_id UUID NULL,
    target_segment_id UUID NULL,

    start_date TIMESTAMPTZ NULL,
    end_date TIMESTAMPTZ NULL,

    -- Metrics
    total_impressions INTEGER NOT NULL DEFAULT 0,
    total_clicks INTEGER NOT NULL DEFAULT 0,
    total_conversions INTEGER NOT NULL DEFAULT 0,
    conversion_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    winning_variant_id UUID NULL,
    winner_selected_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rc_status FOREIGN KEY (recommendation_campaign_status_id) REFERENCES recommendations.recommendation_campaign_status_lookup(recommendation_campaign_status_id),
    CONSTRAINT fk_rc_placement FOREIGN KEY (target_placement_id) REFERENCES recommendations.recommendation_placement_lookup(recommendation_placement_id),
    CONSTRAINT uq_campaign_code UNIQUE (company_id, campaign_code),
    CONSTRAINT ck_rc_type CHECK (campaign_type IN ('AB_TEST', 'MULTIVARIATE', 'SEASONAL', 'PROMOTIONAL', 'MERCHANDISING')),
    CONSTRAINT ck_rc_traffic CHECK (traffic_allocation_percent > 0 AND traffic_allocation_percent <= 100)
);

CREATE INDEX ix_rc_company ON recommendations.recommendation_campaigns(company_id);
CREATE INDEX ix_rc_status ON recommendations.recommendation_campaigns(recommendation_campaign_status_id);

-- Campaign Variants (A/B Test Variants)
CREATE TABLE IF NOT EXISTS recommendations.recommendation_campaign_variants (
    campaign_variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recommendation_campaign_id UUID NOT NULL,
    recommendation_rule_id UUID NULL,

    variant_code VARCHAR(10) NOT NULL,
    variant_name VARCHAR(100) NOT NULL,
    description TEXT NULL,

    traffic_percent NUMERIC(5,2) NOT NULL DEFAULT 50,

    -- Metrics
    impressions INTEGER NOT NULL DEFAULT 0,
    clicks INTEGER NOT NULL DEFAULT 0,
    conversions INTEGER NOT NULL DEFAULT 0,
    conversion_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    is_winner BOOLEAN NOT NULL DEFAULT FALSE,
    is_control BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rcv_campaign FOREIGN KEY (recommendation_campaign_id) REFERENCES recommendations.recommendation_campaigns(recommendation_campaign_id) ON DELETE CASCADE,
    CONSTRAINT fk_rcv_rule FOREIGN KEY (recommendation_rule_id) REFERENCES recommendations.recommendation_rules(recommendation_rule_id),
    CONSTRAINT uq_variant UNIQUE (recommendation_campaign_id, variant_code),
    CONSTRAINT ck_rcv_traffic CHECK (traffic_percent > 0 AND traffic_percent <= 100)
);

CREATE INDEX ix_rcv_campaign ON recommendations.recommendation_campaign_variants(recommendation_campaign_id);

-- ============================================================
-- 27.6 RECOMMENDATION EVENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_events (
    recommendation_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_event_type_id UUID NOT NULL,
    recommendation_rule_id UUID NULL,
    recommendation_campaign_id UUID NULL,
    campaign_variant_id UUID NULL,

    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,
    user_id UUID NULL,

    product_id UUID NULL,
    recommended_product_id UUID NULL,

    placement_id UUID NULL,
    placement_position INTEGER NULL,

    -- Context
    page_url VARCHAR(1000) NULL,
    referrer_url VARCHAR(1000) NULL,
    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    -- Device info
    device_type VARCHAR(30) NULL,
    ip_address INET NULL,
    user_agent TEXT NULL,

    -- Scoring
    recommendation_score NUMERIC(7,4) NULL,
    relevance_score NUMERIC(7,4) NULL,

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_re_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_re_type FOREIGN KEY (recommendation_event_type_id) REFERENCES recommendations.recommendation_event_type_lookup(recommendation_event_type_id),
    CONSTRAINT fk_re_rule FOREIGN KEY (recommendation_rule_id) REFERENCES recommendations.recommendation_rules(recommendation_rule_id),
    CONSTRAINT fk_re_campaign FOREIGN KEY (recommendation_campaign_id) REFERENCES recommendations.recommendation_campaigns(recommendation_campaign_id),
    CONSTRAINT fk_re_variant FOREIGN KEY (campaign_variant_id) REFERENCES recommendations.recommendation_campaign_variants(campaign_variant_id),
    CONSTRAINT fk_re_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_re_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_re_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_re_recommended FOREIGN KEY (recommended_product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_re_placement FOREIGN KEY (placement_id) REFERENCES recommendations.recommendation_placement_lookup(recommendation_placement_id)
);

CREATE INDEX ix_re_company ON recommendations.recommendation_events(company_id);
CREATE INDEX ix_re_type ON recommendations.recommendation_events(recommendation_event_type_id);
CREATE INDEX ix_re_customer ON recommendations.recommendation_events(customer_id);
CREATE INDEX ix_re_session ON recommendations.recommendation_events(session_id);
CREATE INDEX ix_re_product ON recommendations.recommendation_events(product_id);
CREATE INDEX ix_re_occurred ON recommendations.recommendation_events(occurred_at DESC);
CREATE INDEX ix_re_campaign ON recommendations.recommendation_events(recommendation_campaign_id);

-- ============================================================
-- 27.7 IMPRESSIONS & CLICKS
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_impressions (
    recommendation_impression_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_rule_id UUID NULL,
    recommendation_campaign_id UUID NULL,
    campaign_variant_id UUID NULL,

    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,

    product_id UUID NOT NULL,
    placement_id UUID NULL,
    placement_position INTEGER NULL,

    recommendation_score NUMERIC(7,4) NULL,

    displayed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    display_duration_ms INTEGER NULL,

    CONSTRAINT fk_ri_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ri_rule FOREIGN KEY (recommendation_rule_id) REFERENCES recommendations.recommendation_rules(recommendation_rule_id),
    CONSTRAINT fk_ri_campaign FOREIGN KEY (recommendation_campaign_id) REFERENCES recommendations.recommendation_campaigns(recommendation_campaign_id),
    CONSTRAINT fk_ri_variant FOREIGN KEY (campaign_variant_id) REFERENCES recommendations.recommendation_campaign_variants(campaign_variant_id),
    CONSTRAINT fk_ri_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ri_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ri_placement FOREIGN KEY (placement_id) REFERENCES recommendations.recommendation_placement_lookup(recommendation_placement_id)
);

CREATE INDEX ix_ri_customer ON recommendations.recommendation_impressions(customer_id);
CREATE INDEX ix_ri_session ON recommendations.recommendation_impressions(session_id);
CREATE INDEX ix_ri_product ON recommendations.recommendation_impressions(product_id);
CREATE INDEX ix_ri_displayed ON recommendations.recommendation_impressions(displayed_at DESC);

-- Recommendation Clicks
CREATE TABLE IF NOT EXISTS recommendations.recommendation_clicks (
    recommendation_click_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_impression_id UUID NULL,
    recommendation_rule_id UUID NULL,
    recommendation_campaign_id UUID NULL,
    campaign_variant_id UUID NULL,

    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,

    product_id UUID NOT NULL,
    clicked_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    click_position INTEGER NULL,
    click_source VARCHAR(50) NULL,

    CONSTRAINT fk_rcl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rcl_impression FOREIGN KEY (recommendation_impression_id) REFERENCES recommendations.recommendation_impressions(recommendation_impression_id),
    CONSTRAINT fk_rcl_rule FOREIGN KEY (recommendation_rule_id) REFERENCES recommendations.recommendation_rules(recommendation_rule_id),
    CONSTRAINT fk_rcl_campaign FOREIGN KEY (recommendation_campaign_id) REFERENCES recommendations.recommendation_campaigns(recommendation_campaign_id),
    CONSTRAINT fk_rcl_variant FOREIGN KEY (campaign_variant_id) REFERENCES recommendations.recommendation_campaign_variants(campaign_variant_id),
    CONSTRAINT fk_rcl_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rcl_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id)
);

CREATE INDEX ix_rcl_customer ON recommendations.recommendation_clicks(customer_id);
CREATE INDEX ix_rcl_product ON recommendations.recommendation_clicks(product_id);
CREATE INDEX ix_rcl_clicked ON recommendations.recommendation_clicks(clicked_at DESC);

-- ============================================================
-- 27.8 CONVERSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_conversions (
    recommendation_conversion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_rule_id UUID NULL,
    recommendation_campaign_id UUID NULL,
    campaign_variant_id UUID NULL,

    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,

    product_id UUID NOT NULL,
    order_id UUID NULL,
    order_item_id UUID NULL,

    conversion_value NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NULL,

    conversion_type VARCHAR(30) NOT NULL DEFAULT 'PURCHASE',

    converted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rconv_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rconv_rule FOREIGN KEY (recommendation_rule_id) REFERENCES recommendations.recommendation_rules(recommendation_rule_id),
    CONSTRAINT fk_rconv_campaign FOREIGN KEY (recommendation_campaign_id) REFERENCES recommendations.recommendation_campaigns(recommendation_campaign_id),
    CONSTRAINT fk_rconv_variant FOREIGN KEY (campaign_variant_id) REFERENCES recommendations.recommendation_campaign_variants(campaign_variant_id),
    CONSTRAINT fk_rconv_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rconv_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rconv_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_rconv_order_item FOREIGN KEY (order_item_id) REFERENCES sales.order_items(order_item_id),
    CONSTRAINT fk_rconv_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_rconv_type CHECK (conversion_type IN ('PURCHASE', 'ADD_TO_CART', 'VIEW_PRODUCT', 'SIGNUP', 'OTHER'))
);

CREATE INDEX ix_rconv_customer ON recommendations.recommendation_conversions(customer_id);
CREATE INDEX ix_rconv_product ON recommendations.recommendation_conversions(product_id);
CREATE INDEX ix_rconv_order ON recommendations.recommendation_conversions(order_id);
CREATE INDEX ix_rconv_converted ON recommendations.recommendation_conversions(converted_at DESC);

-- ============================================================
-- 27.9 MERCHANDISING & MANUAL PLACEMENT
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_merchandising (
    recommendation_merchandising_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_placement_id UUID NOT NULL,

    merchandising_code VARCHAR(50) NOT NULL,
    merchandising_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    -- Display settings
    display_title VARCHAR(200) NULL,
    display_subtitle VARCHAR(300) NULL,
    display_order INTEGER NOT NULL DEFAULT 0,

    -- Validity
    start_date DATE NULL,
    end_date DATE NULL,

    -- Targeting
    target_customer_segment_id UUID NULL,
    target_category_id UUID NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rm_placement FOREIGN KEY (recommendation_placement_id) REFERENCES recommendations.recommendation_placement_lookup(recommendation_placement_id),
    CONSTRAINT fk_rm_category FOREIGN KEY (target_category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT uq_merchandising_code UNIQUE (company_id, merchandising_code)
);

CREATE INDEX ix_rm_company ON recommendations.recommendation_merchandising(company_id);
CREATE INDEX ix_rm_placement ON recommendations.recommendation_merchandising(recommendation_placement_id);
CREATE INDEX ix_rm_active ON recommendations.recommendation_merchandising(is_active);

-- Merchandising Products
CREATE TABLE IF NOT EXISTS recommendations.recommendation_merchandising_products (
    merchandising_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recommendation_merchandising_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    is_boosted BOOLEAN NOT NULL DEFAULT FALSE,
    boost_weight NUMERIC(5,2) NULL,

    custom_title VARCHAR(200) NULL,
    custom_description TEXT NULL,
    custom_image_url VARCHAR(500) NULL,
    custom_cta_text VARCHAR(100) NULL,
    custom_cta_url VARCHAR(500) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rmp_merchandising FOREIGN KEY (recommendation_merchandising_id) REFERENCES recommendations.recommendation_merchandising(recommendation_merchandising_id) ON DELETE CASCADE,
    CONSTRAINT fk_rmp_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rmp_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT uq_merchandising_product UNIQUE (recommendation_merchandising_id, product_id)
);

CREATE INDEX ix_rmp_merchandising ON recommendations.recommendation_merchandising_products(recommendation_merchandising_id);
CREATE INDEX ix_rmp_product ON recommendations.recommendation_merchandising_products(product_id);

-- ============================================================
-- 27.10 EXCLUSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_exclusions (
    recommendation_exclusion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    exclusion_type VARCHAR(30) NOT NULL,
    product_id UUID NULL,
    category_id UUID NULL,
    customer_segment_id UUID NULL,

    exclusion_reason VARCHAR(200) NULL,

    start_date DATE NULL,
    end_date DATE NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_rexc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rexc_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rexc_category FOREIGN KEY (category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT ck_rexc_type CHECK (exclusion_type IN ('PRODUCT', 'CATEGORY', 'SEGMENT', 'GLOBAL'))
);

CREATE INDEX ix_rexc_company ON recommendations.recommendation_exclusions(company_id);
CREATE INDEX ix_rexc_product ON recommendations.recommendation_exclusions(product_id);
CREATE INDEX ix_rexc_category ON recommendations.recommendation_exclusions(category_id);
CREATE INDEX ix_rexc_active ON recommendations.recommendation_exclusions(is_active);

-- ============================================================
-- 27.11 ANALYTICS
-- ============================================================

CREATE TABLE IF NOT EXISTS recommendations.recommendation_analytics (
    recommendation_analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    recommendation_type_id UUID NULL,
    recommendation_rule_id UUID NULL,
    recommendation_campaign_id UUID NULL,
    placement_id UUID NULL,

    stat_date DATE NOT NULL,

    total_impressions INTEGER NOT NULL DEFAULT 0,
    unique_impressions INTEGER NOT NULL DEFAULT 0,
    total_clicks INTEGER NOT NULL DEFAULT 0,
    unique_clicks INTEGER NOT NULL DEFAULT 0,
    total_conversions INTEGER NOT NULL DEFAULT 0,
    conversion_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    click_through_rate NUMERIC(7,4) NULL,
    conversion_rate NUMERIC(7,4) NULL,
    revenue_per_impression NUMERIC(19,4) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rana_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rana_type FOREIGN KEY (recommendation_type_id) REFERENCES recommendations.recommendation_type_lookup(recommendation_type_id),
    CONSTRAINT fk_rana_rule FOREIGN KEY (recommendation_rule_id) REFERENCES recommendations.recommendation_rules(recommendation_rule_id),
    CONSTRAINT fk_rana_campaign FOREIGN KEY (recommendation_campaign_id) REFERENCES recommendations.recommendation_campaigns(recommendation_campaign_id),
    CONSTRAINT fk_rana_placement FOREIGN KEY (placement_id) REFERENCES recommendations.recommendation_placement_lookup(recommendation_placement_id),
    CONSTRAINT uq_recommendation_analytics UNIQUE (company_id, recommendation_type_id, recommendation_rule_id, recommendation_campaign_id, placement_id, stat_date)
);

CREATE INDEX ix_rana_company ON recommendations.recommendation_analytics(company_id);
CREATE INDEX ix_rana_date ON recommendations.recommendation_analytics(stat_date DESC);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Function: Get Product Recommendations
CREATE OR REPLACE FUNCTION recommendations.get_product_recommendations(
    p_product_id UUID,
    p_recommendation_type_code VARCHAR,
    p_limit INTEGER DEFAULT 10,
    p_customer_id UUID DEFAULT NULL,
    p_session_id VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR,
    product_slug VARCHAR,
    relation_strength NUMERIC,
    recommendation_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.product_id,
        p.product_name::VARCHAR,
        p.slug::VARCHAR,
        pr.relation_strength,
        pr.relation_strength as recommendation_score
    FROM recommendations.product_relations pr
    JOIN recommendations.recommendation_type_lookup rtl ON rtl.recommendation_type_id = pr.recommendation_type_id
    JOIN catalog.products p ON p.product_id = pr.target_product_id
    WHERE pr.source_product_id = p_product_id
      AND rtl.code = p_recommendation_type_code
      AND pr.is_active = TRUE
      AND (pr.start_date IS NULL OR pr.start_date <= CURRENT_DATE)
      AND (pr.end_date IS NULL OR pr.end_date >= CURRENT_DATE)
      AND p.is_active = TRUE
    ORDER BY pr.relation_strength DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Get Frequently Bought Together
CREATE OR REPLACE FUNCTION recommendations.get_frequently_bought_together(
    p_product_id UUID,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR,
    co_purchase_count INTEGER,
    purchase_affinity NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pa.product_b_id,
        p.product_name::VARCHAR,
        pa.co_purchase_count,
        pa.purchase_affinity
    FROM recommendations.product_affinity pa
    JOIN catalog.products p ON p.product_id = pa.product_b_id
    WHERE pa.product_a_id = p_product_id
      AND p.is_active = TRUE
    ORDER BY pa.purchase_affinity DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Get Personalized Recommendations
CREATE OR REPLACE FUNCTION recommendations.get_personalized_recommendations(
    p_customer_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR,
    affinity_score NUMERIC,
    category_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ca.product_id,
        p.product_name::VARCHAR,
        ca.affinity_score,
        c.category_name::VARCHAR
    FROM recommendations.customer_affinity ca
    JOIN catalog.products p ON p.product_id = ca.product_id
    LEFT JOIN catalog.categories c ON c.category_id = ca.category_id
    WHERE ca.customer_id = p_customer_id
      AND p.is_active = TRUE
    ORDER BY ca.affinity_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate Product Affinity
CREATE OR REPLACE FUNCTION recommendations.calculate_product_affinity(
    p_company_id UUID
)
RETURNS VOID AS $$
BEGIN
    -- This would be implemented with actual co-occurrence calculation
    -- For now, update last_calculated_at
    UPDATE recommendations.product_affinity
    SET last_calculated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE company_id = p_company_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_related_type UUID;
    v_similar_type UUID;
    v_fbt_type UUID;
    v_cross_sell_type UUID;
    v_upsell_type UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT recommendation_type_id INTO v_related_type FROM recommendations.recommendation_type_lookup WHERE code = 'RELATED';
    SELECT recommendation_type_id INTO v_similar_type FROM recommendations.recommendation_type_lookup WHERE code = 'SIMILAR';
    SELECT recommendation_type_id INTO v_fbt_type FROM recommendations.recommendation_type_lookup WHERE code = 'FREQUENTLY_BOUGHT_TOGETHER';
    SELECT recommendation_type_id INTO v_cross_sell_type FROM recommendations.recommendation_type_lookup WHERE code = 'CROSS_SELL';
    SELECT recommendation_type_id INTO v_upsell_type FROM recommendations.recommendation_type_lookup WHERE code = 'UPSELL';

    -- Create default recommendation rules
    INSERT INTO recommendations.recommendation_rules (company_id, recommendation_type_id, recommendation_strategy_id, recommendation_status_id, rule_code, rule_name, description, priority, max_results, target_entity_type)
    SELECT v_company_id, v_related_type,
           (SELECT recommendation_strategy_id FROM recommendations.recommendation_strategy_lookup WHERE code = 'CONTENT_BASED'),
           (SELECT recommendation_status_id FROM recommendations.recommendation_status_lookup WHERE code = 'ACTIVE'),
           'RELATED-DEFAULT', 'Related Products', 'Default related products rule.', 100, 8, 'PRODUCT'
    WHERE NOT EXISTS (SELECT 1 FROM recommendations.recommendation_rules WHERE company_id = v_company_id AND rule_code = 'RELATED-DEFAULT');

    INSERT INTO recommendations.recommendation_rules (company_id, recommendation_type_id, recommendation_strategy_id, recommendation_status_id, rule_code, rule_name, description, priority, max_results, target_entity_type)
    SELECT v_company_id, v_similar_type,
           (SELECT recommendation_strategy_id FROM recommendations.recommendation_strategy_lookup WHERE code = 'CONTENT_BASED'),
           (SELECT recommendation_status_id FROM recommendations.recommendation_status_lookup WHERE code = 'ACTIVE'),
           'SIMILAR-DEFAULT', 'Similar Products', 'Default similar products rule.', 90, 8, 'PRODUCT'
    WHERE NOT EXISTS (SELECT 1 FROM recommendations.recommendation_rules WHERE company_id = v_company_id AND rule_code = 'SIMILAR-DEFAULT');

    INSERT INTO recommendations.recommendation_rules (company_id, recommendation_type_id, recommendation_strategy_id, recommendation_status_id, rule_code, rule_name, description, priority, max_results, target_entity_type)
    SELECT v_company_id, v_fbt_type,
           (SELECT recommendation_strategy_id FROM recommendations.recommendation_strategy_lookup WHERE code = 'COLLABORATIVE_FILTERING'),
           (SELECT recommendation_status_id FROM recommendations.recommendation_status_lookup WHERE code = 'ACTIVE'),
           'FBT-DEFAULT', 'Frequently Bought Together', 'Default frequently bought together rule.', 95, 5, 'PRODUCT'
    WHERE NOT EXISTS (SELECT 1 FROM recommendations.recommendation_rules WHERE company_id = v_company_id AND rule_code = 'FBT-DEFAULT');

    INSERT INTO recommendations.recommendation_rules (company_id, recommendation_type_id, recommendation_strategy_id, recommendation_status_id, rule_code, rule_name, description, priority, max_results, target_entity_type)
    SELECT v_company_id, v_cross_sell_type,
           (SELECT recommendation_strategy_id FROM recommendations.recommendation_strategy_lookup WHERE code = 'RULE_BASED'),
           (SELECT recommendation_status_id FROM recommendations.recommendation_status_lookup WHERE code = 'ACTIVE'),
           'CROSS-SELL-DEFAULT', 'Cross-Sell Products', 'Default cross-sell rule.', 80, 6, 'CART'
    WHERE NOT EXISTS (SELECT 1 FROM recommendations.recommendation_rules WHERE company_id = v_company_id AND rule_code = 'CROSS-SELL-DEFAULT');

    INSERT INTO recommendations.recommendation_rules (company_id, recommendation_type_id, recommendation_strategy_id, recommendation_status_id, rule_code, rule_name, description, priority, max_results, target_entity_type)
    SELECT v_company_id, v_upsell_type,
           (SELECT recommendation_strategy_id FROM recommendations.recommendation_strategy_lookup WHERE code = 'RULE_BASED'),
           (SELECT recommendation_status_id FROM recommendations.recommendation_status_lookup WHERE code = 'ACTIVE'),
           'UPSELL-DEFAULT', 'Upsell Products', 'Default upsell rule.', 70, 4, 'PRODUCT'
    WHERE NOT EXISTS (SELECT 1 FROM recommendations.recommendation_rules WHERE company_id = v_company_id AND rule_code = 'UPSELL-DEFAULT');

END $$;

COMMIT;