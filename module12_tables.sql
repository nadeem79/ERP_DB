BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 12 — POS / POINT OF SALE
-- DATABASE TABLES
-- ============================================================
-- Architecture Principle:
--   SALES CHANNELS (Website, POS, Mobile) → ORDER ENGINE →
--   Payment + Inventory + Fulfillment → Accounting
--   POS is NOT a separate order system.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS pos;

-- ============================================================
-- 12.1 POS TERMINALS / DEVICES
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_terminals (
    pos_terminal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    store_id UUID NOT NULL,

    terminal_code VARCHAR(50) NOT NULL,
    terminal_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    terminal_type VARCHAR(30) NOT NULL DEFAULT 'COUNTER',
    device_id VARCHAR(200) NULL,
    device_type VARCHAR(50) NULL,
    ip_address INET NULL,
    mac_address VARCHAR(50) NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'OFFLINE',
    last_seen_at TIMESTAMPTZ NULL,
    last_sale_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pt_store FOREIGN KEY (store_id) REFERENCES organization.stores(store_id),
    CONSTRAINT uq_terminal_code UNIQUE (company_id, terminal_code),
    CONSTRAINT ck_pt_type CHECK (terminal_type IN ('COUNTER', 'MOBILE', 'KIOSK', 'TABLET', 'WEB')),
    CONSTRAINT ck_pt_status CHECK (status IN ('ONLINE', 'OFFLINE', 'MAINTENANCE', 'DISABLED'))
);

CREATE INDEX ix_pt_company ON pos.pos_terminals(company_id);
CREATE INDEX ix_pt_store ON pos.pos_terminals(store_id);
CREATE INDEX ix_pt_status ON pos.pos_terminals(status);

-- ============================================================
-- 12.2 POS SHIFTS
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_shifts (
    pos_shift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    pos_terminal_id UUID NOT NULL,
    store_id UUID NOT NULL,

    shift_number VARCHAR(50) NOT NULL,
    shift_date DATE NOT NULL DEFAULT CURRENT_DATE,

    opened_by_user_id UUID NOT NULL,
    opened_by_employee_id UUID NULL,
    closed_by_user_id UUID NULL,
    closed_by_employee_id UUID NULL,

    opening_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    closing_amount NUMERIC(19,4) NULL,
    expected_amount NUMERIC(19,4) NULL,
    actual_amount NUMERIC(19,4) NULL,
    variance NUMERIC(19,4) NULL,

    currency_id UUID NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    opened_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMPTZ NULL,

    opening_notes TEXT NULL,
    closing_notes TEXT NULL,

    total_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_cash_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_card_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_other_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_refunds NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_discounts NUMERIC(19,4) NOT NULL DEFAULT 0,
    transaction_count INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ps_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ps_terminal FOREIGN KEY (pos_terminal_id) REFERENCES pos.pos_terminals(pos_terminal_id),
    CONSTRAINT fk_ps_store FOREIGN KEY (store_id) REFERENCES organization.stores(store_id),
    CONSTRAINT fk_ps_opened_by FOREIGN KEY (opened_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_ps_closed_by FOREIGN KEY (closed_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_ps_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_shift_number UNIQUE (company_id, shift_number),
    CONSTRAINT ck_ps_status CHECK (status IN ('OPEN', 'CLOSED', 'SUSPENDED', 'FORCE_CLOSED')),
    CONSTRAINT ck_ps_amounts CHECK (opening_amount >= 0 AND (closing_amount IS NULL OR closing_amount >= 0))
);

CREATE INDEX ix_ps_company ON pos.pos_shifts(company_id);
CREATE INDEX ix_ps_terminal ON pos.pos_shifts(pos_terminal_id);
CREATE INDEX ix_ps_store ON pos.pos_shifts(store_id);
CREATE INDEX ix_ps_status ON pos.pos_shifts(status);
CREATE INDEX ix_ps_date ON pos.pos_shifts(shift_date);

-- ============================================================
-- 12.3 POS SALES (Uses Unified Order Engine)
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_sales (
    pos_sale_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    pos_terminal_id UUID NOT NULL,
    pos_shift_id UUID NOT NULL,
    store_id UUID NOT NULL,

    order_id UUID NULL,

    sale_number VARCHAR(50) NOT NULL,
    sale_date DATE NOT NULL DEFAULT CURRENT_DATE,
    sale_time TIME NOT NULL DEFAULT CURRENT_TIME,

    customer_id UUID NULL,
    customer_name VARCHAR(200) NULL,
    customer_email VARCHAR(300) NULL,
    customer_phone VARCHAR(50) NULL,

    subtotal_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    shipping_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    grand_total NUMERIC(19,4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    change_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    status VARCHAR(30) NOT NULL DEFAULT 'COMPLETED',
    sale_type VARCHAR(20) NOT NULL DEFAULT 'SALE',

    cashier_user_id UUID NULL,
    cashier_employee_id UUID NULL,

    coupon_code VARCHAR(100) NULL,
    discount_reason TEXT NULL,

    notes TEXT NULL,

    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    suspended_at TIMESTAMPTZ NULL,
    resumed_at TIMESTAMPTZ NULL,

    is_voided BOOLEAN NOT NULL DEFAULT FALSE,
    voided_at TIMESTAMPTZ NULL,
    voided_by_user_id UUID NULL,
    void_reason TEXT NULL,

    receipt_number VARCHAR(50) NULL,
    receipt_printed BOOLEAN NOT NULL DEFAULT FALSE,
    receipt_printed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_psl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_psl_terminal FOREIGN KEY (pos_terminal_id) REFERENCES pos.pos_terminals(pos_terminal_id),
    CONSTRAINT fk_psl_shift FOREIGN KEY (pos_shift_id) REFERENCES pos.pos_shifts(pos_shift_id),
    CONSTRAINT fk_psl_store FOREIGN KEY (store_id) REFERENCES organization.stores(store_id),
    CONSTRAINT fk_psl_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_psl_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_psl_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_psl_cashier FOREIGN KEY (cashier_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_sale_number UNIQUE (company_id, sale_number),
    CONSTRAINT ck_psl_status CHECK (status IN ('DRAFT', 'COMPLETED', 'REFUNDED', 'PARTIALLY_REFUNDED', 'VOIDED', 'SUSPENDED')),
    CONSTRAINT ck_psl_type CHECK (sale_type IN ('SALE', 'RETURN', 'EXCHANGE')),
    CONSTRAINT ck_psl_amounts CHECK (grand_total >= 0 AND paid_amount >= 0 AND change_amount >= 0)
);

CREATE INDEX ix_psl_company ON pos.pos_sales(company_id);
CREATE INDEX ix_psl_terminal ON pos.pos_sales(pos_terminal_id);
CREATE INDEX ix_psl_shift ON pos.pos_sales(pos_shift_id);
CREATE INDEX ix_psl_store ON pos.pos_sales(store_id);
CREATE INDEX ix_psl_order ON pos.pos_sales(order_id);
CREATE INDEX ix_psl_customer ON pos.pos_sales(customer_id);
CREATE INDEX ix_psl_date ON pos.pos_sales(sale_date);
CREATE INDEX ix_psl_status ON pos.pos_sales(status);

-- ============================================================
-- 12.4 POS SALE ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_sale_items (
    pos_sale_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pos_sale_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    product_name VARCHAR(300) NOT NULL,
    sku VARCHAR(100) NULL,
    barcode VARCHAR(100) NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    warehouse_id UUID NULL,
    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,

    is_returned BOOLEAN NOT NULL DEFAULT FALSE,
    returned_quantity NUMERIC(19,4) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_psi_sale FOREIGN KEY (pos_sale_id) REFERENCES pos.pos_sales(pos_sale_id) ON DELETE CASCADE,
    CONSTRAINT fk_psi_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_psi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_psi_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_psi_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_psi_warehouse FOREIGN KEY (warehouse_id) REFERENCES organization.warehouses(warehouse_id),
    CONSTRAINT ck_psi_amounts CHECK (quantity >= 0 AND unit_price >= 0 AND line_total >= 0)
);

CREATE INDEX ix_psi_sale ON pos.pos_sale_items(pos_sale_id);
CREATE INDEX ix_psi_product ON pos.pos_sale_items(product_id);

-- ============================================================
-- 12.5 POS PAYMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_payments (
    pos_payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pos_sale_id UUID NOT NULL,
    company_id UUID NOT NULL,

    payment_method_id UUID NULL,
    payment_method_code VARCHAR(50) NOT NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    reference_number VARCHAR(200) NULL,
    card_last_four VARCHAR(10) NULL,
    card_type VARCHAR(30) NULL,
    card_holder_name VARCHAR(200) NULL,
    transaction_id VARCHAR(200) NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pp_sale FOREIGN KEY (pos_sale_id) REFERENCES pos.pos_sales(pos_sale_id) ON DELETE CASCADE,
    CONSTRAINT fk_pp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pp_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_pp_amount CHECK (amount >= 0),
    CONSTRAINT ck_pp_status CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'))
);

CREATE INDEX ix_pp_sale ON pos.pos_payments(pos_sale_id);
CREATE INDEX ix_pp_method ON pos.pos_payments(payment_method_code);

-- ============================================================
-- 12.6 POS CASH TRANSACTIONS (Cash Drawer)
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_cash_transactions (
    pos_cash_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    pos_shift_id UUID NOT NULL,
    pos_terminal_id UUID NOT NULL,

    transaction_type VARCHAR(30) NOT NULL,
    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    reference VARCHAR(200) NULL,
    description TEXT NULL,

    processed_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pct_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pct_shift FOREIGN KEY (pos_shift_id) REFERENCES pos.pos_shifts(pos_shift_id),
    CONSTRAINT fk_pct_terminal FOREIGN KEY (pos_terminal_id) REFERENCES pos.pos_terminals(pos_terminal_id),
    CONSTRAINT fk_pct_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_pct_user FOREIGN KEY (processed_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_pct_type CHECK (transaction_type IN (
        'OPENING_BALANCE', 'CASH_SALE', 'CASH_REFUND', 'CASH_IN', 'CASH_OUT',
        'PAYOUT', 'PICKUP', 'ADJUSTMENT', 'RECONCILIATION'
    )),
    CONSTRAINT ck_pct_amount CHECK (amount <> 0)
);

CREATE INDEX ix_pct_shift ON pos.pos_cash_transactions(pos_shift_id);
CREATE INDEX ix_pct_terminal ON pos.pos_cash_transactions(pos_terminal_id);
CREATE INDEX ix_pct_type ON pos.pos_cash_transactions(transaction_type);

-- ============================================================
-- 12.7 POS RETURNS
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_returns (
    pos_return_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    pos_terminal_id UUID NOT NULL,
    pos_shift_id UUID NULL,
    store_id UUID NOT NULL,
    original_pos_sale_id UUID NULL,
    return_request_id UUID NULL,

    return_number VARCHAR(50) NOT NULL,
    return_date DATE NOT NULL DEFAULT CURRENT_DATE,

    customer_id UUID NULL,
    customer_name VARCHAR(200) NULL,

    return_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    refund_method VARCHAR(30) NOT NULL DEFAULT 'CASH',
    return_reason TEXT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',

    processed_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pr_terminal FOREIGN KEY (pos_terminal_id) REFERENCES pos.pos_terminals(pos_terminal_id),
    CONSTRAINT fk_pr_shift FOREIGN KEY (pos_shift_id) REFERENCES pos.pos_shifts(pos_shift_id),
    CONSTRAINT fk_pr_store FOREIGN KEY (store_id) REFERENCES organization.stores(store_id),
    CONSTRAINT fk_pr_original FOREIGN KEY (original_pos_sale_id) REFERENCES pos.pos_sales(pos_sale_id),
    CONSTRAINT fk_pr_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_pr_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_pr_user FOREIGN KEY (processed_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_return_number UNIQUE (company_id, return_number),
    CONSTRAINT ck_pr_amounts CHECK (return_amount >= 0 AND refund_amount >= 0),
    CONSTRAINT ck_pr_refund_method CHECK (refund_method IN ('CASH', 'CARD', 'STORE_CREDIT', 'ORIGINAL_PAYMENT', 'EXCHANGE'))
);

CREATE INDEX ix_pr_company ON pos.pos_returns(company_id);
CREATE INDEX ix_pr_store ON pos.pos_returns(store_id);
CREATE INDEX ix_pr_original ON pos.pos_returns(original_pos_sale_id);

CREATE TABLE IF NOT EXISTS pos.pos_return_items (
    pos_return_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pos_return_id UUID NOT NULL,
    pos_sale_item_id UUID NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    product_name VARCHAR(300) NOT NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    return_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    return_reason TEXT NULL,
    condition VARCHAR(30) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pri_return FOREIGN KEY (pos_return_id) REFERENCES pos.pos_returns(pos_return_id) ON DELETE CASCADE,
    CONSTRAINT fk_pri_sale_item FOREIGN KEY (pos_sale_item_id) REFERENCES pos.pos_sale_items(pos_sale_item_id),
    CONSTRAINT fk_pri_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT ck_pri_amounts CHECK (quantity >= 0 AND unit_price >= 0 AND return_amount >= 0),
    CONSTRAINT ck_pri_condition CHECK (condition IS NULL OR condition IN ('NEW', 'DAMAGED', 'DEFECTIVE', 'WRONG_ITEM', 'OPENED'))
);

CREATE INDEX ix_pri_return ON pos.pos_return_items(pos_return_id);

-- ============================================================
-- 12.8 POS DISCOUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_sale_discounts (
    pos_sale_discount_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pos_sale_id UUID NOT NULL,
    company_id UUID NOT NULL,

    discount_type VARCHAR(30) NOT NULL,
    discount_code VARCHAR(100) NULL,
    description TEXT NULL,

    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_percent NUMERIC(5,2) NULL,

    applied_by_user_id UUID NULL,
    approved_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_psd_sale FOREIGN KEY (pos_sale_id) REFERENCES pos.pos_sales(pos_sale_id) ON DELETE CASCADE,
    CONSTRAINT fk_psd_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_psd_applied_by FOREIGN KEY (applied_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_psd_approved_by FOREIGN KEY (approved_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_psd_type CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'COUPON', 'MANUAL', 'PROMOTION')),
    CONSTRAINT ck_psd_amount CHECK (discount_amount >= 0)
);

CREATE INDEX ix_psd_sale ON pos.pos_sale_discounts(pos_sale_id);

-- ============================================================
-- 12.9 POS RECEIPT LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_receipt_log (
    pos_receipt_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pos_sale_id UUID NOT NULL,
    pos_terminal_id UUID NOT NULL,

    receipt_number VARCHAR(50) NOT NULL,
    print_status VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    printer_name VARCHAR(200) NULL,
    error_message TEXT NULL,

    printed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_prl_sale FOREIGN KEY (pos_sale_id) REFERENCES pos.pos_sales(pos_sale_id),
    CONSTRAINT fk_prl_terminal FOREIGN KEY (pos_terminal_id) REFERENCES pos.pos_terminals(pos_terminal_id),
    CONSTRAINT ck_prl_status CHECK (print_status IN ('SUCCESS', 'FAILED', 'RETRY'))
);

CREATE INDEX ix_prl_sale ON pos.pos_receipt_log(pos_sale_id);

-- ============================================================
-- 12.10 POS END OF DAY SUMMARY
-- ============================================================

CREATE TABLE IF NOT EXISTS pos.pos_end_of_day (
    pos_end_of_day_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    store_id UUID NOT NULL,
    pos_terminal_id UUID NULL,

    eod_date DATE NOT NULL DEFAULT CURRENT_DATE,

    total_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_cash_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_card_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_other_sales NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_refunds NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_discounts NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_voids NUMERIC(19,4) NOT NULL DEFAULT 0,

    transaction_count INTEGER NOT NULL DEFAULT 0,
    refund_count INTEGER NOT NULL DEFAULT 0,
    void_count INTEGER NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    cash_variance NUMERIC(19,4) NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_peod_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_peod_store FOREIGN KEY (store_id) REFERENCES organization.stores(store_id),
    CONSTRAINT fk_peod_terminal FOREIGN KEY (pos_terminal_id) REFERENCES pos.pos_terminals(pos_terminal_id),
    CONSTRAINT fk_peod_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_eod UNIQUE (company_id, store_id, COALESCE(pos_terminal_id, '00000000-0000-0000-0000-000000000000'::uuid), eod_date)
);

CREATE INDEX ix_peod_company ON pos.pos_end_of_day(company_id);
CREATE INDEX ix_peod_store ON pos.pos_end_of_day(store_id);
CREATE INDEX ix_peod_date ON pos.pos_end_of_day(eod_date);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_store_id UUID;
    v_currency_id UUID;
    v_terminal_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT store_id INTO v_store_id FROM organization.stores LIMIT 1;
    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;

    IF v_store_id IS NOT NULL THEN
        INSERT INTO pos.pos_terminals (company_id, store_id, terminal_code, terminal_name, terminal_type, status)
        SELECT v_company_id, v_store_id, 'POS-001', 'Main Counter Terminal', 'COUNTER', 'ONLINE'
        WHERE NOT EXISTS (SELECT 1 FROM pos.pos_terminals WHERE company_id = v_company_id AND terminal_code = 'POS-001')
        RETURNING pos_terminal_id INTO v_terminal_id;
    END IF;

END $$;

COMMIT;