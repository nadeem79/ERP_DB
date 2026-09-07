BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 05: PRICING, CURRENCY, TAX & PROMOTIONS
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   Money uses NUMERIC(19,4). Never use FLOAT for money.
--   Prices are per Variant per Currency per Price List.
--   Tax is calculated at order time, not stored on product.
--   Promotions/Discounts are applied at checkout, not on product.
-- ============================================================
-- Components:
--   05.1  Currencies & Exchange Rates
--   05.2  Price Lists & Price List Items
--   05.3  Product Prices
--   05.4  Price Rules / Adjustments
--   05.5  Price Change History
--   05.6  Tax Categories
--   05.7  Tax Rates & Tax Rules
--   05.8  Tax Exemptions
--   05.9  Promotions & Discount Rules
--   05.10 Coupons & Coupon Usages
--   05.11 Sales Channels
--   05.12 Customer Segments
--   05.13 Pricing Accounting Integration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS pricing;

-- ============================================================
-- 05.1 CURRENCY STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.currency_status_lookup (
    currency_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO pricing.currency_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Currency is active.', 10),
    ('INACTIVE', 'Inactive', 'Currency is disabled.', 20),
    ('DEPRECATED', 'Deprecated', 'Currency is deprecated.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 05.2 CURRENCIES
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.currencies (
    currency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    currency_status_id UUID NOT NULL DEFAULT (SELECT currency_status_id FROM pricing.currency_status_lookup WHERE code = 'ACTIVE'),

    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(20) NULL,
    symbol_position VARCHAR(20) NOT NULL DEFAULT 'PREFIX',
    decimal_places INTEGER NOT NULL DEFAULT 2,
    decimal_separator VARCHAR(5) NOT NULL DEFAULT '.',
    thousands_separator VARCHAR(5) NOT NULL DEFAULT ',',
    iso_code VARCHAR(10) NULL,

    is_base_currency BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cur_status FOREIGN KEY (currency_status_id) REFERENCES pricing.currency_status_lookup(currency_status_id),
    CONSTRAINT ck_cur_decimal CHECK (decimal_places >= 0 AND decimal_places <= 8),
    CONSTRAINT ck_cur_symbol_pos CHECK (symbol_position IN ('PREFIX', 'SUFFIX', 'PREFIX_SPACE', 'SUFFIX_SPACE'))
);

CREATE INDEX ix_cur_code ON pricing.currencies(code);
CREATE INDEX ix_cur_active ON pricing.currencies(is_active);

-- ============================================================
-- 05.3 EXCHANGE RATES
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.exchange_rates (
    exchange_rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    from_currency_id UUID NOT NULL,
    to_currency_id UUID NOT NULL,

    rate NUMERIC(19,8) NOT NULL,
    inverse_rate NUMERIC(19,8) NULL,

    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE NULL,

    source VARCHAR(50) NULL,
    is_manual BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_er_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_er_from_cur FOREIGN KEY (from_currency_id) REFERENCES pricing.currencies(currency_id),
    CONSTRAINT fk_er_to_cur FOREIGN KEY (to_currency_id) REFERENCES pricing.currencies(currency_id),
    CONSTRAINT ck_er_rate CHECK (rate > 0),
    CONSTRAINT ck_er_different CHECK (from_currency_id <> to_currency_id)
);

CREATE INDEX ix_er_from_to ON pricing.exchange_rates(from_currency_id, to_currency_id);
CREATE INDEX ix_er_effective ON pricing.exchange_rates(effective_from, effective_to);
CREATE INDEX ix_er_active ON pricing.exchange_rates(is_active);

-- ============================================================
-- 05.4 PRICE LISTS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.price_lists (
    price_list_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    currency_id UUID NOT NULL,

    price_list_code VARCHAR(50) NOT NULL,
    price_list_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    price_list_type VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    priority INTEGER NOT NULL DEFAULT 0,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    effective_from DATE NULL,
    effective_to DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pl_currency FOREIGN KEY (currency_id) REFERENCES pricing.currencies(currency_id),
    CONSTRAINT uq_price_list_code UNIQUE (company_id, price_list_code),
    CONSTRAINT ck_pl_type CHECK (price_list_type IN ('STANDARD', 'WHOLESALE', 'RETAIL', 'VIP', 'CUSTOM', 'SEASONAL'))
);

CREATE INDEX ix_pl_company ON pricing.price_lists(company_id);
CREATE INDEX ix_pl_currency ON pricing.price_lists(currency_id);
CREATE INDEX ix_pl_active ON pricing.price_lists(is_active);

-- ============================================================
-- 05.5 PRICE LIST ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.price_list_items (
    price_list_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    price_list_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,

    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    list_price NUMERIC(19,4) NULL,
    cost_price NUMERIC(19,4) NULL,
    min_quantity NUMERIC(19,4) NOT NULL DEFAULT 1,

    effective_from DATE NULL,
    effective_to DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pli_price_list FOREIGN KEY (price_list_id) REFERENCES pricing.price_lists(price_list_id) ON DELETE CASCADE,
    CONSTRAINT fk_pli_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pli_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pli_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_pli_price CHECK (unit_price >= 0),
    CONSTRAINT ck_pli_min_qty CHECK (min_quantity >= 1)
);

CREATE INDEX ix_pli_price_list ON pricing.price_list_items(price_list_id);
CREATE INDEX ix_pli_product ON pricing.price_list_items(product_id);
CREATE INDEX ix_pli_variant ON pricing.price_list_items(product_variant_id);

-- ============================================================
-- 05.6 PRODUCT PRICES
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.product_prices (
    product_price_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,
    price_list_id UUID NULL,
    currency_id UUID NOT NULL,

    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    list_price NUMERIC(19,4) NULL,
    cost_price NUMERIC(19,4) NULL,
    min_quantity NUMERIC(19,4) NOT NULL DEFAULT 1,

    effective_from DATE NULL,
    effective_to DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pp_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pp_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_pp_price_list FOREIGN KEY (price_list_id) REFERENCES pricing.price_lists(price_list_id),
    CONSTRAINT fk_pp_currency FOREIGN KEY (currency_id) REFERENCES pricing.currencies(currency_id),
    CONSTRAINT ck_pp_price CHECK (unit_price >= 0),
    CONSTRAINT ck_pp_min_qty CHECK (min_quantity >= 1)
);

CREATE INDEX ix_pp_product ON pricing.product_prices(product_id);
CREATE INDEX ix_pp_variant ON pricing.product_prices(product_variant_id);
CREATE INDEX ix_pp_price_list ON pricing.product_prices(price_list_id);
CREATE INDEX ix_pp_currency ON pricing.product_prices(currency_id);
CREATE INDEX ix_pp_active ON pricing.product_prices(is_active);

-- ============================================================
-- 05.7 PRICE CHANGE HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.price_change_history (
    price_change_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,
    price_list_id UUID NULL,
    currency_id UUID NOT NULL,

    old_price NUMERIC(19,4) NULL,
    new_price NUMERIC(19,4) NOT NULL,
    change_amount NUMERIC(19,4) NULL,
    change_percent NUMERIC(7,2) NULL,

    change_reason TEXT NULL,
    changed_by_user_id UUID NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pch_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pch_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pch_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_pch_price_list FOREIGN KEY (price_list_id) REFERENCES pricing.price_lists(price_list_id),
    CONSTRAINT fk_pch_currency FOREIGN KEY (currency_id) REFERENCES pricing.currencies(currency_id)
);

CREATE INDEX ix_pch_product ON pricing.price_change_history(product_id);
CREATE INDEX ix_pch_variant ON pricing.price_change_history(product_variant_id);
CREATE INDEX ix_pch_changed ON pricing.price_change_history(changed_at);

-- ============================================================
-- 05.8 PRICE RULES / ADJUSTMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.price_rules (
    price_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    price_list_id UUID NULL,

    rule_code VARCHAR(50) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    rule_type VARCHAR(30) NOT NULL DEFAULT 'PERCENTAGE',
    adjustment_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    applies_to VARCHAR(30) NOT NULL DEFAULT 'ALL',
    product_id UUID NULL,
    product_category_id UUID NULL,
    brand_id UUID NULL,

    min_quantity NUMERIC(19,4) NULL,
    min_order_amount NUMERIC(19,4) NULL,

    effective_from DATE NULL,
    effective_to DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pr_price_list FOREIGN KEY (price_list_id) REFERENCES pricing.price_lists(price_list_id),
    CONSTRAINT fk_pr_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pr_category FOREIGN KEY (product_category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT fk_pr_brand FOREIGN KEY (brand_id) REFERENCES catalog.brands(brand_id),
    CONSTRAINT uq_rule_code UNIQUE (company_id, rule_code),
    CONSTRAINT ck_pr_type CHECK (rule_type IN ('PERCENTAGE', 'FIXED', 'VOLUME', 'TIERED')),
    CONSTRAINT ck_pr_applies CHECK (applies_to IN ('ALL', 'PRODUCT', 'CATEGORY', 'BRAND', 'COLLECTION'))
);

CREATE INDEX ix_pr_company ON pricing.price_rules(company_id);
CREATE INDEX ix_pr_active ON pricing.price_rules(is_active);

-- ============================================================
-- 05.9 TAX CATEGORIES
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.tax_categories (
    tax_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_taxable BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_tc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_tax_category UNIQUE (company_id, code)
);

CREATE INDEX ix_tc_company ON pricing.tax_categories(company_id);
CREATE INDEX ix_tc_active ON pricing.tax_categories(is_active);

-- ============================================================
-- 05.10 TAX RATES
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.tax_rates (
    tax_rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    tax_category_id UUID NOT NULL,
    country_id UUID NULL,
    state_id UUID NULL,

    rate NUMERIC(7,4) NOT NULL DEFAULT 0,
    rate_type VARCHAR(20) NOT NULL DEFAULT 'PERCENTAGE',
    is_inclusive BOOLEAN NOT NULL DEFAULT FALSE,
    is_compound BOOLEAN NOT NULL DEFAULT FALSE,
    tax_order INTEGER NOT NULL DEFAULT 0,

    effective_from DATE NULL,
    effective_to DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_tr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_tr_category FOREIGN KEY (tax_category_id) REFERENCES pricing.tax_categories(tax_category_id),
    CONSTRAINT fk_tr_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT ck_tr_rate CHECK (rate >= 0 AND rate <= 100),
    CONSTRAINT ck_tr_type CHECK (rate_type IN ('PERCENTAGE', 'FIXED'))
);

CREATE INDEX ix_tr_company ON pricing.tax_rates(company_id);
CREATE INDEX ix_tr_category ON pricing.tax_rates(tax_category_id);
CREATE INDEX ix_tr_country ON pricing.tax_rates(country_id);
CREATE INDEX ix_tr_active ON pricing.tax_rates(is_active);

-- ============================================================
-- 05.11 TAX RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.tax_rules (
    tax_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    tax_category_id UUID NOT NULL,

    rule_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    applies_to VARCHAR(30) NOT NULL DEFAULT 'ALL',
    product_id UUID NULL,
    product_category_id UUID NULL,

    country_id UUID NULL,
    state_id UUID NULL,

    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_trule_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_trule_category FOREIGN KEY (tax_category_id) REFERENCES pricing.tax_categories(tax_category_id),
    CONSTRAINT fk_trule_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_trule_cat FOREIGN KEY (product_category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT fk_trule_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT ck_trule_applies CHECK (applies_to IN ('ALL', 'PRODUCT', 'CATEGORY'))
);

CREATE INDEX ix_trule_company ON pricing.tax_rules(company_id);
CREATE INDEX ix_trule_category ON pricing.tax_rules(tax_category_id);

-- ============================================================
-- 05.12 TAX EXEMPTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.tax_exemptions (
    tax_exemption_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    tax_category_id UUID NOT NULL,

    exemption_type VARCHAR(30) NOT NULL DEFAULT 'CUSTOMER',
    customer_id UUID NULL,
    customer_segment_id UUID NULL,

    exemption_reason TEXT NULL,
    exemption_certificate_number VARCHAR(100) NULL,

    effective_from DATE NULL,
    effective_to DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_te_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_te_category FOREIGN KEY (tax_category_id) REFERENCES pricing.tax_categories(tax_category_id),
    CONSTRAINT fk_te_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT ck_te_type CHECK (exemption_type IN ('CUSTOMER', 'SEGMENT', 'PRODUCT', 'CATEGORY'))
);

CREATE INDEX ix_te_company ON pricing.tax_exemptions(company_id);
CREATE INDEX ix_te_customer ON pricing.tax_exemptions(customer_id);

-- ============================================================
-- 05.13 PROMOTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.promotions (
    promotion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    promotion_status_id UUID NULL,

    promotion_code VARCHAR(50) NOT NULL,
    promotion_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    promotion_type VARCHAR(30) NOT NULL DEFAULT 'DISCOUNT',
    discount_type VARCHAR(20) NOT NULL DEFAULT 'PERCENTAGE',
    discount_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    applies_to VARCHAR(30) NOT NULL DEFAULT 'ORDER',
    product_id UUID NULL,
    product_category_id UUID NULL,
    brand_id UUID NULL,

    min_order_amount NUMERIC(19,4) NULL,
    min_quantity NUMERIC(19,4) NULL,
    max_discount_amount NUMERIC(19,4) NULL,

    usage_limit INTEGER NULL,
    usage_count INTEGER NOT NULL DEFAULT 0,
    usage_limit_per_customer INTEGER NULL,

    start_date TIMESTAMPTZ NULL,
    end_date TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_stackable BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_promo_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_promo_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_promo_category FOREIGN KEY (product_category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT fk_promo_brand FOREIGN KEY (brand_id) REFERENCES catalog.brands(brand_id),
    CONSTRAINT uq_promotion_code UNIQUE (company_id, promotion_code),
    CONSTRAINT ck_promo_type CHECK (promotion_type IN ('DISCOUNT', 'BOGO', 'FREE_SHIPPING', 'BUNDLE', 'GIFT')),
    CONSTRAINT ck_promo_discount_type CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'FREE')),
    CONSTRAINT ck_promo_discount CHECK (discount_value >= 0),
    CONSTRAINT ck_promo_applies CHECK (applies_to IN ('ORDER', 'PRODUCT', 'CATEGORY', 'BRAND', 'COLLECTION'))
);

CREATE INDEX ix_promo_company ON pricing.promotions(company_id);
CREATE INDEX ix_promo_active ON pricing.promotions(is_active);
CREATE INDEX ix_promo_dates ON pricing.promotions(start_date, end_date);

-- ============================================================
-- 05.14 COUPONS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.coupons (
    coupon_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    promotion_id UUID NULL,

    coupon_code VARCHAR(100) NOT NULL,
    description TEXT NULL,

    coupon_type VARCHAR(20) NOT NULL DEFAULT 'SINGLE_USE',
    discount_type VARCHAR(20) NOT NULL DEFAULT 'PERCENTAGE',
    discount_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    min_order_amount NUMERIC(19,4) NULL,
    max_discount_amount NUMERIC(19,4) NULL,

    usage_limit INTEGER NULL,
    usage_count INTEGER NOT NULL DEFAULT 0,
    usage_limit_per_customer INTEGER NULL,

    start_date TIMESTAMPTZ NULL,
    end_date TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_coupon_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_coupon_promotion FOREIGN KEY (promotion_id) REFERENCES pricing.promotions(promotion_id),
    CONSTRAINT uq_coupon_code UNIQUE (company_id, coupon_code),
    CONSTRAINT ck_coupon_type CHECK (coupon_type IN ('SINGLE_USE', 'MULTI_USE', 'UNLIMITED')),
    CONSTRAINT ck_coupon_discount_type CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'FREE_SHIPPING')),
    CONSTRAINT ck_coupon_discount CHECK (discount_value >= 0)
);

CREATE INDEX ix_coupon_company ON pricing.coupons(company_id);
CREATE INDEX ix_coupon_code ON pricing.coupons(coupon_code);
CREATE INDEX ix_coupon_active ON pricing.coupons(is_active);

-- ============================================================
-- 05.15 COUPON USAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.coupon_usages (
    coupon_usage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coupon_id UUID NOT NULL,
    company_id UUID NOT NULL,
    order_id UUID NULL,
    customer_id UUID NULL,

    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    used_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cu_coupon FOREIGN KEY (coupon_id) REFERENCES pricing.coupons(coupon_id),
    CONSTRAINT fk_cu_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cu_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_cu_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_cu_currency FOREIGN KEY (currency_id) REFERENCES pricing.currencies(currency_id),
    CONSTRAINT ck_cu_discount CHECK (discount_amount >= 0)
);

CREATE INDEX ix_cu_coupon ON pricing.coupon_usages(coupon_id);
CREATE INDEX ix_cu_order ON pricing.coupon_usages(order_id);
CREATE INDEX ix_cu_customer ON pricing.coupon_usages(customer_id);

-- ============================================================
-- 05.16 SALES CHANNELS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.sales_channels (
    sales_channel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    channel_code VARCHAR(50) NOT NULL,
    channel_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    channel_type VARCHAR(30) NOT NULL DEFAULT 'ONLINE',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_sc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_channel_code UNIQUE (company_id, channel_code),
    CONSTRAINT ck_sc_type CHECK (channel_type IN ('ONLINE', 'OFFLINE', 'POS', 'MOBILE', 'B2B', 'MARKETPLACE'))
);

CREATE INDEX ix_sc_company ON pricing.sales_channels(company_id);
CREATE INDEX ix_sc_active ON pricing.sales_channels(is_active);

-- ============================================================
-- 05.17 CUSTOMER SEGMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.customer_segments (
    customer_segment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    segment_code VARCHAR(50) NOT NULL,
    segment_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    segment_type VARCHAR(30) NOT NULL DEFAULT 'MANUAL',
    filter_criteria JSONB NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cseg_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_segment_code UNIQUE (company_id, segment_code),
    CONSTRAINT ck_cseg_type CHECK (segment_type IN ('MANUAL', 'DYNAMIC', 'RFM', 'PURCHASE_BEHAVIOR'))
);

CREATE INDEX ix_cseg_company ON pricing.customer_segments(company_id);
CREATE INDEX ix_cseg_active ON pricing.customer_segments(is_active);

-- ============================================================
-- 05.18 CUSTOMER SEGMENT MEMBERS
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.customer_segment_members (
    customer_segment_member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_segment_id UUID NOT NULL,
    customer_id UUID NOT NULL,

    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    added_by_user_id UUID NULL,
    removed_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_csm_segment FOREIGN KEY (customer_segment_id) REFERENCES pricing.customer_segments(customer_segment_id) ON DELETE CASCADE,
    CONSTRAINT fk_csm_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT uq_segment_customer UNIQUE (customer_segment_id, customer_id)
);

CREATE INDEX ix_csm_segment ON pricing.customer_segment_members(customer_segment_id);
CREATE INDEX ix_csm_customer ON pricing.customer_segment_members(customer_id);

-- ============================================================
-- 05.19 PRICING JOURNAL ENTRIES (Accounting Integration)
-- ============================================================

CREATE TABLE IF NOT EXISTS pricing.pricing_journal_entries (
    pricing_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    order_id UUID NULL,
    journal_entry_id UUID NULL,

    posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
    debit_account_id UUID NULL,
    credit_account_id UUID NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pje_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pje_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_pje_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_pje_currency FOREIGN KEY (currency_id) REFERENCES pricing.currencies(currency_id)
);

CREATE INDEX ix_pje_order ON pricing.pricing_journal_entries(order_id);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_pkr_id UUID;
    v_usd_id UUID;
    v_eur_id UUID;
    v_gbp_id UUID;
    v_aed_id UUID;
    v_sar_id UUID;
    v_standard_tax_cat UUID;
    v_reduced_tax_cat UUID;
    v_exempt_tax_cat UUID;
    v_standard_pl UUID;
    v_retail_channel UUID;
    v_online_channel UUID;
    v_pos_channel UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Seed Currencies
    INSERT INTO pricing.currencies (code, name, symbol, symbol_position, decimal_places, iso_code, is_base_currency) VALUES
        ('PKR', 'Pakistani Rupee', 'Rs.', 'PREFIX', 2, '586', TRUE),
        ('USD', 'US Dollar', '$', 'PREFIX', 2, '840', FALSE),
        ('EUR', 'Euro', '€', 'PREFIX', 2, '978', FALSE),
        ('GBP', 'British Pound', '£', 'PREFIX', 2, '826', FALSE),
        ('AED', 'UAE Dirham', 'د.إ', 'SUFFIX', 2, '784', FALSE),
        ('SAR', 'Saudi Riyal', '﷼', 'SUFFIX', 2, '682', FALSE)
    ON CONFLICT (code) DO NOTHING;

    SELECT currency_id INTO v_pkr_id FROM pricing.currencies WHERE code = 'PKR';
    SELECT currency_id INTO v_usd_id FROM pricing.currencies WHERE code = 'USD';
    SELECT currency_id INTO v_eur_id FROM pricing.currencies WHERE code = 'EUR';
    SELECT currency_id INTO v_gbp_id FROM pricing.currencies WHERE code = 'GBP';
    SELECT currency_id INTO v_aed_id FROM pricing.currencies WHERE code = 'AED';
    SELECT currency_id INTO v_sar_id FROM pricing.currencies WHERE code = 'SAR';

    -- Seed Exchange Rates (PKR base)
    INSERT INTO pricing.exchange_rates (company_id, from_currency_id, to_currency_id, rate, effective_from, source, is_manual)
    SELECT v_company_id, v_pkr_id, v_usd_id, 0.0036, CURRENT_DATE, 'MANUAL', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.exchange_rates WHERE company_id = v_company_id AND from_currency_id = v_pkr_id AND to_currency_id = v_usd_id);

    INSERT INTO pricing.exchange_rates (company_id, from_currency_id, to_currency_id, rate, effective_from, source, is_manual)
    SELECT v_company_id, v_pkr_id, v_aed_id, 0.0132, CURRENT_DATE, 'MANUAL', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.exchange_rates WHERE company_id = v_company_id AND from_currency_id = v_pkr_id AND to_currency_id = v_aed_id);

    INSERT INTO pricing.exchange_rates (company_id, from_currency_id, to_currency_id, rate, effective_from, source, is_manual)
    SELECT v_company_id, v_pkr_id, v_gbp_id, 0.0028, CURRENT_DATE, 'MANUAL', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.exchange_rates WHERE company_id = v_company_id AND from_currency_id = v_pkr_id AND to_currency_id = v_gbp_id);

    INSERT INTO pricing.exchange_rates (company_id, from_currency_id, to_currency_id, rate, effective_from, source, is_manual)
    SELECT v_company_id, v_usd_id, v_pkr_id, 277.78, CURRENT_DATE, 'MANUAL', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.exchange_rates WHERE company_id = v_company_id AND from_currency_id = v_usd_id AND to_currency_id = v_pkr_id);

    -- Seed Price Lists
    INSERT INTO pricing.price_lists (company_id, currency_id, price_list_code, price_list_name, description, price_list_type, is_default, is_active)
    SELECT v_company_id, v_pkr_id, 'STANDARD-PKR', 'Standard PKR Price List', 'Default price list in PKR.', 'STANDARD', TRUE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.price_lists WHERE company_id = v_company_id AND price_list_code = 'STANDARD-PKR')
    RETURNING price_list_id INTO v_standard_pl;

    INSERT INTO pricing.price_lists (company_id, currency_id, price_list_code, price_list_name, description, price_list_type, is_default, is_active)
    SELECT v_company_id, v_usd_id, 'STANDARD-USD', 'Standard USD Price List', 'Default price list in USD.', 'STANDARD', FALSE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.price_lists WHERE company_id = v_company_id AND price_list_code = 'STANDARD-USD');

    INSERT INTO pricing.price_lists (company_id, currency_id, price_list_code, price_list_name, description, price_list_type, is_default, is_active)
    SELECT v_company_id, v_pkr_id, 'WHOLESALE-PKR', 'Wholesale PKR Price List', 'Wholesale price list in PKR.', 'WHOLESALE', FALSE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.price_lists WHERE company_id = v_company_id AND price_list_code = 'WHOLESALE-PKR');

    INSERT INTO pricing.price_lists (company_id, currency_id, price_list_code, price_list_name, description, price_list_type, is_default, is_active)
    SELECT v_company_id, v_pkr_id, 'VIP-PKR', 'VIP PKR Price List', 'VIP customer price list in PKR.', 'VIP', FALSE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.price_lists WHERE company_id = v_company_id AND price_list_code = 'VIP-PKR');

    -- Seed Tax Categories
    INSERT INTO pricing.tax_categories (company_id, code, name, description, is_taxable) VALUES
        (v_company_id, 'STANDARD', 'Standard Tax', 'Standard tax rate.', TRUE),
        (v_company_id, 'REDUCED', 'Reduced Tax', 'Reduced tax rate.', TRUE),
        (v_company_id, 'EXEMPT', 'Tax Exempt', 'Tax exempt items.', FALSE),
        (v_company_id, 'ZERO', 'Zero Rated', 'Zero rated items.', TRUE)
    ON CONFLICT (company_id, code) DO NOTHING;

    SELECT tax_category_id INTO v_standard_tax_cat FROM pricing.tax_categories WHERE company_id = v_company_id AND code = 'STANDARD';
    SELECT tax_category_id INTO v_reduced_tax_cat FROM pricing.tax_categories WHERE company_id = v_company_id AND code = 'REDUCED';
    SELECT tax_category_id INTO v_exempt_tax_cat FROM pricing.tax_categories WHERE company_id = v_company_id AND code = 'EXEMPT';

    -- Seed Tax Rates
    INSERT INTO pricing.tax_rates (company_id, tax_category_id, rate, rate_type, is_inclusive, effective_from, is_active)
    SELECT v_company_id, v_standard_tax_cat, 18.0, 'PERCENTAGE', FALSE, CURRENT_DATE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.tax_rates WHERE company_id = v_company_id AND tax_category_id = v_standard_tax_cat);

    INSERT INTO pricing.tax_rates (company_id, tax_category_id, rate, rate_type, is_inclusive, effective_from, is_active)
    SELECT v_company_id, v_reduced_tax_cat, 5.0, 'PERCENTAGE', FALSE, CURRENT_DATE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.tax_rates WHERE company_id = v_company_id AND tax_category_id = v_reduced_tax_cat);

    INSERT INTO pricing.tax_rates (company_id, tax_category_id, rate, rate_type, is_inclusive, effective_from, is_active)
    SELECT v_company_id, v_exempt_tax_cat, 0.0, 'PERCENTAGE', FALSE, CURRENT_DATE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.tax_rates WHERE company_id = v_company_id AND tax_category_id = v_exempt_tax_cat);

    -- Seed Sales Channels
    INSERT INTO pricing.sales_channels (company_id, channel_code, channel_name, description, channel_type) VALUES
        (v_company_id, 'WEBSITE', 'Website', 'Online website sales.', 'ONLINE'),
        (v_company_id, 'POS', 'Point of Sale', 'Point of sale sales.', 'POS'),
        (v_company_id, 'MOBILE_APP', 'Mobile App', 'Mobile app sales.', 'MOBILE'),
        (v_company_id, 'B2B_PORTAL', 'B2B Portal', 'B2B portal sales.', 'B2B'),
        (v_company_id, 'MARKETPLACE', 'Marketplace', 'Marketplace sales.', 'MARKETPLACE')
    ON CONFLICT (company_id, channel_code) DO NOTHING;

    -- Seed Customer Segments
    INSERT INTO pricing.customer_segments (company_id, segment_code, segment_name, description, segment_type) VALUES
        (v_company_id, 'VIP', 'VIP Customers', 'VIP customer segment.', 'MANUAL'),
        (v_company_id, 'WHOLESALE', 'Wholesale Customers', 'Wholesale customer segment.', 'MANUAL'),
        (v_company_id, 'NEW', 'New Customers', 'New customer segment.', 'MANUAL'),
        (v_company_id, 'INACTIVE', 'Inactive Customers', 'Inactive customer segment.', 'MANUAL')
    ON CONFLICT (company_id, segment_code) DO NOTHING;

    -- Seed Promotions
    INSERT INTO pricing.promotions (company_id, promotion_code, promotion_name, description, promotion_type, discount_type, discount_value, min_order_amount, start_date, end_date, is_active)
    SELECT v_company_id, 'WELCOME10', 'Welcome 10% Off', '10% off for new customers.', 'DISCOUNT', 'PERCENTAGE', 10.0, 1000.00,
           CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '90 days', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.promotions WHERE company_id = v_company_id AND promotion_code = 'WELCOME10');

    INSERT INTO pricing.promotions (company_id, promotion_code, promotion_name, description, promotion_type, discount_type, discount_value, min_order_amount, start_date, end_date, is_active)
    SELECT v_company_id, 'FREESHIP', 'Free Shipping', 'Free shipping on orders above Rs. 5000.', 'FREE_SHIPPING', 'FREE', 0, 5000.00,
           CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '180 days', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.promotions WHERE company_id = v_company_id AND promotion_code = 'FREESHIP');

    -- Seed Coupons
    INSERT INTO pricing.coupons (company_id, promotion_id, coupon_code, description, coupon_type, discount_type, discount_value, min_order_amount, usage_limit, start_date, end_date, is_active)
    SELECT v_company_id,
           (SELECT promotion_id FROM pricing.promotions WHERE company_id = v_company_id AND promotion_code = 'WELCOME10'),
           'WELCOME10', '10% off for new customers.', 'MULTI_USE', 'PERCENTAGE', 10.0, 1000.00, 1000,
           CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '90 days', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.coupons WHERE company_id = v_company_id AND coupon_code = 'WELCOME10');

    INSERT INTO pricing.coupons (company_id, coupon_code, description, coupon_type, discount_type, discount_value, min_order_amount, usage_limit, start_date, end_date, is_active)
    SELECT v_company_id, 'SAVE500', 'Save Rs. 500 on orders above Rs. 3000.', 'MULTI_USE', 'FIXED', 500.00, 3000.00, 500,
           CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '60 days', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM pricing.coupons WHERE company_id = v_company_id AND coupon_code = 'SAVE500');

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 05 Pricing, Currency, Tax & Promotions
-- 19 Tables + 1 Lookup Table + Seed Data
-- ============================================================