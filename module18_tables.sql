BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 18 — LOYALTY, REWARDS & CUSTOMER RETENTION
-- DATABASE TABLES
-- ============================================================
-- Components:
--   18.1  Loyalty Programs
--   18.2  Loyalty Tiers / Levels
--   18.3  Points Earning Rules
--   18.4  Points Transactions
--   18.5  Customer Points Balances
--   18.6  Rewards Catalog
--   18.7  Reward Redemptions
--   18.8  Vouchers & Voucher Codes
--   18.9  Cashback Rules & Transactions
--   18.10 Referral Programs & Rewards
--   18.11 Purchase-Based Rewards
--   18.12 Birthday & Anniversary Rewards
--   18.13 Loyalty Campaigns
--   18.14 Points Expiration & Recovery
-- ============================================================

CREATE SCHEMA IF NOT EXISTS loyalty;

-- ============================================================
-- 18.1 LOYALTY LOOKUPS
-- ============================================================

-- Loyalty Program Status
CREATE TABLE IF NOT EXISTS loyalty.loyalty_program_status_lookup (
    loyalty_program_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO loyalty.loyalty_program_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Program is being configured.', 10),
    ('ACTIVE', 'Active', 'Program is live and accepting members.', 20),
    ('PAUSED', 'Paused', 'Program temporarily paused.', 30),
    ('ARCHIVED', 'Archived', 'Program ended and archived.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Points Transaction Type
CREATE TABLE IF NOT EXISTS loyalty.points_transaction_type_lookup (
    points_transaction_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    affects_balance BOOLEAN NOT NULL DEFAULT TRUE,
    is_positive BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO loyalty.points_transaction_type_lookup (code, name, description, affects_balance, is_positive, sort_order) VALUES
    ('PURCHASE_EARN', 'Purchase Earn', 'Points earned from purchase.', TRUE, TRUE, 10),
    ('PROMOTION_BONUS', 'Promotion Bonus', 'Bonus points from promotion.', TRUE, TRUE, 20),
    ('REFERRAL_REWARD', 'Referral Reward', 'Points earned from referral.', TRUE, TRUE, 30),
    ('BIRTHDAY_BONUS', 'Birthday Bonus', 'Birthday bonus points.', TRUE, TRUE, 40),
    ('ANNIVERSARY_BONUS', 'Anniversary Bonus', 'Registration anniversary bonus.', TRUE, TRUE, 50),
    ('SIGNUP_BONUS', 'Signup Bonus', 'Welcome bonus for new members.', TRUE, TRUE, 60),
    ('MANUAL_CREDIT', 'Manual Credit', 'Manual points credit by admin.', TRUE, TRUE, 70),
    ('REDEMPTION', 'Redemption', 'Points spent on reward.', TRUE, FALSE, 80),
    ('RETURN_REVERSAL', 'Return Reversal', 'Points reversed due to return.', TRUE, FALSE, 90),
    ('EXPIRATION', 'Expiration', 'Points expired.', TRUE, FALSE, 100),
    ('ADJUSTMENT', 'Adjustment', 'Manual adjustment.', TRUE, TRUE, 110),
    ('FRAUD_REVERSAL', 'Fraud Reversal', 'Points reversed due to fraud.', TRUE, FALSE, 120)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, affects_balance = EXCLUDED.affects_balance, is_positive = EXCLUDED.is_positive, sort_order = EXCLUDED.sort_order;

-- Reward Type
CREATE TABLE IF NOT EXISTS loyalty.reward_type_lookup (
    reward_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO loyalty.reward_type_lookup (code, name, description, sort_order) VALUES
    ('DISCOUNT_VOUCHER', 'Discount Voucher', 'Percentage or fixed discount voucher.', 10),
    ('FREE_SHIPPING', 'Free Shipping', 'Free shipping voucher.', 20),
    ('FREE_PRODUCT', 'Free Product', 'Free product reward.', 30),
    ('CASHBACK', 'Cashback', 'Cash or store credit.', 40),
    ('GIFT_CARD', 'Gift Card', 'Gift card with value.', 50),
    ('EXPERIENCE', 'Experience', 'VIP experience or event.', 60),
    ('CHARITY_DONATION', 'Charity Donation', 'Donate points to charity.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Voucher Status
CREATE TABLE IF NOT EXISTS loyalty.voucher_status_lookup (
    voucher_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO loyalty.voucher_status_lookup (code, name, description, sort_order) VALUES
    ('ISSUED', 'Issued', 'Voucher issued to customer.', 10),
    ('ACTIVE', 'Active', 'Voucher is active and usable.', 20),
    ('REDEEMED', 'Redeemed', 'Voucher has been redeemed.', 30),
    ('EXPIRED', 'Expired', 'Voucher has expired.', 40),
    ('CANCELLED', 'Cancelled', 'Voucher was cancelled.', 50),
    ('FRAUD', 'Fraud', 'Voucher flagged as fraud.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Redemption Status
CREATE TABLE IF NOT EXISTS loyalty.redemption_status_lookup (
    redemption_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO loyalty.redemption_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Redemption is pending.', 10),
    ('APPROVED', 'Approved', 'Redemption approved.', 20),
    ('FULFILLED', 'Fulfilled', 'Reward delivered.', 30),
    ('REJECTED', 'Rejected', 'Redemption rejected.', 40),
    ('CANCELLED', 'Cancelled', 'Redemption cancelled.', 50),
    ('REVERSED', 'Reversed', 'Redemption reversed.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Cashback Type
CREATE TABLE IF NOT EXISTS loyalty.cashback_type_lookup (
    cashback_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO loyalty.cashback_type_lookup (code, name, description, sort_order) VALUES
    ('PERCENTAGE', 'Percentage', 'Percentage of order value.', 10),
    ('FIXED', 'Fixed Amount', 'Fixed cashback amount.', 20),
    ('TIERED', 'Tiered', 'Tiered based on order value.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- ============================================================
-- 18.1 LOYALTY PROGRAMS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.loyalty_programs (
    loyalty_program_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_status_id UUID NOT NULL DEFAULT (SELECT loyalty_program_status_id FROM loyalty.loyalty_program_status_lookup WHERE code = 'DRAFT'),

    program_code VARCHAR(50) NOT NULL,
    program_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    
    points_currency_name VARCHAR(50) NOT NULL DEFAULT 'Points',
    points_currency_symbol VARCHAR(10) NULL,
    
    signup_bonus_points INTEGER NOT NULL DEFAULT 0,
    points_per_currency_unit NUMERIC(10,4) NOT NULL DEFAULT 1.0,
    currency_unit_per_point NUMERIC(10,4) NOT NULL DEFAULT 1.0,
    
    points_expiry_days INTEGER NULL,
    tier_requalification_period_days INTEGER NULL,
    
    allows_partial_redemption BOOLEAN NOT NULL DEFAULT TRUE,
    minimum_redemption_points INTEGER NOT NULL DEFAULT 0,
    maximum_points_balance INTEGER NULL,
    
    allows_points_and_discount BOOLEAN NOT NULL DEFAULT TRUE,
    allows_cashback_and_points BOOLEAN NOT NULL DEFAULT TRUE,
    
    terms_and_conditions TEXT NULL,
    start_date DATE NULL,
    end_date DATE NULL,
    
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    auto_enroll_customers BOOLEAN NOT NULL DEFAULT FALSE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_lp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_lp_status FOREIGN KEY (loyalty_program_status_id) REFERENCES loyalty.loyalty_program_status_lookup(loyalty_program_status_id),
    CONSTRAINT uq_program_code UNIQUE (company_id, program_code),
    CONSTRAINT ck_lp_points CHECK (points_per_currency_unit >= 0 AND currency_unit_per_point >= 0),
    CONSTRAINT ck_lp_expiry CHECK (points_expiry_days IS NULL OR points_expiry_days > 0)
);

CREATE INDEX ix_lp_company ON loyalty.loyalty_programs(company_id);
CREATE INDEX ix_lp_status ON loyalty.loyalty_programs(loyalty_program_status_id);

-- ============================================================
-- 18.2 LOYALTY TIERS / LEVELS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.loyalty_tiers (
    loyalty_tier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loyalty_program_id UUID NOT NULL,
    
    tier_code VARCHAR(50) NOT NULL,
    tier_name VARCHAR(150) NOT NULL,
    tier_level INTEGER NOT NULL DEFAULT 0,
    description TEXT NULL,
    
    minimum_points INTEGER NOT NULL DEFAULT 0,
    minimum_spend NUMERIC(19,4) NULL,
    minimum_orders INTEGER NULL,
    
    points_multiplier NUMERIC(5,2) NOT NULL DEFAULT 1.0,
    cashback_multiplier NUMERIC(5,2) NOT NULL DEFAULT 1.0,
    
    tier_benefits JSONB NULL,
    tier_image_url VARCHAR(500) NULL,
    tier_color VARCHAR(20) NULL,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_lt_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id) ON DELETE CASCADE,
    CONSTRAINT uq_tier_code UNIQUE (loyalty_program_id, tier_code),
    CONSTRAINT ck_lt_level CHECK (tier_level >= 0),
    CONSTRAINT ck_lt_points CHECK (minimum_points >= 0),
    CONSTRAINT ck_lt_multiplier CHECK (points_multiplier >= 0 AND cashback_multiplier >= 0)
);

CREATE INDEX ix_lt_program ON loyalty.loyalty_tiers(loyalty_program_id);

-- ============================================================
-- 18.3 POINTS EARNING RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.points_earning_rules (
    points_earning_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_id UUID NOT NULL,
    loyalty_tier_id UUID NULL,
    product_category_id UUID NULL,
    product_id UUID NULL,
    sales_channel_id UUID NULL,
    
    rule_name VARCHAR(200) NOT NULL,
    rule_type VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    
    points_per_currency_unit NUMERIC(10,4) NULL,
    fixed_points_per_order INTEGER NULL,
    bonus_points INTEGER NULL,
    bonus_percentage NUMERIC(5,2) NULL,
    
    minimum_order_amount NUMERIC(19,4) NULL,
    maximum_points_per_order INTEGER NULL,
    
    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    start_date DATE NULL,
    end_date DATE NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_per_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_per_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id) ON DELETE CASCADE,
    CONSTRAINT fk_per_tier FOREIGN KEY (loyalty_tier_id) REFERENCES loyalty.loyalty_tiers(loyalty_tier_id),
    CONSTRAINT ck_per_type CHECK (rule_type IN ('STANDARD', 'BONUS', 'PROMOTIONAL', 'CATEGORY', 'PRODUCT', 'CHANNEL', 'TIER')),
    CONSTRAINT ck_per_points CHECK (points_per_currency_unit IS NULL OR points_per_currency_unit >= 0)
);

CREATE INDEX ix_per_program ON loyalty.points_earning_rules(loyalty_program_id);
CREATE INDEX ix_per_active ON loyalty.points_earning_rules(is_active, start_date, end_date);

-- ============================================================
-- 18.4 CUSTOMER LOYALTY MEMBERSHIP
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.customer_loyalty_memberships (
    customer_loyalty_membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    loyalty_program_id UUID NOT NULL,
    current_tier_id UUID NULL,
    
    membership_number VARCHAR(50) NOT NULL,
    membership_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    
    total_points_earned BIGINT NOT NULL DEFAULT 0,
    total_points_redeemed BIGINT NOT NULL DEFAULT 0,
    total_points_expired BIGINT NOT NULL DEFAULT 0,
    total_points_adjusted BIGINT NOT NULL DEFAULT 0,
    current_points_balance BIGINT NOT NULL DEFAULT 0,
    pending_points BIGINT NOT NULL DEFAULT 0,
    
    lifetime_spend NUMERIC(19,4) NOT NULL DEFAULT 0,
    lifetime_orders INTEGER NOT NULL DEFAULT 0,
    
    current_tier_qualified_at TIMESTAMPTZ NULL,
    tier_requalification_date DATE NULL,
    previous_tier_id UUID NULL,
    
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMPTZ NULL,
    last_points_earned_at TIMESTAMPTZ NULL,
    last_redemption_at TIMESTAMPTZ NULL,
    
    is_opted_out BOOLEAN NOT NULL DEFAULT FALSE,
    opted_out_at TIMESTAMPTZ NULL,
    
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_clm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_clm_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_clm_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT fk_clm_tier FOREIGN KEY (current_tier_id) REFERENCES loyalty.loyalty_tiers(loyalty_tier_id),
    CONSTRAINT uq_membership UNIQUE (company_id, customer_id, loyalty_program_id),
    CONSTRAINT uq_membership_number UNIQUE (company_id, membership_number),
    CONSTRAINT ck_clm_status CHECK (membership_status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED', 'TERMINATED')),
    CONSTRAINT ck_clm_balance CHECK (current_points_balance >= 0)
);

CREATE INDEX ix_clm_customer ON loyalty.customer_loyalty_memberships(customer_id);
CREATE INDEX ix_clm_program ON loyalty.customer_loyalty_memberships(loyalty_program_id);
CREATE INDEX ix_clm_tier ON loyalty.customer_loyalty_memberships(current_tier_id);

-- ============================================================
-- 18.4 POINTS TRANSACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.points_transactions (
    points_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_loyalty_membership_id UUID NOT NULL,
    points_transaction_type_id UUID NOT NULL,
    order_id UUID NULL,
    return_request_id UUID NULL,
    reward_id UUID NULL,
    voucher_id UUID NULL,
    referral_id UUID NULL,
    
    transaction_number VARCHAR(50) NOT NULL,
    points_amount BIGINT NOT NULL,
    points_balance_before BIGINT NOT NULL,
    points_balance_after BIGINT NOT NULL,
    
    currency_amount NUMERIC(19,4) NULL,
    currency_id UUID NULL,
    exchange_rate NUMERIC(10,4) NULL,
    
    description TEXT NULL,
    reference_type VARCHAR(50) NULL,
    reference_id UUID NULL,
    
    expires_at TIMESTAMPTZ NULL,
    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    expired_at TIMESTAMPTZ NULL,
    
    is_pending BOOLEAN NOT NULL DEFAULT FALSE,
    pending_until TIMESTAMPTZ NULL,
    confirmed_at TIMESTAMPTZ NULL,
    
    is_reversed BOOLEAN NOT NULL DEFAULT FALSE,
    reversed_at TIMESTAMPTZ NULL,
    reversal_reason TEXT NULL,
    reversed_by_user_id UUID NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_pt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pt_membership FOREIGN KEY (customer_loyalty_membership_id) REFERENCES loyalty.customer_loyalty_memberships(customer_loyalty_membership_id),
    CONSTRAINT fk_pt_type FOREIGN KEY (points_transaction_type_id) REFERENCES loyalty.points_transaction_type_lookup(points_transaction_type_id),
    CONSTRAINT fk_pt_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_pt_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id),
    CONSTRAINT fk_pt_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_transaction_number UNIQUE (company_id, transaction_number),
    CONSTRAINT ck_pt_amount CHECK (points_amount <> 0),
    CONSTRAINT ck_pt_balance CHECK (points_balance_after >= 0)
);

CREATE INDEX ix_pt_membership ON loyalty.points_transactions(customer_loyalty_membership_id);
CREATE INDEX ix_pt_type ON loyalty.points_transactions(points_transaction_type_id);
CREATE INDEX ix_pt_order ON loyalty.points_transactions(order_id);
CREATE INDEX ix_pt_expires ON loyalty.points_transactions(expires_at) WHERE is_expired = FALSE;
CREATE INDEX ix_pt_created ON loyalty.points_transactions(created_at DESC);

-- ============================================================
-- 18.5 POINTS BALANCE BUCKETS (for expiration tracking)
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.points_balance_buckets (
    points_balance_bucket_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_loyalty_membership_id UUID NOT NULL,
    
    points_earned BIGINT NOT NULL,
    points_remaining BIGINT NOT NULL,
    points_used BIGINT NOT NULL DEFAULT 0,
    points_expired BIGINT NOT NULL DEFAULT 0,
    
    earned_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    
    source_transaction_id UUID NULL,
    source_type VARCHAR(50) NULL,
    source_reference VARCHAR(200) NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pbb_membership FOREIGN KEY (customer_loyalty_membership_id) REFERENCES loyalty.customer_loyalty_memberships(customer_loyalty_membership_id) ON DELETE CASCADE,
    CONSTRAINT fk_pbb_transaction FOREIGN KEY (source_transaction_id) REFERENCES loyalty.points_transactions(points_transaction_id),
    CONSTRAINT ck_pbb_remaining CHECK (points_remaining >= 0)
);

CREATE INDEX ix_pbb_membership ON loyalty.points_balance_buckets(customer_loyalty_membership_id);
CREATE INDEX ix_pbb_expires ON loyalty.points_balance_buckets(expires_at) WHERE is_expired = FALSE;

-- ============================================================
-- 18.6 REWARDS CATALOG
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.rewards (
    reward_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_id UUID NOT NULL,
    reward_type_id UUID NOT NULL,
    product_id UUID NULL,
    product_variant_id UUID NULL,
    
    reward_code VARCHAR(50) NOT NULL,
    reward_name VARCHAR(300) NOT NULL,
    description TEXT NULL,
    short_description VARCHAR(500) NULL,
    
    points_cost INTEGER NOT NULL,
    cash_value NUMERIC(19,4) NULL,
    discount_percentage NUMERIC(5,2) NULL,
    discount_amount NUMERIC(19,4) NULL,
    
    minimum_tier_id UUID NULL,
    allowed_tier_ids UUID[] NULL,
    
    total_quantity INTEGER NULL,
    remaining_quantity INTEGER NULL,
    max_per_customer INTEGER NULL,
    
    image_url VARCHAR(500) NULL,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    
    start_date DATE NULL,
    end_date DATE NULL,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_r_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_r_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT fk_r_type FOREIGN KEY (reward_type_id) REFERENCES loyalty.reward_type_lookup(reward_type_id),
    CONSTRAINT fk_r_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_r_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT uq_reward_code UNIQUE (company_id, reward_code),
    CONSTRAINT ck_r_points CHECK (points_cost > 0),
    CONSTRAINT ck_r_quantity CHECK (total_quantity IS NULL OR remaining_quantity <= total_quantity)
);

CREATE INDEX ix_r_program ON loyalty.rewards(loyalty_program_id);
CREATE INDEX ix_r_type ON loyalty.rewards(reward_type_id);
CREATE INDEX ix_r_active ON loyalty.rewards(is_active, start_date, end_date);

-- ============================================================
-- 18.7 REWARD REDEMPTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.reward_redemptions (
    reward_redemption_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_loyalty_membership_id UUID NOT NULL,
    reward_id UUID NOT NULL,
    redemption_status_id UUID NOT NULL DEFAULT (SELECT redemption_status_id FROM loyalty.redemption_status_lookup WHERE code = 'PENDING'),
    points_transaction_id UUID NULL,
    voucher_id UUID NULL,
    order_id UUID NULL,
    
    redemption_number VARCHAR(50) NOT NULL,
    points_spent INTEGER NOT NULL,
    cash_value NUMERIC(19,4) NULL,
    
    status_history JSONB NULL,
    notes TEXT NULL,
    
    requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMPTZ NULL,
    approved_by_user_id UUID NULL,
    fulfilled_at TIMESTAMPTZ NULL,
    rejected_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,
    
    is_reversed BOOLEAN NOT NULL DEFAULT FALSE,
    reversed_at TIMESTAMPTZ NULL,
    reversal_reason TEXT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_rr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rr_membership FOREIGN KEY (customer_loyalty_membership_id) REFERENCES loyalty.customer_loyalty_memberships(customer_loyalty_membership_id),
    CONSTRAINT fk_rr_reward FOREIGN KEY (reward_id) REFERENCES loyalty.rewards(reward_id),
    CONSTRAINT fk_rr_status FOREIGN KEY (redemption_status_id) REFERENCES loyalty.redemption_status_lookup(redemption_status_id),
    CONSTRAINT fk_rr_transaction FOREIGN KEY (points_transaction_id) REFERENCES loyalty.points_transactions(points_transaction_id),
    CONSTRAINT fk_rr_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT uq_redemption_number UNIQUE (company_id, redemption_number),
    CONSTRAINT ck_rr_points CHECK (points_spent > 0)
);

CREATE INDEX ix_rr_membership ON loyalty.reward_redemptions(customer_loyalty_membership_id);
CREATE INDEX ix_rr_reward ON loyalty.reward_redemptions(reward_id);
CREATE INDEX ix_rr_status ON loyalty.reward_redemptions(redemption_status_id);

-- ============================================================
-- 18.8 VOUCHERS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.vouchers (
    voucher_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    loyalty_program_id UUID NULL,
    reward_redemption_id UUID NULL,
    voucher_status_id UUID NOT NULL DEFAULT (SELECT voucher_status_id FROM loyalty.voucher_status_lookup WHERE code = 'ISSUED'),
    coupon_id UUID NULL,
    
    voucher_code VARCHAR(50) NOT NULL UNIQUE,
    voucher_type VARCHAR(30) NOT NULL DEFAULT 'DISCOUNT',
    
    discount_percentage NUMERIC(5,2) NULL,
    discount_amount NUMERIC(19,4) NULL,
    free_shipping BOOLEAN NOT NULL DEFAULT FALSE,
    
    minimum_order_amount NUMERIC(19,4) NULL,
    maximum_discount_amount NUMERIC(19,4) NULL,
    
    applicable_categories UUID[] NULL,
    applicable_products UUID[] NULL,
    excluded_products UUID[] NULL,
    
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    
    usage_count INTEGER NOT NULL DEFAULT 0,
    max_usage INTEGER NOT NULL DEFAULT 1,
    max_usage_per_customer INTEGER NOT NULL DEFAULT 1,
    
    points_cost INTEGER NULL,
    
    issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    first_used_at TIMESTAMPTZ NULL,
    last_used_at TIMESTAMPTZ NULL,
    redeemed_at TIMESTAMPTZ NULL,
    expired_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,
    cancellation_reason TEXT NULL,
    
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_v_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_v_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_v_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT fk_v_redemption FOREIGN KEY (reward_redemption_id) REFERENCES loyalty.reward_redemptions(reward_redemption_id),
    CONSTRAINT fk_v_status FOREIGN KEY (voucher_status_id) REFERENCES loyalty.voucher_status_lookup(voucher_status_id),
    CONSTRAINT fk_v_coupon FOREIGN KEY (coupon_id) REFERENCES pricing.coupons(coupon_id),
    CONSTRAINT ck_v_type CHECK (voucher_type IN ('DISCOUNT', 'FREE_SHIPPING', 'FREE_PRODUCT', 'CASHBACK', 'GIFT_CARD')),
    CONSTRAINT ck_v_dates CHECK (valid_until >= valid_from),
    CONSTRAINT ck_v_usage CHECK (usage_count >= 0 AND usage_count <= max_usage)
);

CREATE INDEX ix_v_customer ON loyalty.vouchers(customer_id);
CREATE INDEX ix_v_status ON loyalty.vouchers(voucher_status_id);
CREATE INDEX ix_v_code ON loyalty.vouchers(voucher_code);
CREATE INDEX ix_v_valid ON loyalty.vouchers(valid_from, valid_until) WHERE is_expired = FALSE;

-- Voucher Usage History
CREATE TABLE IF NOT EXISTS loyalty.voucher_usage_history (
    voucher_usage_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id UUID NOT NULL,
    order_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    
    discount_applied NUMERIC(19,4) NOT NULL,
    used_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_vuh_voucher FOREIGN KEY (voucher_id) REFERENCES loyalty.vouchers(voucher_id),
    CONSTRAINT fk_vuh_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_vuh_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id)
);

CREATE INDEX ix_vuh_voucher ON loyalty.voucher_usage_history(voucher_id);
CREATE INDEX ix_vuh_customer ON loyalty.voucher_usage_history(customer_id);

-- ============================================================
-- 18.9 CASHBACK RULES & TRANSACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.cashback_rules (
    cashback_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_id UUID NOT NULL,
    cashback_type_id UUID NOT NULL,
    loyalty_tier_id UUID NULL,
    product_category_id UUID NULL,
    sales_channel_id UUID NULL,
    
    rule_name VARCHAR(200) NOT NULL,
    cashback_percentage NUMERIC(5,2) NULL,
    fixed_cashback_amount NUMERIC(19,4) NULL,
    maximum_cashback_amount NUMERIC(19,4) NULL,
    minimum_order_amount NUMERIC(19,4) NULL,
    
    cashback_delay_days INTEGER NOT NULL DEFAULT 0,
    cashback_hold_days INTEGER NOT NULL DEFAULT 0,
    
    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    start_date DATE NULL,
    end_date DATE NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cr_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT fk_cr_type FOREIGN KEY (cashback_type_id) REFERENCES loyalty.cashback_type_lookup(cashback_type_id),
    CONSTRAINT fk_cr_tier FOREIGN KEY (loyalty_tier_id) REFERENCES loyalty.loyalty_tiers(loyalty_tier_id),
    CONSTRAINT ck_cr_percentage CHECK (cashback_percentage IS NULL OR (cashback_percentage >= 0 AND cashback_percentage <= 100))
);

-- Cashback Transactions
CREATE TABLE IF NOT EXISTS loyalty.cashback_transactions (
    cashback_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    order_id UUID NULL,
    cashback_rule_id UUID NULL,
    
    cashback_number VARCHAR(50) NOT NULL,
    cashback_amount NUMERIC(19,4) NOT NULL,
    currency_id UUID NOT NULL,
    
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    order_amount NUMERIC(19,4) NULL,
    cashback_percentage NUMERIC(5,2) NULL,
    
    earned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    available_at TIMESTAMPTZ NULL,
    credited_at TIMESTAMPTZ NULL,
    expired_at TIMESTAMPTZ NULL,
    reversed_at TIMESTAMPTZ NULL,
    reversal_reason TEXT NULL,
    
    is_reversed BOOLEAN NOT NULL DEFAULT FALSE,
    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ct_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ct_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ct_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_ct_rule FOREIGN KEY (cashback_rule_id) REFERENCES loyalty.cashback_rules(cashback_rule_id),
    CONSTRAINT fk_ct_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_cashback_number UNIQUE (company_id, cashback_number),
    CONSTRAINT ck_ct_status CHECK (status IN ('PENDING', 'AVAILABLE', 'CREDITED', 'EXPIRED', 'REVERSED')),
    CONSTRAINT ck_ct_amount CHECK (cashback_amount >= 0)
);

CREATE INDEX ix_ct_customer ON loyalty.cashback_transactions(customer_id);
CREATE INDEX ix_ct_order ON loyalty.cashback_transactions(order_id);
CREATE INDEX ix_ct_status ON loyalty.cashback_transactions(status);

-- ============================================================
-- 18.10 REFERRAL PROGRAMS & REWARDS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.referral_programs (
    referral_program_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_id UUID NULL,
    
    program_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    
    referrer_reward_type VARCHAR(30) NOT NULL DEFAULT 'POINTS',
    referrer_points_reward INTEGER NULL,
    referrer_cashback_amount NUMERIC(19,4) NULL,
    referrer_discount_percentage NUMERIC(5,2) NULL,
    
    referee_reward_type VARCHAR(30) NOT NULL DEFAULT 'POINTS',
    referee_points_reward INTEGER NULL,
    referee_cashback_amount NUMERIC(19,4) NULL,
    referee_discount_percentage NUMERIC(5,2) NULL,
    
    minimum_order_amount NUMERIC(19,4) NULL,
    reward_after_days INTEGER NOT NULL DEFAULT 0,
    
    max_referrals_per_customer INTEGER NULL,
    max_referrals_per_day INTEGER NULL,
    
    referral_code_length INTEGER NOT NULL DEFAULT 8,
    referral_code_prefix VARCHAR(10) NULL,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    start_date DATE NULL,
    end_date DATE NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_rp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rp_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT ck_rp_referrer_type CHECK (referrer_reward_type IN ('POINTS', 'CASHBACK', 'DISCOUNT', 'VOUCHER')),
    CONSTRAINT ck_rp_referee_type CHECK (referee_reward_type IN ('POINTS', 'CASHBACK', 'DISCOUNT', 'VOUCHER'))
);

-- Referral Codes
CREATE TABLE IF NOT EXISTS loyalty.referral_codes (
    referral_code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referral_program_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    
    referral_code VARCHAR(50) NOT NULL UNIQUE,
    referral_link VARCHAR(500) NULL,
    
    total_referrals INTEGER NOT NULL DEFAULT 0,
    successful_referrals INTEGER NOT NULL DEFAULT 0,
    pending_referrals INTEGER NOT NULL DEFAULT 0,
    
    total_rewards_earned NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_points_earned BIGINT NOT NULL DEFAULT 0,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_referral_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_rc_program FOREIGN KEY (referral_program_id) REFERENCES loyalty.referral_programs(referral_program_id),
    CONSTRAINT fk_rc_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT uq_customer_referral UNIQUE (referral_program_id, customer_id)
);

CREATE INDEX ix_rc_code ON loyalty.referral_codes(referral_code);
CREATE INDEX ix_rc_customer ON loyalty.referral_codes(customer_id);

-- Referral Transactions
CREATE TABLE IF NOT EXISTS loyalty.referral_transactions (
    referral_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referral_program_id UUID NOT NULL,
    referral_code_id UUID NOT NULL,
    referrer_customer_id UUID NOT NULL,
    referee_customer_id UUID NOT NULL,
    order_id UUID NULL,
    
    transaction_number VARCHAR(50) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    
    referrer_reward_type VARCHAR(30) NULL,
    referrer_reward_amount NUMERIC(19,4) NULL,
    referrer_points_awarded BIGINT NULL,
    
    referee_reward_type VARCHAR(30) NULL,
    referee_reward_amount NUMERIC(19,4) NULL,
    referee_points_awarded BIGINT NULL,
    
    referred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    qualified_at TIMESTAMPTZ NULL,
    rewarded_at TIMESTAMPTZ NULL,
    expired_at TIMESTAMPTZ NULL,
    
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rt_program FOREIGN KEY (referral_program_id) REFERENCES loyalty.referral_programs(referral_program_id),
    CONSTRAINT fk_rt_code FOREIGN KEY (referral_code_id) REFERENCES loyalty.referral_codes(referral_code_id),
    CONSTRAINT fk_rt_referrer FOREIGN KEY (referrer_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rt_referee FOREIGN KEY (referee_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rt_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT uq_transaction_number UNIQUE (transaction_number),
    CONSTRAINT ck_rt_status CHECK (status IN ('PENDING', 'QUALIFIED', 'REWARDED', 'EXPIRED', 'CANCELLED', 'FRAUD'))
);

CREATE INDEX ix_rt_referrer ON loyalty.referral_transactions(referrer_customer_id);
CREATE INDEX ix_rt_referee ON loyalty.referral_transactions(referee_customer_id);
CREATE INDEX ix_rt_status ON loyalty.referral_transactions(status);

-- ============================================================
-- 18.11 PURCHASE-BASED REWARDS (Milestones)
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.purchase_milestones (
    purchase_milestone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_id UUID NOT NULL,
    
    milestone_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    
    milestone_type VARCHAR(30) NOT NULL DEFAULT 'ORDER_COUNT',
    milestone_value INTEGER NOT NULL,
    
    reward_type VARCHAR(30) NOT NULL DEFAULT 'POINTS',
    points_reward INTEGER NULL,
    cashback_amount NUMERIC(19,4) NULL,
    voucher_template_id UUID NULL,
    
    is_one_time BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pm_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT ck_pm_type CHECK (milestone_type IN ('ORDER_COUNT', 'TOTAL_SPEND', 'CATEGORY_ORDERS', 'CONSECUTIVE_MONTHS')),
    CONSTRAINT ck_pm_reward CHECK (reward_type IN ('POINTS', 'CASHBACK', 'VOUCHER', 'TIER_UPGRADE', 'BADGE'))
);

-- Milestone Achievements
CREATE TABLE IF NOT EXISTS loyalty.milestone_achievements (
    milestone_achievement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_milestone_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    
    achieved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    points_awarded BIGINT NULL,
    cashback_awarded NUMERIC(19,4) NULL,
    voucher_id UUID NULL,
    
    current_value INTEGER NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ma_milestone FOREIGN KEY (purchase_milestone_id) REFERENCES loyalty.purchase_milestones(purchase_milestone_id),
    CONSTRAINT fk_ma_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ma_voucher FOREIGN KEY (voucher_id) REFERENCES loyalty.vouchers(voucher_id),
    CONSTRAINT uq_milestone_customer UNIQUE (purchase_milestone_id, customer_id)
);

CREATE INDEX ix_ma_customer ON loyalty.milestone_achievements(customer_id);

-- ============================================================
-- 18.12 BIRTHDAY & ANNIVERSARY REWARDS
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.birthday_rewards (
    birthday_reward_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_id UUID NOT NULL,
    loyalty_tier_id UUID NULL,
    
    reward_name VARCHAR(200) NOT NULL,
    points_reward INTEGER NULL,
    cashback_amount NUMERIC(19,4) NULL,
    voucher_template_id UUID NULL,
    
    valid_days_before INTEGER NOT NULL DEFAULT 0,
    valid_days_after INTEGER NOT NULL DEFAULT 7,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_br_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_br_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT fk_br_tier FOREIGN KEY (loyalty_tier_id) REFERENCES loyalty.loyalty_tiers(loyalty_tier_id)
);

-- Birthday Reward History
CREATE TABLE IF NOT EXISTS loyalty.birthday_reward_history (
    birthday_reward_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    birthday_reward_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    
    birthday_date DATE NOT NULL,
    points_awarded BIGINT NULL,
    cashback_awarded NUMERIC(19,4) NULL,
    voucher_id UUID NULL,
    points_transaction_id UUID NULL,
    
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_brh_reward FOREIGN KEY (birthday_reward_id) REFERENCES loyalty.birthday_rewards(birthday_reward_id),
    CONSTRAINT fk_brh_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_brh_voucher FOREIGN KEY (voucher_id) REFERENCES loyalty.vouchers(voucher_id),
    CONSTRAINT fk_brh_transaction FOREIGN KEY (points_transaction_id) REFERENCES loyalty.points_transactions(points_transaction_id),
    CONSTRAINT uq_birthday_customer_year UNIQUE (customer_id, birthday_date)
);

CREATE INDEX ix_brh_customer ON loyalty.birthday_reward_history(customer_id);

-- ============================================================
-- 18.13 LOYALTY CAMPAIGNS (Bonus Multipliers)
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.loyalty_campaigns (
    loyalty_campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    loyalty_program_id UUID NOT NULL,
    marketing_campaign_id UUID NULL,
    
    campaign_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    campaign_type VARCHAR(30) NOT NULL DEFAULT 'POINTS_MULTIPLIER',
    
    points_multiplier NUMERIC(5,2) NULL,
    bonus_points INTEGER NULL,
    cashback_multiplier NUMERIC(5,2) NULL,
    
    applicable_tiers UUID[] NULL,
    applicable_categories UUID[] NULL,
    applicable_products UUID[] NULL,
    applicable_channels UUID[] NULL,
    
    minimum_order_amount NUMERIC(19,4) NULL,
    maximum_bonus_per_order INTEGER NULL,
    maximum_total_bonus INTEGER NULL,
    
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_lc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_lc_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT fk_lc_marketing FOREIGN KEY (marketing_campaign_id) REFERENCES marketing.campaigns(campaign_id),
    CONSTRAINT ck_lc_type CHECK (campaign_type IN ('POINTS_MULTIPLIER', 'BONUS_POINTS', 'CASHBACK_BOOST', 'DOUBLE_POINTS', 'TRIPLE_POINTS')),
    CONSTRAINT ck_lc_dates CHECK (end_date > start_date)
);

CREATE INDEX ix_lc_program ON loyalty.loyalty_campaigns(loyalty_program_id);
CREATE INDEX ix_lc_active ON loyalty.loyalty_campaigns(is_active, start_date, end_date);

-- ============================================================
-- 18.14 POINTS EXPIRATION CONFIGURATION
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty.points_expiration_rules (
    points_expiration_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loyalty_program_id UUID NOT NULL,
    loyalty_tier_id UUID NULL,
    
    rule_name VARCHAR(200) NOT NULL,
    expiration_days INTEGER NOT NULL,
    
    reset_on_activity BOOLEAN NOT NULL DEFAULT TRUE,
    grace_period_days INTEGER NOT NULL DEFAULT 0,
    
    notification_days_before INTEGER[] NULL,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_per_program FOREIGN KEY (loyalty_program_id) REFERENCES loyalty.loyalty_programs(loyalty_program_id),
    CONSTRAINT fk_per_tier FOREIGN KEY (loyalty_tier_id) REFERENCES loyalty.loyalty_tiers(loyalty_tier_id),
    CONSTRAINT ck_per_days CHECK (expiration_days > 0)
);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_currency_id UUID;
    v_program_id UUID;
    v_bronze_tier UUID;
    v_silver_tier UUID;
    v_gold_tier UUID;
    v_platinum_tier UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;

    -- Create default loyalty program
    INSERT INTO loyalty.loyalty_programs (
        company_id, program_code, program_name, description,
        points_currency_name, signup_bonus_points, points_per_currency_unit,
        currency_unit_per_point, points_expiry_days, auto_enroll_customers
    )
    SELECT v_company_id, 'LOYALTY-001', 'eStore Rewards', 'Default loyalty program for eStore customers.',
           'Reward Points', 100, 1.0, 1.0, 365, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.loyalty_programs WHERE company_id = v_company_id AND program_code = 'LOYALTY-001')
    RETURNING loyalty_program_id INTO v_program_id;

    IF v_program_id IS NULL THEN
        SELECT loyalty_program_id INTO v_program_id FROM loyalty.loyalty_programs WHERE company_id = v_company_id AND program_code = 'LOYALTY-001';
    END IF;

    -- Create loyalty tiers
    INSERT INTO loyalty.loyalty_tiers (loyalty_program_id, tier_code, tier_name, tier_level, minimum_points, points_multiplier, tier_color)
    SELECT v_program_id, 'BRONZE', 'Bronze', 1, 0, 1.0, '#CD7F32'
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.loyalty_tiers WHERE loyalty_program_id = v_program_id AND tier_code = 'BRONZE')
    RETURNING loyalty_tier_id INTO v_bronze_tier;

    INSERT INTO loyalty.loyalty_tiers (loyalty_program_id, tier_code, tier_name, tier_level, minimum_points, points_multiplier, tier_color)
    SELECT v_program_id, 'SILVER', 'Silver', 2, 1000, 1.25, '#C0C0C0'
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.loyalty_tiers WHERE loyalty_program_id = v_program_id AND tier_code = 'SILVER')
    RETURNING loyalty_tier_id INTO v_silver_tier;

    INSERT INTO loyalty.loyalty_tiers (loyalty_program_id, tier_code, tier_name, tier_level, minimum_points, points_multiplier, tier_color)
    SELECT v_program_id, 'GOLD', 'Gold', 3, 5000, 1.5, '#FFD700'
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.loyalty_tiers WHERE loyalty_program_id = v_program_id AND tier_code = 'GOLD')
    RETURNING loyalty_tier_id INTO v_gold_tier;

    INSERT INTO loyalty.loyalty_tiers (loyalty_program_id, tier_code, tier_name, tier_level, minimum_points, points_multiplier, tier_color)
    SELECT v_program_id, 'PLATINUM', 'Platinum', 4, 15000, 2.0, '#E5E4E2'
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.loyalty_tiers WHERE loyalty_program_id = v_program_id AND tier_code = 'PLATINUM')
    RETURNING loyalty_tier_id INTO v_platinum_tier;

    -- Create standard earning rule
    INSERT INTO loyalty.points_earning_rules (company_id, loyalty_program_id, rule_name, rule_type, points_per_currency_unit, priority)
    SELECT v_company_id, v_program_id, 'Standard Earning', 'STANDARD', 1.0, 0
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.points_earning_rules WHERE company_id = v_company_id AND rule_name = 'Standard Earning');

    -- Create referral program
    INSERT INTO loyalty.referral_programs (company_id, loyalty_program_id, program_name, referrer_reward_type, referrer_points_reward, referee_reward_type, referee_points_reward)
    SELECT v_company_id, v_program_id, 'Refer a Friend', 'POINTS', 500, 'POINTS', 200
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.referral_programs WHERE company_id = v_company_id AND program_name = 'Refer a Friend');

    -- Create birthday reward
    INSERT INTO loyalty.birthday_rewards (company_id, loyalty_program_id, reward_name, points_reward, valid_days_after)
    SELECT v_company_id, v_program_id, 'Birthday Bonus', 250, 7
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.birthday_rewards WHERE company_id = v_company_id AND reward_name = 'Birthday Bonus');

    -- Create sample rewards
    INSERT INTO loyalty.rewards (company_id, loyalty_program_id, reward_type_id, reward_code, reward_name, description, points_cost, cash_value)
    SELECT v_company_id, v_program_id, 
           (SELECT reward_type_id FROM loyalty.reward_type_lookup WHERE code = 'DISCOUNT_VOUCHER'),
           'RWD-500-DISC', 'Rs. 500 Discount', 'Rs. 500 off your next order', 500, 500.00
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.rewards WHERE company_id = v_company_id AND reward_code = 'RWD-500-DISC');

    INSERT INTO loyalty.rewards (company_id, loyalty_program_id, reward_type_id, reward_code, reward_name, description, points_cost)
    SELECT v_company_id, v_program_id,
           (SELECT reward_type_id FROM loyalty.reward_type_lookup WHERE code = 'FREE_SHIPPING'),
           'RWD-FREE-SHIP', 'Free Shipping', 'Free shipping on your next order', 200
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.rewards WHERE company_id = v_company_id AND reward_code = 'RWD-FREE-SHIP');

    INSERT INTO loyalty.rewards (company_id, loyalty_program_id, reward_type_id, reward_code, reward_name, description, points_cost, cash_value)
    SELECT v_company_id, v_program_id,
           (SELECT reward_type_id FROM loyalty.reward_type_lookup WHERE code = 'DISCOUNT_VOUCHER'),
           'RWD-1000-DISC', 'Rs. 1000 Discount', 'Rs. 1000 off your next order', 1000, 1000.00
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.rewards WHERE company_id = v_company_id AND reward_code = 'RWD-1000-DISC');

    -- Create expiration rule
    INSERT INTO loyalty.points_expiration_rules (loyalty_program_id, rule_name, expiration_days, reset_on_activity, notification_days_before)
    SELECT v_program_id, 'Standard Expiration', 365, TRUE, ARRAY[30, 7, 1]
    WHERE NOT EXISTS (SELECT 1 FROM loyalty.points_expiration_rules WHERE loyalty_program_id = v_program_id AND rule_name = 'Standard Expiration');

END $$;

COMMIT;