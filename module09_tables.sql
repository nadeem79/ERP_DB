BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 09: PAYMENTS / PAYMENT GATEWAYS
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   A payment is a financial event, separate from the order.
--   Payment status flow: PENDING → PROCESSING → COMPLETED → SETTLED
--   Idempotency is critical for payment processing.
--   Gateway credentials must never be exposed.
-- ============================================================
-- Components:
--   09.1  Payment Methods
--   09.2  Payment Gateways & Credentials
--   09.3  Payments (Main)
--   09.4  Payment Transactions (Gateway)
--   09.5  Payment Refunds
--   09.6  Payment Reconciliations
--   09.7  Payment Webhooks
--   09.8  Payment Splits
--   09.9  Payment Settlements
--   09.10 Payment Retries
--   09.11 Payment Journal Entries (Accounting)
--   09.12 Payment Status History
-- ============================================================

CREATE SCHEMA IF NOT EXISTS payments;

-- ============================================================
-- 09.1 PAYMENT METHOD STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_method_status_lookup (
    payment_method_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO payments.payment_method_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Payment method is active.', 10),
    ('INACTIVE', 'Inactive', 'Payment method is disabled.', 20),
    ('MAINTENANCE', 'Maintenance', 'Payment method under maintenance.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 09.2 PAYMENT METHODS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_methods (
    payment_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    payment_method_status_id UUID NOT NULL DEFAULT (SELECT payment_method_status_id FROM payments.payment_method_status_lookup WHERE code = 'ACTIVE'),

    method_code VARCHAR(50) NOT NULL,
    method_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    method_type VARCHAR(30) NOT NULL DEFAULT 'ONLINE',
    requires_gateway BOOLEAN NOT NULL DEFAULT FALSE,
    requires_manual_confirmation BOOLEAN NOT NULL DEFAULT FALSE,
    supports_refund BOOLEAN NOT NULL DEFAULT TRUE,
    supports_partial_refund BOOLEAN NOT NULL DEFAULT TRUE,
    supports_recurring BOOLEAN NOT NULL DEFAULT FALSE,

    processing_fee_percent NUMERIC(5,2) NULL,
    processing_fee_fixed NUMERIC(19,4) NULL,

    display_order INTEGER NOT NULL DEFAULT 0,
    icon_url VARCHAR(500) NULL,

    min_amount NUMERIC(19,4) NULL,
    max_amount NUMERIC(19,4) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pm_status FOREIGN KEY (payment_method_status_id) REFERENCES payments.payment_method_status_lookup(payment_method_status_id),
    CONSTRAINT uq_method_code UNIQUE (company_id, method_code),
    CONSTRAINT ck_pm_type CHECK (method_type IN ('ONLINE', 'OFFLINE', 'COD', 'WALLET', 'BANK', 'CARD', 'CRYPTO')),
    CONSTRAINT ck_pm_amounts CHECK ((min_amount IS NULL OR min_amount >= 0) AND (max_amount IS NULL OR max_amount >= 0))
);

CREATE INDEX ix_pm_company ON payments.payment_methods(company_id);
CREATE INDEX ix_pm_status ON payments.payment_methods(payment_method_status_id);
CREATE INDEX ix_pm_active ON payments.payment_methods(is_active);

-- ============================================================
-- 09.3 PAYMENT GATEWAYS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_gateways (
    payment_gateway_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    gateway_code VARCHAR(50) NOT NULL,
    gateway_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    gateway_type VARCHAR(30) NOT NULL DEFAULT 'ONLINE',
    api_endpoint VARCHAR(500) NULL,
    api_version VARCHAR(50) NULL,
    api_key_encrypted TEXT NULL,
    api_secret_encrypted TEXT NULL,
    webhook_secret_encrypted TEXT NULL,

    supports_capture BOOLEAN NOT NULL DEFAULT TRUE,
    supports_refund BOOLEAN NOT NULL DEFAULT TRUE,
    supports_partial_refund BOOLEAN NOT NULL DEFAULT TRUE,
    supports_webhooks BOOLEAN NOT NULL DEFAULT TRUE,
    supports_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    supports_3ds BOOLEAN NOT NULL DEFAULT FALSE,

    currency_ids UUID[] NULL,
    supported_countries VARCHAR(10)[] NULL,

    processing_fee_percent NUMERIC(5,2) NULL,
    processing_fee_fixed NUMERIC(19,4) NULL,
    settlement_delay_days INTEGER NULL,

    is_test_mode BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pg_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_gateway_code UNIQUE (company_id, gateway_code),
    CONSTRAINT ck_pg_type CHECK (gateway_type IN ('ONLINE', 'MOBILE', 'CRYPTO', 'BANK', 'WALLET', 'POS', 'COD'))
);

CREATE INDEX ix_pg_company ON payments.payment_gateways(company_id);
CREATE INDEX ix_pg_active ON payments.payment_gateways(is_active);

-- ============================================================
-- 09.4 PAYMENT STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_status_lookup (
    payment_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO payments.payment_status_lookup (code, name, description, is_terminal, sort_order) VALUES
    ('PENDING', 'Pending', 'Payment initiated, awaiting processing.', FALSE, 10),
    ('PROCESSING', 'Processing', 'Payment being processed by gateway.', FALSE, 20),
    ('AUTHORIZED', 'Authorized', 'Payment authorized but not captured.', FALSE, 30),
    ('COMPLETED', 'Completed', 'Payment successfully completed.', TRUE, 40),
    ('SETTLED', 'Settled', 'Payment settled with merchant.', TRUE, 50),
    ('FAILED', 'Failed', 'Payment failed.', TRUE, 60),
    ('CANCELLED', 'Cancelled', 'Payment cancelled.', TRUE, 70),
    ('REFUND_PENDING', 'Refund Pending', 'Refund initiated.', FALSE, 80),
    ('REFUND_PROCESSING', 'Refund Processing', 'Refund being processed.', FALSE, 90),
    ('REFUNDED', 'Refunded', 'Payment fully refunded.', TRUE, 100),
    ('PARTIALLY_REFUNDED', 'Partially Refunded', 'Payment partially refunded.', TRUE, 110),
    ('CHARGEBACK', 'Chargeback', 'Payment disputed/charged back.', TRUE, 120),
    ('EXPIRED', 'Expired', 'Payment expired.', TRUE, 130)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 09.5 PAYMENTS (Main Table)
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payments (
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    order_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    payment_method_id UUID NULL,
    payment_gateway_id UUID NULL,
    payment_status_id UUID NOT NULL DEFAULT (SELECT payment_status_id FROM payments.payment_status_lookup WHERE code = 'PENDING'),

    payment_number VARCHAR(50) NOT NULL,
    idempotency_key VARCHAR(200) NULL UNIQUE,

    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_type VARCHAR(30) NOT NULL DEFAULT 'SALE',

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,
    base_amount NUMERIC(19,4) NULL,

    processing_fee NUMERIC(19,4) NULL,
    net_amount NUMERIC(19,4) NULL,

    -- Gateway transaction info
    gateway_transaction_id VARCHAR(200) NULL,
    gateway_reference VARCHAR(200) NULL,
    gateway_response_code VARCHAR(50) NULL,
    gateway_response_message TEXT NULL,

    -- Card info (masked)
    card_type VARCHAR(30) NULL,
    card_last_four VARCHAR(10) NULL,
    card_holder_name VARCHAR(200) NULL,
    card_expiry VARCHAR(10) NULL,

    -- COD info
    cod_reference VARCHAR(100) NULL,
    cod_collected_at TIMESTAMPTZ NULL,

    -- Bank transfer info
    bank_reference VARCHAR(200) NULL,
    bank_name VARCHAR(200) NULL,
    bank_account_last_four VARCHAR(10) NULL,

    -- Wallet info
    wallet_id VARCHAR(200) NULL,
    wallet_type VARCHAR(50) NULL,

    -- Refund tracking
    refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    refunded_at TIMESTAMPTZ NULL,

    -- Status tracking
    initiated_at TIMESTAMPTZ NULL,
    processed_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    settled_at TIMESTAMPTZ NULL,
    failed_at TIMESTAMPTZ NULL,
    failure_reason TEXT NULL,

    -- Retry tracking
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    last_retry_at TIMESTAMPTZ NULL,

    -- Settlement tracking
    settlement_batch_id VARCHAR(200) NULL,
    settlement_date DATE NULL,

    -- Metadata
    ip_address INET NULL,
    user_agent TEXT NULL,
    metadata JSONB NULL,

    is_test_payment BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pay_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pay_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_pay_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_pay_method FOREIGN KEY (payment_method_id) REFERENCES payments.payment_methods(payment_method_id),
    CONSTRAINT fk_pay_gateway FOREIGN KEY (payment_gateway_id) REFERENCES payments.payment_gateways(payment_gateway_id),
    CONSTRAINT fk_pay_status FOREIGN KEY (payment_status_id) REFERENCES payments.payment_status_lookup(payment_status_id),
    CONSTRAINT fk_pay_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_payment_number UNIQUE (company_id, payment_number),
    CONSTRAINT ck_pay_amount CHECK (amount > 0),
    CONSTRAINT ck_pay_type CHECK (payment_type IN ('SALE', 'REFUND', 'RECURRING', 'DEPOSIT', 'WITHDRAWAL', 'TRANSFER')),
    CONSTRAINT ck_pay_refund CHECK (refund_amount >= 0 AND refund_amount <= amount)
);

CREATE INDEX ix_pay_company ON payments.payments(company_id);
CREATE INDEX ix_pay_order ON payments.payments(order_id);
CREATE INDEX ix_pay_customer ON payments.payments(customer_id);
CREATE INDEX ix_pay_status ON payments.payments(payment_status_id);
CREATE INDEX ix_pay_gateway ON payments.payments(payment_gateway_id);
CREATE INDEX ix_pay_date ON payments.payments(payment_date);
CREATE INDEX ix_pay_idempotency ON payments.payments(idempotency_key);

-- ============================================================
-- 09.6 PAYMENT TRANSACTIONS (Gateway Level)
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_transactions (
    payment_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL,
    company_id UUID NOT NULL,
    payment_gateway_id UUID NOT NULL,

    transaction_type VARCHAR(30) NOT NULL DEFAULT 'AUTHORIZE',
    gateway_transaction_id VARCHAR(200) NULL,
    gateway_reference VARCHAR(200) NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    gateway_response_code VARCHAR(50) NULL,
    gateway_response_message TEXT NULL,
    gateway_response_data JSONB NULL,

    request_data JSONB NULL,
    response_data JSONB NULL,

    processed_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pt_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id) ON DELETE CASCADE,
    CONSTRAINT fk_pt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pt_gateway FOREIGN KEY (payment_gateway_id) REFERENCES payments.payment_gateways(payment_gateway_id),
    CONSTRAINT fk_pt_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_pt_type CHECK (transaction_type IN ('AUTHORIZE', 'CAPTURE', 'REFUND', 'VOID', 'VERIFY', 'WEBHOOK', 'RETRY')),
    CONSTRAINT ck_pt_status CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'EXPIRED'))
);

CREATE INDEX ix_pt_payment ON payments.payment_transactions(payment_id);
CREATE INDEX ix_pt_gateway_txn ON payments.payment_transactions(gateway_transaction_id);
CREATE INDEX ix_pt_status ON payments.payment_transactions(status);

-- ============================================================
-- 09.7 PAYMENT REFUNDS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_refunds (
    payment_refund_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL,
    company_id UUID NOT NULL,
    order_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    payment_gateway_id UUID NULL,

    refund_number VARCHAR(50) NOT NULL,
    refund_date DATE NOT NULL DEFAULT CURRENT_DATE,

    refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    refund_reason TEXT NULL,
    refund_type VARCHAR(30) NOT NULL DEFAULT 'FULL',

    -- Gateway refund info
    gateway_refund_id VARCHAR(200) NULL,
    gateway_refund_status VARCHAR(50) NULL,
    gateway_response_code VARCHAR(50) NULL,
    gateway_response_message TEXT NULL,

    -- Status tracking
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    initiated_at TIMESTAMPTZ NULL,
    processed_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    failed_at TIMESTAMPTZ NULL,

    -- Approval
    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    approval_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pr_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id),
    CONSTRAINT fk_pr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pr_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_pr_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_pr_gateway FOREIGN KEY (payment_gateway_id) REFERENCES payments.payment_gateways(payment_gateway_id),
    CONSTRAINT fk_pr_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_refund_number UNIQUE (company_id, refund_number),
    CONSTRAINT ck_pr_amount CHECK (refund_amount > 0),
    CONSTRAINT ck_pr_type CHECK (refund_type IN ('FULL', 'PARTIAL')),
    CONSTRAINT ck_pr_status CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED'))
);

CREATE INDEX ix_pr_payment ON payments.payment_refunds(payment_id);
CREATE INDEX ix_pr_order ON payments.payment_refunds(order_id);
CREATE INDEX ix_pr_status ON payments.payment_refunds(status);
CREATE INDEX ix_pr_date ON payments.payment_refunds(refund_date);

-- ============================================================
-- 09.8 PAYMENT RECONCILIATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_reconciliations (
    payment_reconciliation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    payment_gateway_id UUID NULL,
    payment_method_id UUID NULL,

    reconciliation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reconciliation_batch VARCHAR(100) NULL,

    expected_count INTEGER NOT NULL DEFAULT 0,
    matched_count INTEGER NOT NULL DEFAULT 0,
    unmatched_count INTEGER NOT NULL DEFAULT 0,
    discrepancy_count INTEGER NOT NULL DEFAULT 0,

    expected_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    matched_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    unmatched_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discrepancy_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    reconciled_by_user_id UUID NULL,
    reconciled_at TIMESTAMPTZ NULL,
    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_prec_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_prec_gateway FOREIGN KEY (payment_gateway_id) REFERENCES payments.payment_gateways(payment_gateway_id),
    CONSTRAINT fk_prec_method FOREIGN KEY (payment_method_id) REFERENCES payments.payment_methods(payment_method_id),
    CONSTRAINT fk_prec_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_prec_status CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'DISPUTED', 'CLOSED'))
);

CREATE INDEX ix_prec_company ON payments.payment_reconciliations(company_id);
CREATE INDEX ix_prec_date ON payments.payment_reconciliations(reconciliation_date);
CREATE INDEX ix_prec_status ON payments.payment_reconciliations(status);

-- ============================================================
-- 09.9 PAYMENT WEBHOOKS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_webhooks (
    payment_webhook_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    payment_gateway_id UUID NOT NULL,
    payment_id UUID NULL,

    webhook_type VARCHAR(100) NOT NULL,
    gateway_event_id VARCHAR(200) NULL,

    payload JSONB NULL,
    signature VARCHAR(500) NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
    processed_at TIMESTAMPTZ NULL,
    error_message TEXT NULL,

    retry_count INTEGER NOT NULL DEFAULT 0,
    next_retry_at TIMESTAMPTZ NULL,

    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pw_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pw_gateway FOREIGN KEY (payment_gateway_id) REFERENCES payments.payment_gateways(payment_gateway_id),
    CONSTRAINT fk_pw_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id),
    CONSTRAINT ck_pw_status CHECK (status IN ('RECEIVED', 'PROCESSING', 'PROCESSED', 'FAILED', 'IGNORED'))
);

CREATE INDEX ix_pw_company ON payments.payment_webhooks(company_id);
CREATE INDEX ix_pw_gateway ON payments.payment_webhooks(payment_gateway_id);
CREATE INDEX ix_pw_status ON payments.payment_webhooks(status);
CREATE INDEX ix_pw_received ON payments.payment_webhooks(received_at);

-- ============================================================
-- 09.10 PAYMENT SPLITS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_splits (
    payment_split_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    split_type VARCHAR(30) NOT NULL DEFAULT 'MERCHANT',
    recipient_type VARCHAR(30) NOT NULL DEFAULT 'MERCHANT',
    recipient_id UUID NULL,
    recipient_name VARCHAR(200) NULL,

    split_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    split_percent NUMERIC(5,2) NULL,
    currency_id UUID NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    settled_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ps_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id) ON DELETE CASCADE,
    CONSTRAINT fk_ps_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ps_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_ps_split_type CHECK (split_type IN ('MERCHANT', 'SELLER', 'PLATFORM_FEE', 'SHIPPING', 'TAX', 'OTHER')),
    CONSTRAINT ck_ps_recipient CHECK (recipient_type IN ('MERCHANT', 'SELLER', 'PLATFORM', 'COURIER', 'OTHER')),
    CONSTRAINT ck_ps_status CHECK (status IN ('PENDING', 'PROCESSING', 'SETTLED', 'FAILED')),
    CONSTRAINT ck_ps_amount CHECK (split_amount >= 0)
);

CREATE INDEX ix_ps_payment ON payments.payment_splits(payment_id);

-- ============================================================
-- 09.11 PAYMENT SETTLEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_settlements (
    payment_settlement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    payment_gateway_id UUID NOT NULL,

    settlement_batch_id VARCHAR(200) NOT NULL,
    settlement_date DATE NOT NULL DEFAULT CURRENT_DATE,

    gross_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    processing_fees NUMERIC(19,4) NOT NULL DEFAULT 0,
    net_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    transaction_count INTEGER NOT NULL DEFAULT 0,
    refund_count INTEGER NOT NULL DEFAULT 0,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    settled_at TIMESTAMPTZ NULL,

    bank_reference VARCHAR(200) NULL,
    bank_account_last_four VARCHAR(10) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pset_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pset_gateway FOREIGN KEY (payment_gateway_id) REFERENCES payments.payment_gateways(payment_gateway_id),
    CONSTRAINT fk_pset_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_settlement_batch UNIQUE (company_id, settlement_batch_id),
    CONSTRAINT ck_pset_status CHECK (status IN ('PENDING', 'PROCESSING', 'SETTLED', 'FAILED', 'DISPUTED')),
    CONSTRAINT ck_pset_amounts CHECK (gross_amount >= 0 AND processing_fees >= 0 AND net_amount >= 0)
);

CREATE INDEX ix_pset_company ON payments.payment_settlements(company_id);
CREATE INDEX ix_pset_gateway ON payments.payment_settlements(payment_gateway_id);
CREATE INDEX ix_pset_date ON payments.payment_settlements(settlement_date);
CREATE INDEX ix_pset_status ON payments.payment_settlements(status);

-- ============================================================
-- 09.12 PAYMENT RETRIES
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_retries (
    payment_retry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    retry_number INTEGER NOT NULL DEFAULT 1,
    retry_reason TEXT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED',
    scheduled_at TIMESTAMPTZ NULL,
    attempted_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,

    gateway_response_code VARCHAR(50) NULL,
    gateway_response_message TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_prt_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id) ON DELETE CASCADE,
    CONSTRAINT fk_prt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_prt_status CHECK (status IN ('SCHEDULED', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED'))
);

CREATE INDEX ix_prt_payment ON payments.payment_retries(payment_id);
CREATE INDEX ix_prt_status ON payments.payment_retries(status);

-- ============================================================
-- 09.13 PAYMENT JOURNAL ENTRIES (Accounting)
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_journal_entries (
    payment_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    payment_id UUID NULL,
    payment_refund_id UUID NULL,
    journal_entry_id UUID NULL,

    posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
    debit_account_id UUID NULL,
    credit_account_id UUID NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pje_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pje_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id),
    CONSTRAINT fk_pje_refund FOREIGN KEY (payment_refund_id) REFERENCES payments.payment_refunds(payment_refund_id),
    CONSTRAINT fk_pje_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_pje_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_pje_payment ON payments.payment_journal_entries(payment_id);
CREATE INDEX ix_pje_refund ON payments.payment_journal_entries(payment_refund_id);

-- ============================================================
-- 09.14 PAYMENT STATUS HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS payments.payment_status_history (
    payment_status_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    from_status_id UUID NULL,
    to_status_id UUID NOT NULL,

    status_notes TEXT NULL,
    changed_by_user_id UUID NULL,
    gateway_response_code VARCHAR(50) NULL,

    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_psh_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id) ON DELETE CASCADE,
    CONSTRAINT fk_psh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_psh_from_status FOREIGN KEY (from_status_id) REFERENCES payments.payment_status_lookup(payment_status_id),
    CONSTRAINT fk_psh_to_status FOREIGN KEY (to_status_id) REFERENCES payments.payment_status_lookup(payment_status_id)
);

CREATE INDEX ix_psh_payment ON payments.payment_status_history(payment_id);
CREATE INDEX ix_psh_changed ON payments.payment_status_history(changed_at);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_currency_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;

    -- Seed payment methods
    INSERT INTO payments.payment_methods (company_id, method_code, method_name, description, method_type, requires_gateway, display_order) VALUES
        (v_company_id, 'CASH', 'Cash', 'Cash payment.', 'OFFLINE', FALSE, 10),
        (v_company_id, 'COD', 'Cash on Delivery', 'Cash on delivery.', 'COD', FALSE, 20),
        (v_company_id, 'CARD', 'Credit/Debit Card', 'Credit or debit card payment.', 'CARD', TRUE, 30),
        (v_company_id, 'BANK_TRANSFER', 'Bank Transfer', 'Direct bank transfer.', 'BANK', FALSE, 40),
        (v_company_id, 'WALLET', 'Digital Wallet', 'Digital wallet payment (JazzCash, EasyPaisa).', 'WALLET', TRUE, 50),
        (v_company_id, 'CRYPTO', 'Cryptocurrency', 'Cryptocurrency payment.', 'CRYPTO', TRUE, 60)
    ON CONFLICT (company_id, method_code) DO UPDATE SET method_name = EXCLUDED.method_name;

    -- Seed payment gateways
    INSERT INTO payments.payment_gateways (company_id, gateway_code, gateway_name, description, gateway_type, is_test_mode) VALUES
        (v_company_id, 'STRIPE', 'Stripe', 'Stripe payment gateway.', 'ONLINE', FALSE),
        (v_company_id, 'JAZZCASH', 'JazzCash', 'JazzCash mobile wallet.', 'WALLET', FALSE),
        (v_company_id, 'EASYPAISA', 'EasyPaisa', 'EasyPaisa mobile wallet.', 'WALLET', FALSE),
        (v_company_id, 'PAYFAST', 'PayFast', 'PayFast payment gateway.', 'ONLINE', FALSE)
    ON CONFLICT (company_id, gateway_code) DO UPDATE SET gateway_name = EXCLUDED.gateway_name;

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 09 Payments
-- 14 Tables + 3 Lookup Tables + Seed Data
-- ============================================================