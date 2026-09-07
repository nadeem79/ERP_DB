BEGIN;

-- ============================================================
-- MODULE 30 — SUBSCRIPTIONS, RECURRING BILLING & MEMBERSHIPS
-- DATABASE TABLES
-- ============================================================
-- Design Decisions:
--   1. Subscription plans are templates; subscriptions are instances
--   2. Billing cycles drive order/invoice/payment creation
--   3. Orders remain source of truth for purchases
--   4. Payments remain source of truth for money
--   5. Accounting remains the financial source of truth
--   6. Subscription status transitions must be controlled
--   7. Proration must be calculated precisely
--   8. Trials are special billing cycles with zero amount
--   9. Membership access is represented by entitlements
--   10. Failed payments require proper retry/dunning process
--   11. Usage billing is optional and introduced later
--   12. Subscription events drive notifications and analytics
-- ============================================================

CREATE SCHEMA IF NOT EXISTS subscriptions;

-- ============================================================
-- LOOKUPS
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.subscription_plan_status_lookup (
    subscription_plan_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.subscription_plan_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Plan is being configured.', 10),
    ('ACTIVE', 'Active', 'Plan is available for purchase.', 20),
    ('PAUSED', 'Paused', 'Plan temporarily unavailable.', 30),
    ('RETIRED', 'Retired', 'Plan no longer available for new subscriptions.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.subscription_status_lookup (
    subscription_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.subscription_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Subscription created but not yet activated.', 10),
    ('TRIAL', 'Trial', 'Subscription in trial period.', 20),
    ('ACTIVE', 'Active', 'Subscription active and billing.', 30),
    ('PAST_DUE', 'Past Due', 'Payment failed, retrying.', 40),
    ('GRACE_PERIOD', 'Grace Period', 'In grace period before suspension.', 50),
    ('PAUSED', 'Paused', 'Subscription paused by customer.', 60),
    ('SUSPENDED', 'Suspended', 'Subscription suspended due to non-payment.', 70),
    ('CANCELLED', 'Cancelled', 'Subscription cancelled.', 80),
    ('EXPIRED', 'Expired', 'Subscription expired.', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.billing_frequency_lookup (
    billing_frequency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    interval_days INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.billing_frequency_lookup (code, name, description, interval_days, sort_order) VALUES
    ('DAILY', 'Daily', 'Billed every day.', 1, 10),
    ('WEEKLY', 'Weekly', 'Billed every week.', 7, 20),
    ('BIWEEKLY', 'Bi-Weekly', 'Billed every two weeks.', 14, 30),
    ('MONTHLY', 'Monthly', 'Billed every month.', 30, 40),
    ('QUARTERLY', 'Quarterly', 'Billed every three months.', 90, 50),
    ('SEMI_ANNUAL', 'Semi-Annual', 'Billed every six months.', 180, 60),
    ('ANNUAL', 'Annual', 'Billed every year.', 365, 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.billing_cycle_status_lookup (
    billing_cycle_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.billing_cycle_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Billing cycle not yet invoiced.', 10),
    ('INVOICED', 'Invoiced', 'Invoice created for this cycle.', 20),
    ('PAYMENT_PENDING', 'Payment Pending', 'Awaiting payment.', 30),
    ('PAID', 'Paid', 'Payment received.', 40),
    ('FAILED', 'Failed', 'Payment failed.', 50),
    ('OVERDUE', 'Overdue', 'Payment overdue.', 60),
    ('WAIVED', 'Waived', 'Billing waived (trial, promo).', 70),
    ('CANCELLED', 'Cancelled', 'Billing cycle cancelled.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.subscription_change_type_lookup (
    subscription_change_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.subscription_change_type_lookup (code, name, description, sort_order) VALUES
    ('UPGRADE', 'Upgrade', 'Upgrade to higher plan.', 10),
    ('DOWNGRADE', 'Downgrade', 'Downgrade to lower plan.', 20),
    ('PLAN_CHANGE', 'Plan Change', 'Change to different plan.', 30),
    ('ADDON_ADD', 'Add-on Added', 'Add-on added to subscription.', 40),
    ('ADDON_REMOVE', 'Add-on Removed', 'Add-on removed from subscription.', 50),
    ('QUANTITY_CHANGE', 'Quantity Change', 'Quantity/seats changed.', 60),
    ('RENEWAL', 'Renewal', 'Subscription renewed.', 70),
    ('CANCELLATION', 'Cancellation', 'Subscription cancelled.', 80),
    ('PAUSE', 'Pause', 'Subscription paused.', 90),
    ('RESUME', 'Resume', 'Subscription resumed.', 100),
    ('TRIAL_CONVERSION', 'Trial Conversion', 'Trial converted to paid.', 110)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.proration_method_lookup (
    proration_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.proration_method_lookup (code, name, description, sort_order) VALUES
    ('IMMEDIATE', 'Immediate', 'Change applied immediately with proration.', 10),
    ('NEXT_CYCLE', 'Next Cycle', 'Change applied at next billing cycle.', 20),
    ('PRORATED', 'Prorated', 'Prorated credit/charge applied.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.dunning_status_lookup (
    dunning_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.dunning_status_lookup (code, name, description, sort_order) VALUES
    ('RETRYING', 'Retrying', 'Payment retry in progress.', 10),
    ('GRACE_PERIOD', 'Grace Period', 'In grace period.', 20),
    ('NOTIFIED', 'Notified', 'Customer notified of failure.', 30),
    ('SUSPENDED', 'Suspended', 'Subscription suspended.', 40),
    ('CANCELLED', 'Cancelled', 'Subscription cancelled after dunning.', 50),
    ('RECOVERED', 'Recovered', 'Payment recovered.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.membership_tier_lookup (
    membership_tier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.membership_tier_lookup (code, name, description, sort_order) VALUES
    ('BASIC', 'Basic', 'Basic membership tier.', 10),
    ('SILVER', 'Silver', 'Silver membership tier.', 20),
    ('GOLD', 'Gold', 'Gold membership tier.', 30),
    ('PLATINUM', 'Platinum', 'Platinum membership tier.', 40),
    ('ENTERPRISE', 'Enterprise', 'Enterprise membership tier.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS subscriptions.entitlement_type_lookup (
    entitlement_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO subscriptions.entitlement_type_lookup (code, name, description, sort_order) VALUES
    ('FEATURE_ACCESS', 'Feature Access', 'Access to specific features.', 10),
    ('USAGE_LIMIT', 'Usage Limit', 'Usage quota/limit.', 20),
    ('DISCOUNT', 'Discount', 'Discount entitlement.', 30),
    ('SUPPORT_LEVEL', 'Support Level', 'Support level entitlement.', 40),
    ('CONTENT_ACCESS', 'Content Access', 'Access to content/library.', 50),
    ('PRIORITY', 'Priority', 'Priority access/processing.', 60),
    ('STORAGE', 'Storage', 'Storage allocation.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- SUBSCRIPTION PLANS
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.subscription_plans (
    subscription_plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    subscription_plan_status_id UUID NOT NULL DEFAULT (SELECT subscription_plan_status_id FROM subscriptions.subscription_plan_status_lookup WHERE code = 'DRAFT'),
    billing_frequency_id UUID NOT NULL,

    plan_code VARCHAR(50) NOT NULL,
    plan_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    base_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    setup_fee NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    trial_days INTEGER NOT NULL DEFAULT 0,
    trial_requires_payment_method BOOLEAN NOT NULL DEFAULT FALSE,

    billing_interval INTEGER NOT NULL DEFAULT 1,
    billing_anchor_day INTEGER NULL,

    max_subscribers INTEGER NULL,
    min_subscribers INTEGER NOT NULL DEFAULT 1,

    is_recurring BOOLEAN NOT NULL DEFAULT TRUE,
    auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
    allow_upgrades BOOLEAN NOT NULL DEFAULT TRUE,
    allow_downgrades BOOLEAN NOT NULL DEFAULT TRUE,
    allow_pausing BOOLEAN NOT NULL DEFAULT TRUE,
    max_pause_days INTEGER NULL,

    cancellation_policy TEXT NULL,
    proration_method_id UUID NULL,

    membership_tier_id UUID NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from DATE NULL,
    effective_to DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sp_status FOREIGN KEY (subscription_plan_status_id) REFERENCES subscriptions.subscription_plan_status_lookup(subscription_plan_status_id),
    CONSTRAINT fk_sp_frequency FOREIGN KEY (billing_frequency_id) REFERENCES subscriptions.billing_frequency_lookup(billing_frequency_id),
    CONSTRAINT fk_sp_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_sp_proration FOREIGN KEY (proration_method_id) REFERENCES subscriptions.proration_method_lookup(proration_method_id),
    CONSTRAINT fk_sp_tier FOREIGN KEY (membership_tier_id) REFERENCES subscriptions.membership_tier_lookup(membership_tier_id),
    CONSTRAINT uq_plan_code UNIQUE (company_id, plan_code),
    CONSTRAINT ck_sp_price CHECK (base_price >= 0 AND setup_fee >= 0),
    CONSTRAINT ck_sp_trial CHECK (trial_days >= 0),
    CONSTRAINT ck_sp_interval CHECK (billing_interval >= 1),
    CONSTRAINT ck_sp_subscribers CHECK (min_subscribers >= 1 AND (max_subscribers IS NULL OR max_subscribers >= min_subscribers))
);

CREATE INDEX ix_sp_company ON subscriptions.subscription_plans(company_id);
CREATE INDEX ix_sp_status ON subscriptions.subscription_plans(subscription_plan_status_id);
CREATE INDEX ix_sp_active ON subscriptions.subscription_plans(is_active);

-- Plan Items (products included in plan)
CREATE TABLE IF NOT EXISTS subscriptions.subscription_plan_items (
    subscription_plan_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_plan_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    included_price NUMERIC(19,4) NOT NULL DEFAULT 0,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_spi_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscriptions.subscription_plans(subscription_plan_id) ON DELETE CASCADE,
    CONSTRAINT fk_spi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_spi_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_spi_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_spi_plan ON subscriptions.subscription_plan_items(subscription_plan_id);

-- Plan Add-ons
CREATE TABLE IF NOT EXISTS subscriptions.subscription_plan_addons (
    subscription_plan_addon_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_plan_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    addon_code VARCHAR(50) NOT NULL,
    addon_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    price NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    billing_frequency_id UUID NULL,

    is_optional BOOLEAN NOT NULL DEFAULT TRUE,
    max_quantity INTEGER NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_spa_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscriptions.subscription_plans(subscription_plan_id) ON DELETE CASCADE,
    CONSTRAINT fk_spa_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_spa_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_spa_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_spa_frequency FOREIGN KEY (billing_frequency_id) REFERENCES subscriptions.billing_frequency_lookup(billing_frequency_id),
    CONSTRAINT uq_plan_addon UNIQUE (subscription_plan_id, addon_code),
    CONSTRAINT ck_spa_price CHECK (price >= 0)
);

CREATE INDEX ix_spa_plan ON subscriptions.subscription_plan_addons(subscription_plan_id);

-- ============================================================
-- SUBSCRIPTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.subscriptions (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    subscription_plan_id UUID NOT NULL,
    subscription_status_id UUID NOT NULL DEFAULT (SELECT subscription_status_id FROM subscriptions.subscription_status_lookup WHERE code = 'PENDING'),
    customer_id UUID NOT NULL,

    subscription_number VARCHAR(80) NOT NULL,

    currency_id UUID NOT NULL,
    base_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    setup_fee NUMERIC(19,4) NOT NULL DEFAULT 0,
    addon_total NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    quantity INTEGER NOT NULL DEFAULT 1,

    start_date DATE NOT NULL,
    trial_end_date DATE NULL,
    current_period_start DATE NOT NULL,
    current_period_end DATE NOT NULL,
    next_billing_date DATE NULL,
    cancelled_at TIMESTAMPTZ NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
    ends_at TIMESTAMPTZ NULL,

    auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
    billing_frequency_id UUID NOT NULL,
    billing_interval INTEGER NOT NULL DEFAULT 1,

    payment_method_id UUID NULL,
    payment_provider_customer_id VARCHAR(200) NULL,

    membership_tier_id UUID NULL,

    total_billed NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_paid NUMERIC(19,4) NOT NULL DEFAULT 0,
    outstanding_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    billing_cycle_count INTEGER NOT NULL DEFAULT 0,
    failed_payment_count INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sub_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sub_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscriptions.subscription_plans(subscription_plan_id),
    CONSTRAINT fk_sub_status FOREIGN KEY (subscription_status_id) REFERENCES subscriptions.subscription_status_lookup(subscription_status_id),
    CONSTRAINT fk_sub_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_sub_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_sub_frequency FOREIGN KEY (billing_frequency_id) REFERENCES subscriptions.billing_frequency_lookup(billing_frequency_id),
    CONSTRAINT fk_sub_tier FOREIGN KEY (membership_tier_id) REFERENCES subscriptions.membership_tier_lookup(membership_tier_id),
    CONSTRAINT uq_subscription_number UNIQUE (company_id, subscription_number),
    CONSTRAINT ck_sub_amounts CHECK (base_price >= 0 AND setup_fee >= 0 AND addon_total >= 0 AND total_amount >= 0 AND total_billed >= 0 AND total_paid >= 0 AND outstanding_amount >= 0),
    CONSTRAINT ck_sub_quantity CHECK (quantity >= 1),
    CONSTRAINT ck_sub_dates CHECK (current_period_end >= current_period_start)
);

CREATE INDEX ix_sub_company ON subscriptions.subscriptions(company_id);
CREATE INDEX ix_sub_customer ON subscriptions.subscriptions(customer_id);
CREATE INDEX ix_sub_plan ON subscriptions.subscriptions(subscription_plan_id);
CREATE INDEX ix_sub_status ON subscriptions.subscriptions(subscription_status_id);
CREATE INDEX ix_sub_next_billing ON subscriptions.subscriptions(next_billing_date);

-- Subscription Items
CREATE TABLE IF NOT EXISTS subscriptions.subscription_items (
    subscription_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_si_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_si_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_si_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_si_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_si_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_si_subscription ON subscriptions.subscription_items(subscription_id);

-- Subscription Add-ons (active)
CREATE TABLE IF NOT EXISTS subscriptions.subscription_addons (
    subscription_addon_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    subscription_plan_addon_id UUID NOT NULL,

    quantity INTEGER NOT NULL DEFAULT 1,
    price NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_sa_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_sa_plan_addon FOREIGN KEY (subscription_plan_addon_id) REFERENCES subscriptions.subscription_plan_addons(subscription_plan_addon_id),
    CONSTRAINT fk_sa_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_sa_quantity CHECK (quantity >= 1)
);

CREATE INDEX ix_sa_subscription ON subscriptions.subscription_addons(subscription_id);

-- ============================================================
-- BILLING CYCLES
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.billing_cycles (
    billing_cycle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    billing_cycle_status_id UUID NOT NULL DEFAULT (SELECT billing_cycle_status_id FROM subscriptions.billing_cycle_status_lookup WHERE code = 'PENDING'),

    cycle_number INTEGER NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    amount_due NUMERIC(19,4) NOT NULL DEFAULT 0,
    amount_paid NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    is_trial BOOLEAN NOT NULL DEFAULT FALSE,
    is_prorated BOOLEAN NOT NULL DEFAULT FALSE,
    proration_amount NUMERIC(19,4) NULL,

    invoice_id UUID NULL,
    order_id UUID NULL,
    payment_id UUID NULL,

    due_date DATE NULL,
    paid_at TIMESTAMPTZ NULL,
    failed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bc_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_bc_status FOREIGN KEY (billing_cycle_status_id) REFERENCES subscriptions.billing_cycle_status_lookup(billing_cycle_status_id),
    CONSTRAINT fk_bc_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_bc_invoice FOREIGN KEY (invoice_id) REFERENCES accounting.invoices(invoice_id),
    CONSTRAINT fk_bc_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_bc_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id),
    CONSTRAINT uq_billing_cycle UNIQUE (subscription_id, cycle_number),
    CONSTRAINT ck_bc_amounts CHECK (amount_due >= 0 AND amount_paid >= 0),
    CONSTRAINT ck_bc_dates CHECK (period_end >= period_start)
);

CREATE INDEX ix_bc_subscription ON subscriptions.billing_cycles(subscription_id);
CREATE INDEX ix_bc_status ON subscriptions.billing_cycles(billing_cycle_status_id);
CREATE INDEX ix_bc_due ON subscriptions.billing_cycles(due_date);

-- ============================================================
-- PAYMENT SCHEDULES
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.payment_schedules (
    payment_schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    billing_cycle_id UUID NULL,

    scheduled_date DATE NOT NULL,
    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED',
    attempted_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,

    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ps_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_ps_cycle FOREIGN KEY (billing_cycle_id) REFERENCES subscriptions.billing_cycles(billing_cycle_id),
    CONSTRAINT fk_ps_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_ps_status CHECK (status IN ('SCHEDULED', 'ATTEMPTING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    CONSTRAINT ck_ps_amount CHECK (amount >= 0)
);

CREATE INDEX ix_ps_subscription ON subscriptions.payment_schedules(subscription_id);
CREATE INDEX ix_ps_scheduled ON subscriptions.payment_schedules(scheduled_date);

-- ============================================================
-- SUBSCRIPTION EVENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.subscription_events (
    subscription_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    company_id UUID NOT NULL,

    event_type VARCHAR(50) NOT NULL,
    event_data JSONB NULL,

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    triggered_by_user_id UUID NULL,

    CONSTRAINT fk_se_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_se_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_se_type CHECK (event_type IN (
        'SUBSCRIPTION_CREATED', 'SUBSCRIPTION_ACTIVATED', 'TRIAL_STARTED', 'TRIAL_ENDED',
        'TRIAL_CONVERTED', 'BILLING_CYCLE_CREATED', 'PAYMENT_SUCCESS', 'PAYMENT_FAILED',
        'PAYMENT_RETRY', 'UPGRADE', 'DOWNGRADE', 'PLAN_CHANGED', 'ADDON_ADDED', 'ADDON_REMOVED',
        'QUANTITY_CHANGED', 'PAUSED', 'RESUMED', 'CANCELLATION_REQUESTED', 'CANCELLED',
        'EXPIRED', 'SUSPENDED', 'RENEWED', 'PRORATION_APPLIED', 'GRACE_PERIOD_STARTED',
        'DUNNING_STARTED', 'DUNNING_COMPLETED', 'MEMBERSHIP_GRANTED', 'MEMBERSHIP_REVOKED'
    ))
);

CREATE INDEX ix_se_subscription ON subscriptions.subscription_events(subscription_id);
CREATE INDEX ix_se_type ON subscriptions.subscription_events(event_type);
CREATE INDEX ix_se_occurred ON subscriptions.subscription_events(occurred_at DESC);

-- ============================================================
-- SUBSCRIPTION CHANGES
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.subscription_changes (
    subscription_change_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    subscription_change_type_id UUID NOT NULL,
    proration_method_id UUID NULL,

    from_plan_id UUID NULL,
    to_plan_id UUID NULL,
    from_quantity INTEGER NULL,
    to_quantity INTEGER NULL,

    change_data JSONB NULL,

    effective_date DATE NOT NULL,
    effective_immediately BOOLEAN NOT NULL DEFAULT TRUE,

    proration_credit NUMERIC(19,4) NULL,
    proration_charge NUMERIC(19,4) NULL,

    requested_by_user_id UUID NULL,
    approved_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sc_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_sc_type FOREIGN KEY (subscription_change_type_id) REFERENCES subscriptions.subscription_change_type_lookup(subscription_change_type_id),
    CONSTRAINT fk_sc_proration FOREIGN KEY (proration_method_id) REFERENCES subscriptions.proration_method_lookup(proration_method_id),
    CONSTRAINT fk_sc_from_plan FOREIGN KEY (from_plan_id) REFERENCES subscriptions.subscription_plans(subscription_plan_id),
    CONSTRAINT fk_sc_to_plan FOREIGN KEY (to_plan_id) REFERENCES subscriptions.subscription_plans(subscription_plan_id)
);

CREATE INDEX ix_sc_subscription ON subscriptions.subscription_changes(subscription_id);
CREATE INDEX ix_sc_type ON subscriptions.subscription_changes(subscription_change_type_id);

-- ============================================================
-- CANCELLATIONS & PAUSES
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.subscription_cancellations (
    subscription_cancellation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,

    cancellation_reason VARCHAR(300) NULL,
    cancellation_notes TEXT NULL,

    cancel_immediately BOOLEAN NOT NULL DEFAULT FALSE,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT TRUE,

    requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_at TIMESTAMPTZ NULL,

    requested_by_user_id UUID NULL,
    processed_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_suc_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE
);

CREATE INDEX ix_suc_subscription ON subscriptions.subscription_cancellations(subscription_id);

CREATE TABLE IF NOT EXISTS subscriptions.subscription_pauses (
    subscription_pause_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,

    pause_reason VARCHAR(300) NULL,
    pause_start_date DATE NOT NULL,
    pause_end_date DATE NULL,
    max_pause_days INTEGER NULL,

    resumed_at TIMESTAMPTZ NULL,

    requested_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sup_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT ck_sup_dates CHECK (pause_end_date IS NULL OR pause_end_date >= pause_start_date)
);

CREATE INDEX ix_sup_subscription ON subscriptions.subscription_pauses(subscription_id);

-- ============================================================
-- DUNNING
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.dunning_schedules (
    dunning_schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    billing_cycle_id UUID NOT NULL,
    dunning_status_id UUID NOT NULL DEFAULT (SELECT dunning_status_id FROM subscriptions.dunning_status_lookup WHERE code = 'RETRYING'),

    retry_schedule JSONB NULL,
    current_retry_number INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,

    grace_period_days INTEGER NOT NULL DEFAULT 7,
    grace_period_ends_at TIMESTAMPTZ NULL,

    next_retry_at TIMESTAMPTZ NULL,
    last_retry_at TIMESTAMPTZ NULL,

    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ds_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_ds_cycle FOREIGN KEY (billing_cycle_id) REFERENCES subscriptions.billing_cycles(billing_cycle_id),
    CONSTRAINT fk_ds_status FOREIGN KEY (dunning_status_id) REFERENCES subscriptions.dunning_status_lookup(dunning_status_id)
);

CREATE INDEX ix_ds_subscription ON subscriptions.dunning_schedules(subscription_id);
CREATE INDEX ix_ds_next_retry ON subscriptions.dunning_schedules(next_retry_at);

CREATE TABLE IF NOT EXISTS subscriptions.dunning_attempts (
    dunning_attempt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dunning_schedule_id UUID NOT NULL,

    attempt_number INTEGER NOT NULL,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    payment_id UUID NULL,
    amount_attempted NUMERIC(19,4) NOT NULL DEFAULT 0,

    status VARCHAR(30) NOT NULL DEFAULT 'ATTEMPTING',
    failure_reason TEXT NULL,

    notification_sent BOOLEAN NOT NULL DEFAULT FALSE,
    notification_sent_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_da_schedule FOREIGN KEY (dunning_schedule_id) REFERENCES subscriptions.dunning_schedules(dunning_schedule_id) ON DELETE CASCADE,
    CONSTRAINT fk_da_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id),
    CONSTRAINT ck_da_status CHECK (status IN ('ATTEMPTING', 'SUCCESS', 'FAILED', 'CANCELLED'))
);

CREATE INDEX ix_da_schedule ON subscriptions.dunning_attempts(dunning_schedule_id);

-- ============================================================
-- MEMBERSHIPS & ENTITLEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.customer_memberships (
    customer_membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    subscription_id UUID NULL,
    membership_tier_id UUID NOT NULL,

    membership_number VARCHAR(80) NULL,

    granted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NULL,
    revoked_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cm_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_cm_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id),
    CONSTRAINT fk_cm_tier FOREIGN KEY (membership_tier_id) REFERENCES subscriptions.membership_tier_lookup(membership_tier_id)
);

CREATE INDEX ix_cm_customer ON subscriptions.customer_memberships(customer_id);
CREATE INDEX ix_cm_subscription ON subscriptions.customer_memberships(subscription_id);
CREATE INDEX ix_cm_active ON subscriptions.customer_memberships(is_active);

CREATE TABLE IF NOT EXISTS subscriptions.membership_tier_entitlements (
    membership_tier_entitlement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    membership_tier_id UUID NOT NULL,
    entitlement_type_id UUID NOT NULL,

    entitlement_code VARCHAR(100) NOT NULL,
    entitlement_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    entitlement_value TEXT NULL,
    entitlement_value_numeric NUMERIC(19,4) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_mte_tier FOREIGN KEY (membership_tier_id) REFERENCES subscriptions.membership_tier_lookup(membership_tier_id) ON DELETE CASCADE,
    CONSTRAINT fk_mte_type FOREIGN KEY (entitlement_type_id) REFERENCES subscriptions.entitlement_type_lookup(entitlement_type_id),
    CONSTRAINT uq_tier_entitlement UNIQUE (membership_tier_id, entitlement_code)
);

CREATE INDEX ix_mte_tier ON subscriptions.membership_tier_entitlements(membership_tier_id);

CREATE TABLE IF NOT EXISTS subscriptions.customer_entitlements (
    customer_entitlement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_membership_id UUID NOT NULL,
    entitlement_type_id UUID NOT NULL,

    entitlement_code VARCHAR(100) NOT NULL,
    entitlement_name VARCHAR(200) NOT NULL,

    entitlement_value TEXT NULL,
    entitlement_value_numeric NUMERIC(19,4) NULL,

    granted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NULL,
    revoked_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ce_membership FOREIGN KEY (customer_membership_id) REFERENCES subscriptions.customer_memberships(customer_membership_id) ON DELETE CASCADE,
    CONSTRAINT fk_ce_type FOREIGN KEY (entitlement_type_id) REFERENCES subscriptions.entitlement_type_lookup(entitlement_type_id)
);

CREATE INDEX ix_ce_membership ON subscriptions.customer_entitlements(customer_membership_id);

-- ============================================================
-- USAGE RECORDS (Optional, for usage-based billing)
-- ============================================================

CREATE TABLE IF NOT EXISTS subscriptions.usage_records (
    usage_record_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    subscription_item_id UUID NULL,

    usage_type VARCHAR(100) NOT NULL,
    usage_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    usage_unit VARCHAR(50) NULL,

    usage_date DATE NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    billing_cycle_id UUID NULL,
    is_billed BOOLEAN NOT NULL DEFAULT FALSE,

    metadata JSONB NULL,

    CONSTRAINT fk_ur_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions.subscriptions(subscription_id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_item FOREIGN KEY (subscription_item_id) REFERENCES subscriptions.subscription_items(subscription_item_id),
    CONSTRAINT fk_ur_cycle FOREIGN KEY (billing_cycle_id) REFERENCES subscriptions.billing_cycles(billing_cycle_id),
    CONSTRAINT ck_ur_quantity CHECK (usage_quantity >= 0)
);

CREATE INDEX ix_ur_subscription ON subscriptions.usage_records(subscription_id);
CREATE INDEX ix_ur_date ON subscriptions.usage_records(usage_date);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION subscriptions.calculate_proration(
    p_subscription_id UUID,
    p_change_date DATE,
    p_old_amount NUMERIC,
    p_new_amount NUMERIC
)
RETURNS TABLE (
    proration_credit NUMERIC,
    proration_charge NUMERIC,
    net_amount NUMERIC
) AS $$
DECLARE
    v_sub RECORD;
    v_days_in_period INTEGER;
    v_days_remaining INTEGER;
    v_daily_old NUMERIC;
    v_daily_new NUMERIC;
    v_credit NUMERIC;
    v_charge NUMERIC;
BEGIN
    SELECT * INTO v_sub FROM subscriptions.subscriptions WHERE subscription_id = p_subscription_id;

    v_days_in_period := GREATEST((v_sub.current_period_end - v_sub.current_period_start) + 1, 1);
    v_days_remaining := GREATEST((v_sub.current_period_end - p_change_date) + 1, 0);

    v_daily_old := p_old_amount / v_days_in_period;
    v_daily_new := p_new_amount / v_days_in_period;

    v_credit := ROUND(v_daily_old * v_days_remaining, 4);
    v_charge := ROUND(v_daily_new * v_days_remaining, 4);

    RETURN QUERY SELECT v_credit, v_charge, (v_charge - v_credit);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION subscriptions.get_next_billing_date(
    p_current_period_end DATE,
    p_billing_frequency_id UUID,
    p_billing_interval INTEGER
)
RETURNS DATE AS $$
DECLARE
    v_interval_days INTEGER;
BEGIN
    SELECT interval_days INTO v_interval_days
    FROM subscriptions.billing_frequency_lookup
    WHERE billing_frequency_id = p_billing_frequency_id;

    RETURN p_current_period_end + (v_interval_days * p_billing_interval);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_currency_id UUID;
    v_monthly_freq UUID;
    v_annual_freq UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;
    SELECT billing_frequency_id INTO v_monthly_freq FROM subscriptions.billing_frequency_lookup WHERE code = 'MONTHLY';
    SELECT billing_frequency_id INTO v_annual_freq FROM subscriptions.billing_frequency_lookup WHERE code = 'ANNUAL';

    -- Create Basic Plan
    INSERT INTO subscriptions.subscription_plans (company_id, plan_code, plan_name, description, base_price, currency_id, billing_frequency_id, subscription_plan_status_id, trial_days, membership_tier_id)
    SELECT v_company_id, 'BASIC-MONTHLY', 'Basic Monthly', 'Basic subscription plan - monthly billing.', 999.00, v_currency_id, v_monthly_freq,
           (SELECT subscription_plan_status_id FROM subscriptions.subscription_plan_status_lookup WHERE code = 'ACTIVE'),
           14,
           (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'BASIC')
    WHERE NOT EXISTS (SELECT 1 FROM subscriptions.subscription_plans WHERE company_id = v_company_id AND plan_code = 'BASIC-MONTHLY');

    -- Create Gold Plan
    INSERT INTO subscriptions.subscription_plans (company_id, plan_code, plan_name, description, base_price, currency_id, billing_frequency_id, subscription_plan_status_id, trial_days, membership_tier_id)
    SELECT v_company_id, 'GOLD-MONTHLY', 'Gold Monthly', 'Gold subscription plan - monthly billing.', 2499.00, v_currency_id, v_monthly_freq,
           (SELECT subscription_plan_status_id FROM subscriptions.subscription_plan_status_lookup WHERE code = 'ACTIVE'),
           14,
           (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'GOLD')
    WHERE NOT EXISTS (SELECT 1 FROM subscriptions.subscription_plans WHERE company_id = v_company_id AND plan_code = 'GOLD-MONTHLY');

    -- Create Platinum Annual Plan
    INSERT INTO subscriptions.subscription_plans (company_id, plan_code, plan_name, description, base_price, currency_id, billing_frequency_id, subscription_plan_status_id, trial_days, membership_tier_id)
    SELECT v_company_id, 'PLATINUM-ANNUAL', 'Platinum Annual', 'Platinum subscription plan - annual billing.', 19999.00, v_currency_id, v_annual_freq,
           (SELECT subscription_plan_status_id FROM subscriptions.subscription_plan_status_lookup WHERE code = 'ACTIVE'),
           30,
           (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'PLATINUM')
    WHERE NOT EXISTS (SELECT 1 FROM subscriptions.subscription_plans WHERE company_id = v_company_id AND plan_code = 'PLATINUM-ANNUAL');

    -- Create entitlements for Gold tier
    INSERT INTO subscriptions.membership_tier_entitlements (membership_tier_id, entitlement_type_id, entitlement_code, entitlement_name, entitlement_value_numeric)
    SELECT (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'GOLD'),
           (SELECT entitlement_type_id FROM subscriptions.entitlement_type_lookup WHERE code = 'DISCOUNT'),
           'GOLD_DISCOUNT', 'Gold Member Discount', 10.00
    WHERE NOT EXISTS (
        SELECT 1 FROM subscriptions.membership_tier_entitlements
        WHERE membership_tier_id = (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'GOLD')
          AND entitlement_code = 'GOLD_DISCOUNT'
    );

    INSERT INTO subscriptions.membership_tier_entitlements (membership_tier_id, entitlement_type_id, entitlement_code, entitlement_name, entitlement_value_numeric)
    SELECT (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'PLATINUM'),
           (SELECT entitlement_type_id FROM subscriptions.entitlement_type_lookup WHERE code = 'DISCOUNT'),
           'PLATINUM_DISCOUNT', 'Platinum Member Discount', 20.00
    WHERE NOT EXISTS (
        SELECT 1 FROM subscriptions.membership_tier_entitlements
        WHERE membership_tier_id = (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'PLATINUM')
          AND entitlement_code = 'PLATINUM_DISCOUNT'
    );

    INSERT INTO subscriptions.membership_tier_entitlements (membership_tier_id, entitlement_type_id, entitlement_code, entitlement_name, entitlement_value)
    SELECT (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'PLATINUM'),
           (SELECT entitlement_type_id FROM subscriptions.entitlement_type_lookup WHERE code = 'SUPPORT_LEVEL'),
           'PRIORITY_SUPPORT', 'Priority Support', 'PRIORITY'
    WHERE NOT EXISTS (
        SELECT 1 FROM subscriptions.membership_tier_entitlements
        WHERE membership_tier_id = (SELECT membership_tier_id FROM subscriptions.membership_tier_lookup WHERE code = 'PLATINUM')
          AND entitlement_code = 'PRIORITY_SUPPORT'
    );

END $$;

COMMIT;