BEGIN;

-- ============================================================
-- MODULE 13 — ACCOUNTING / GENERAL LEDGER
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   Operational modules record business events;
--   Accounting converts those events into financial entries.
--   Users do NOT manually create entries for every sale/purchase.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS accounting;

-- ============================================================
-- 13.1 ACCOUNT TYPES
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.account_type_lookup (
    account_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    normal_balance VARCHAR(10) NOT NULL DEFAULT 'DEBIT',
    is_balance_sheet BOOLEAN NOT NULL DEFAULT TRUE,
    is_profit_and_loss BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT ck_at_balance CHECK (normal_balance IN ('DEBIT', 'CREDIT'))
);

INSERT INTO accounting.account_type_lookup (code, name, normal_balance, is_balance_sheet, is_profit_and_loss, sort_order) VALUES
    ('ASSET', 'Asset', 'DEBIT', TRUE, FALSE, 10),
    ('LIABILITY', 'Liability', 'CREDIT', TRUE, FALSE, 20),
    ('EQUITY', 'Equity', 'CREDIT', TRUE, FALSE, 30),
    ('REVENUE', 'Revenue', 'CREDIT', FALSE, TRUE, 40),
    ('COGS', 'Cost of Goods Sold', 'DEBIT', FALSE, TRUE, 50),
    ('EXPENSE', 'Expense', 'DEBIT', FALSE, TRUE, 60),
    ('OTHER_INCOME', 'Other Income', 'CREDIT', FALSE, TRUE, 70),
    ('OTHER_EXPENSE', 'Other Expense', 'DEBIT', FALSE, TRUE, 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- ============================================================
-- 13.2 CHART OF ACCOUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    account_type_id UUID NOT NULL,
    parent_account_id UUID NULL,

    account_code VARCHAR(50) NOT NULL,
    account_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    normal_balance VARCHAR(10) NOT NULL DEFAULT 'DEBIT',
    is_posting_account BOOLEAN NOT NULL DEFAULT TRUE,
    is_system_account BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    opening_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_acc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_acc_type FOREIGN KEY (account_type_id) REFERENCES accounting.account_type_lookup(account_type_id),
    CONSTRAINT fk_acc_parent FOREIGN KEY (parent_account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT fk_acc_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_account_code UNIQUE (company_id, account_code),
    CONSTRAINT ck_acc_balance CHECK (normal_balance IN ('DEBIT', 'CREDIT'))
);

CREATE INDEX ix_acc_company ON accounting.accounts(company_id);
CREATE INDEX ix_acc_type ON accounting.accounts(account_type_id);
CREATE INDEX ix_acc_parent ON accounting.accounts(parent_account_id);
CREATE INDEX ix_acc_active ON accounting.accounts(is_active);

-- ============================================================
-- 13.3 FISCAL YEARS & PERIODS
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.fiscal_years (
    fiscal_year_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    fiscal_year_code VARCHAR(20) NOT NULL,
    fiscal_year_name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    closed_at TIMESTAMPTZ NULL,
    closed_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fy_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_fy_code UNIQUE (company_id, fiscal_year_code),
    CONSTRAINT ck_fy_dates CHECK (end_date >= start_date)
);

CREATE INDEX ix_fy_company ON accounting.fiscal_years(company_id);
CREATE INDEX ix_fy_current ON accounting.fiscal_years(is_current);

CREATE TABLE IF NOT EXISTS accounting.fiscal_periods (
    fiscal_period_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fiscal_year_id UUID NOT NULL,
    company_id UUID NOT NULL,

    period_code VARCHAR(20) NOT NULL,
    period_name VARCHAR(100) NOT NULL,
    period_number INTEGER NOT NULL,

    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    is_adjustment_period BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fp_year FOREIGN KEY (fiscal_year_id) REFERENCES accounting.fiscal_years(fiscal_year_id) ON DELETE CASCADE,
    CONSTRAINT fk_fp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_fp_code UNIQUE (fiscal_year_id, period_code),
    CONSTRAINT ck_fp_dates CHECK (end_date >= start_date)
);

CREATE INDEX ix_fp_year ON accounting.fiscal_periods(fiscal_year_id);
CREATE INDEX ix_fp_company ON accounting.fiscal_periods(company_id);

-- ============================================================
-- 13.4 JOURNAL ENTRIES
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.journal_entries (
    journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    fiscal_year_id UUID NULL,
    fiscal_period_id UUID NULL,

    entry_number VARCHAR(50) NOT NULL,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    posting_date DATE NULL,
    description TEXT NULL,
    reference VARCHAR(200) NULL,

    source_type VARCHAR(50) NULL,
    source_id UUID NULL,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    debit_total NUMERIC(19,4) NOT NULL DEFAULT 0,
    credit_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    is_reversal BOOLEAN NOT NULL DEFAULT FALSE,
    reversed_journal_entry_id UUID NULL,

    approved_at TIMESTAMPTZ NULL,
    approved_by_user_id UUID NULL,
    posted_at TIMESTAMPTZ NULL,
    posted_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_je_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_je_fiscal_year FOREIGN KEY (fiscal_year_id) REFERENCES accounting.fiscal_years(fiscal_year_id),
    CONSTRAINT fk_je_fiscal_period FOREIGN KEY (fiscal_period_id) REFERENCES accounting.fiscal_periods(fiscal_period_id),
    CONSTRAINT fk_je_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_je_reversed FOREIGN KEY (reversed_journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT uq_entry_number UNIQUE (company_id, entry_number),
    CONSTRAINT ck_je_status CHECK (status IN ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'POSTED', 'REVERSED', 'CANCELLED')),
    CONSTRAINT ck_je_totals CHECK (debit_total >= 0 AND credit_total >= 0)
);

CREATE INDEX ix_je_company ON accounting.journal_entries(company_id);
CREATE INDEX ix_je_fiscal_year ON accounting.journal_entries(fiscal_year_id);
CREATE INDEX ix_je_date ON accounting.journal_entries(entry_date);
CREATE INDEX ix_je_status ON accounting.journal_entries(status);
CREATE INDEX ix_je_source ON accounting.journal_entries(source_type, source_id);

-- ============================================================
-- 13.5 JOURNAL ENTRY LINES
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.journal_entry_lines (
    journal_entry_line_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_entry_id UUID NOT NULL,
    account_id UUID NOT NULL,
    company_id UUID NOT NULL,

    line_number INTEGER NOT NULL DEFAULT 1,
    description TEXT NULL,
    reference VARCHAR(200) NULL,

    debit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    credit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,
    base_debit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    base_credit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    dimension_1 VARCHAR(100) NULL,
    dimension_2 VARCHAR(100) NULL,
    dimension_3 VARCHAR(100) NULL,
    cost_center_id UUID NULL,
    department_id UUID NULL,
    business_unit_id UUID NULL,
    project_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_jel_entry FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id) ON DELETE CASCADE,
    CONSTRAINT fk_jel_account FOREIGN KEY (account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT fk_jel_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_jel_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_jel_department FOREIGN KEY (department_id) REFERENCES organization.departments(department_id),
    CONSTRAINT fk_jel_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT ck_jel_amounts CHECK (debit_amount >= 0 AND credit_amount >= 0),
    CONSTRAINT ck_jel_not_both CHECK (NOT (debit_amount > 0 AND credit_amount > 0))
);

CREATE INDEX ix_jel_entry ON accounting.journal_entry_lines(journal_entry_id);
CREATE INDEX ix_jel_account ON accounting.journal_entry_lines(account_id);
CREATE INDEX ix_jel_company ON accounting.journal_entry_lines(company_id);

-- ============================================================
-- 13.6 ACCOUNTING MAPPINGS (Event → Account Mapping)
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.accounting_mappings (
    accounting_mapping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    transaction_type VARCHAR(50) NOT NULL,
    product_type_id UUID NULL,
    product_category_id UUID NULL,
    business_unit_id UUID NULL,
    tax_category_id UUID NULL,

    debit_account_id UUID NOT NULL,
    credit_account_id UUID NOT NULL,
    tax_account_id UUID NULL,

    description TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    priority INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_am_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_am_debit FOREIGN KEY (debit_account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT fk_am_credit FOREIGN KEY (credit_account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT fk_am_tax FOREIGN KEY (tax_account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT fk_am_category FOREIGN KEY (product_category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT ck_am_type CHECK (transaction_type IN (
        'SALE_COMPLETED', 'SALE_RETURNED', 'PAYMENT_RECEIVED', 'PAYMENT_REFUNDED',
        'PURCHASE_RECEIVED', 'SUPPLIER_INVOICE_POSTED', 'SUPPLIER_PAYMENT_MADE',
        'STOCK_ADJUSTED', 'STOCK_DAMAGED', 'STOCK_RETURNEED',
        'EXPENSE_POSTED', 'EXPENSE_PAID',
        'COD_COLLECTED', 'COD_SETTLED',
        'TAX_ASSESSED', 'TAX_PAID',
        'ASSET_PURCHASED', 'DEPRECIATION_POSTED',
        'CREDIT_NOTE_ISSUED', 'DEBIT_NOTE_ISSUED',
        'INVENTORY_SALE', 'INVENTORY_RECEIPT'
    ))
);

CREATE INDEX ix_am_company ON accounting.accounting_mappings(company_id);
CREATE INDEX ix_am_type ON accounting.accounting_mappings(transaction_type);

-- ============================================================
-- 13.7 ACCOUNTING EVENTS (Domain Event → Journal Entry)
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.accounting_events (
    accounting_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    journal_entry_id UUID NULL,

    event_type VARCHAR(50) NOT NULL,
    source_type VARCHAR(50) NOT NULL,
    source_id UUID NOT NULL,

    event_data JSONB NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    error_message TEXT NULL,

    processed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ae_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ae_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT ck_ae_status CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'SKIPPED'))
);

CREATE INDEX ix_ae_company ON accounting.accounting_events(company_id);
CREATE INDEX ix_ae_source ON accounting.accounting_events(source_type, source_id);
CREATE INDEX ix_ae_status ON accounting.accounting_events(status);

-- ============================================================
-- 13.8 INVOICES (AR/AP)
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.invoices (
    invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NULL,
    supplier_id UUID NULL,

    invoice_number VARCHAR(50) NOT NULL,
    invoice_type VARCHAR(20) NOT NULL DEFAULT 'SALES',
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NULL,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    subtotal_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    outstanding_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',

    order_id UUID NULL,
    purchase_order_id UUID NULL,
    journal_entry_id UUID NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_inv_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_inv_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_inv_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_inv_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_inv_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT uq_invoice_number UNIQUE (company_id, invoice_number),
    CONSTRAINT ck_inv_type CHECK (invoice_type IN ('SALES', 'PURCHASE', 'CREDIT_NOTE', 'DEBIT_NOTE')),
    CONSTRAINT ck_inv_status CHECK (status IN ('DRAFT', 'OPEN', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED', 'VOID')),
    CONSTRAINT ck_inv_amounts CHECK (total_amount >= 0 AND paid_amount >= 0 AND outstanding_amount >= 0)
);

CREATE INDEX ix_inv_company ON accounting.invoices(company_id);
CREATE INDEX ix_inv_customer ON accounting.invoices(customer_id);
CREATE INDEX ix_inv_supplier ON accounting.invoices(supplier_id);
CREATE INDEX ix_inv_status ON accounting.invoices(status);
CREATE INDEX ix_inv_due ON accounting.invoices(due_date);

-- Invoice Lines
CREATE TABLE IF NOT EXISTS accounting.invoice_lines (
    invoice_line_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL,
    company_id UUID NOT NULL,

    line_number INTEGER NOT NULL DEFAULT 1,
    description TEXT NOT NULL,
    product_id UUID NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    account_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_il_invoice FOREIGN KEY (invoice_id) REFERENCES accounting.invoices(invoice_id) ON DELETE CASCADE,
    CONSTRAINT fk_il_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_il_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_il_account FOREIGN KEY (account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT ck_il_amounts CHECK (quantity >= 0 AND unit_price >= 0 AND line_total >= 0)
);

CREATE INDEX ix_il_invoice ON accounting.invoice_lines(invoice_id);

-- ============================================================
-- 13.9 BANK ACCOUNTS & TRANSACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.bank_accounts (
    bank_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    account_id UUID NOT NULL,

    bank_name VARCHAR(200) NOT NULL,
    branch_name VARCHAR(200) NULL,
    account_number VARCHAR(100) NOT NULL,
    account_title VARCHAR(200) NULL,
    iban VARCHAR(50) NULL,
    swift_code VARCHAR(20) NULL,

    currency_id UUID NOT NULL,
    opening_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    current_balance NUMERIC(19,4) NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ba_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ba_account FOREIGN KEY (account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT fk_ba_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_bank_account UNIQUE (company_id, account_number)
);

CREATE INDEX ix_ba_company ON accounting.bank_accounts(company_id);

CREATE TABLE IF NOT EXISTS accounting.bank_transactions (
    bank_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_account_id UUID NOT NULL,
    company_id UUID NOT NULL,

    transaction_date DATE NOT NULL,
    reference VARCHAR(200) NULL,
    description TEXT NULL,

    debit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    credit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    balance_after NUMERIC(19,4) NULL,

    external_reference VARCHAR(200) NULL,
    reconciliation_status VARCHAR(20) NOT NULL DEFAULT 'UNRECONCILED',

    imported_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bt_account FOREIGN KEY (bank_account_id) REFERENCES accounting.bank_accounts(bank_account_id) ON DELETE CASCADE,
    CONSTRAINT fk_bt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_bt_amounts CHECK (debit_amount >= 0 AND credit_amount >= 0),
    CONSTRAINT ck_bt_reconciliation CHECK (reconciliation_status IN ('UNRECONCILED', 'MATCHED', 'RECONCILED', 'DISPUTED'))
);

CREATE INDEX ix_bt_account ON accounting.bank_transactions(bank_account_id);
CREATE INDEX ix_bt_date ON accounting.bank_transactions(transaction_date);
CREATE INDEX ix_bt_reconciliation ON accounting.bank_transactions(reconciliation_status);

-- ============================================================
-- 13.10 BANK RECONCILIATION
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.bank_reconciliations (
    bank_reconciliation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_account_id UUID NOT NULL,
    company_id UUID NOT NULL,

    statement_date DATE NOT NULL,
    statement_opening_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    statement_closing_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    system_closing_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    difference NUMERIC(19,4) NOT NULL DEFAULT 0,

    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',

    reconciled_by_user_id UUID NULL,
    reconciled_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_br_account FOREIGN KEY (bank_account_id) REFERENCES accounting.bank_accounts(bank_account_id),
    CONSTRAINT fk_br_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_br_status CHECK (status IN ('IN_PROGRESS', 'RECONCILED', 'DISPUTED', 'CANCELLED'))
);

CREATE INDEX ix_br_account ON accounting.bank_reconciliations(bank_account_id);

CREATE TABLE IF NOT EXISTS accounting.bank_reconciliation_items (
    bank_reconciliation_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_reconciliation_id UUID NOT NULL,
    bank_transaction_id UUID NULL,
    matched_journal_entry_line_id UUID NULL,

    matched_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'MATCHED',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bri_reconciliation FOREIGN KEY (bank_reconciliation_id) REFERENCES accounting.bank_reconciliations(bank_reconciliation_id) ON DELETE CASCADE,
    CONSTRAINT fk_bri_transaction FOREIGN KEY (bank_transaction_id) REFERENCES accounting.bank_transactions(bank_transaction_id),
    CONSTRAINT fk_bri_journal_line FOREIGN KEY (matched_journal_entry_line_id) REFERENCES accounting.journal_entry_lines(journal_entry_line_id),
    CONSTRAINT ck_bri_status CHECK (status IN ('MATCHED', 'UNMATCHED', 'ADJUSTED'))
);

CREATE INDEX ix_bri_reconciliation ON accounting.bank_reconciliation_items(bank_reconciliation_id);

-- ============================================================
-- 13.11 ACCOUNTING DIMENSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.accounting_dimensions (
    dimension_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    dimension_code VARCHAR(50) NOT NULL,
    dimension_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ad_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_dimension UNIQUE (company_id, dimension_code)
);

CREATE INDEX ix_ad_company ON accounting.accounting_dimensions(company_id);

-- ============================================================
-- 13.12 ACCOUNT BALANCES (Read Model / Cache)
-- ============================================================

CREATE TABLE IF NOT EXISTS accounting.account_balances (
    account_balance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    account_id UUID NOT NULL,
    fiscal_year_id UUID NOT NULL,
    fiscal_period_id UUID NULL,

    opening_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    debit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    credit_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    closing_balance NUMERIC(19,4) NOT NULL DEFAULT 0,

    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ab_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ab_account FOREIGN KEY (account_id) REFERENCES accounting.accounts(account_id),
    CONSTRAINT fk_ab_year FOREIGN KEY (fiscal_year_id) REFERENCES accounting.fiscal_years(fiscal_year_id),
    CONSTRAINT fk_ab_period FOREIGN KEY (fiscal_period_id) REFERENCES accounting.fiscal_periods(fiscal_period_id),
    CONSTRAINT uq_account_balance UNIQUE (company_id, account_id, fiscal_year_id, fiscal_period_id)
);

CREATE INDEX ix_ab_company ON accounting.account_balances(company_id);
CREATE INDEX ix_ab_account ON accounting.account_balances(account_id);
CREATE INDEX ix_ab_year ON accounting.account_balances(fiscal_year_id);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_currency_id UUID;
    v_fy_id UUID;
    v_asset_type UUID;
    v_liability_type UUID;
    v_equity_type UUID;
    v_revenue_type UUID;
    v_cogs_type UUID;
    v_expense_type UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;

    SELECT account_type_id INTO v_asset_type FROM accounting.account_type_lookup WHERE code = 'ASSET';
    SELECT account_type_id INTO v_liability_type FROM accounting.account_type_lookup WHERE code = 'LIABILITY';
    SELECT account_type_id INTO v_equity_type FROM accounting.account_type_lookup WHERE code = 'EQUITY';
    SELECT account_type_id INTO v_revenue_type FROM accounting.account_type_lookup WHERE code = 'REVENUE';
    SELECT account_type_id INTO v_cogs_type FROM accounting.account_type_lookup WHERE code = 'COGS';
    SELECT account_type_id INTO v_expense_type FROM accounting.account_type_lookup WHERE code = 'EXPENSE';

    -- Chart of Accounts
    INSERT INTO accounting.accounts (company_id, account_type_id, account_code, account_name, normal_balance, is_posting_account, is_system_account, sort_order) VALUES
        -- Assets
        (v_company_id, v_asset_type, '1000', 'Cash', 'DEBIT', TRUE, TRUE, 10),
        (v_company_id, v_asset_type, '1100', 'Bank', 'DEBIT', TRUE, TRUE, 20),
        (v_company_id, v_asset_type, '1200', 'Accounts Receivable', 'DEBIT', TRUE, TRUE, 30),
        (v_company_id, v_asset_type, '1300', 'Inventory', 'DEBIT', TRUE, TRUE, 40),
        (v_company_id, v_asset_type, '1400', 'Fixed Assets', 'DEBIT', TRUE, TRUE, 50),
        -- Liabilities
        (v_company_id, v_liability_type, '2000', 'Accounts Payable', 'CREDIT', TRUE, TRUE, 60),
        (v_company_id, v_liability_type, '2100', 'Sales Tax Payable', 'CREDIT', TRUE, TRUE, 70),
        (v_company_id, v_liability_type, '2200', 'Income Tax Payable', 'CREDIT', TRUE, TRUE, 80),
        (v_company_id, v_liability_type, '2300', 'Expense Payable', 'CREDIT', TRUE, TRUE, 90),
        -- Equity
        (v_company_id, v_equity_type, '3000', 'Capital', 'CREDIT', TRUE, TRUE, 100),
        (v_company_id, v_equity_type, '3100', 'Retained Earnings', 'CREDIT', TRUE, TRUE, 110),
        -- Revenue
        (v_company_id, v_revenue_type, '4000', 'Revenue', 'CREDIT', FALSE, TRUE, 120),
        (v_company_id, v_revenue_type, '4100', 'Product Sales', 'CREDIT', TRUE, TRUE, 130),
        (v_company_id, v_revenue_type, '4200', 'Shipping Revenue', 'CREDIT', TRUE, TRUE, 140),
        -- COGS
        (v_company_id, v_cogs_type, '5000', 'Cost of Goods Sold', 'DEBIT', FALSE, TRUE, 150),
        (v_company_id, v_cogs_type, '5100', 'Product COGS', 'DEBIT', TRUE, TRUE, 160),
        -- Expenses
        (v_company_id, v_expense_type, '6000', 'Expenses', 'DEBIT', FALSE, TRUE, 170),
        (v_company_id, v_expense_type, '6100', 'Salaries', 'DEBIT', TRUE, TRUE, 180),
        (v_company_id, v_expense_type, '6200', 'Rent', 'DEBIT', TRUE, TRUE, 190),
        (v_company_id, v_expense_type, '6300', 'Utilities', 'DEBIT', TRUE, TRUE, 200),
        (v_company_id, v_expense_type, '6400', 'Marketing', 'DEBIT', TRUE, TRUE, 210),
        (v_company_id, v_expense_type, '6500', 'Office Supplies', 'DEBIT', TRUE, TRUE, 220)
    ON CONFLICT (company_id, account_code) DO UPDATE SET account_name = EXCLUDED.account_name;

    -- Fiscal Year
    INSERT INTO accounting.fiscal_years (company_id, fiscal_year_code, fiscal_year_name, start_date, end_date, is_current)
    SELECT v_company_id, 'FY-2026', 'Fiscal Year 2026', '2026-01-01', '2026-12-31', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM accounting.fiscal_years WHERE company_id = v_company_id AND fiscal_year_code = 'FY-2026')
    RETURNING fiscal_year_id INTO v_fy_id;

    IF v_fy_id IS NULL THEN
        SELECT fiscal_year_id INTO v_fy_id FROM accounting.fiscal_years WHERE company_id = v_company_id AND fiscal_year_code = 'FY-2026';
    END IF;

    -- Fiscal Periods (12 months)
    INSERT INTO accounting.fiscal_periods (fiscal_year_id, company_id, period_code, period_name, period_number, start_date, end_date)
    SELECT v_fy_id, v_company_id, 'P' || LPAD(m::TEXT, 2, '0'), 'Month ' || m, m,
           ('2026-' || LPAD(m::TEXT, 2, '0') || '-01')::DATE,
           (('2026-' || LPAD(m::TEXT, 2, '0') || '-01')::DATE + INTERVAL '1 month' - INTERVAL '1 day')::DATE
    FROM generate_series(1, 12) AS m
    ON CONFLICT (fiscal_year_id, period_code) DO NOTHING;

    -- Accounting Mappings
    INSERT INTO accounting.accounting_mappings (company_id, transaction_type, debit_account_id, credit_account_id, tax_account_id, description)
    SELECT v_company_id, 'SALE_COMPLETED',
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '1200'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '4100'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '2100'),
           'Sales revenue recognition'
    WHERE NOT EXISTS (SELECT 1 FROM accounting.accounting_mappings WHERE company_id = v_company_id AND transaction_type = 'SALE_COMPLETED');

    INSERT INTO accounting.accounting_mappings (company_id, transaction_type, debit_account_id, credit_account_id, description)
    SELECT v_company_id, 'INVENTORY_SALE',
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '5100'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '1300'),
           'COGS recognition on sale'
    WHERE NOT EXISTS (SELECT 1 FROM accounting.accounting_mappings WHERE company_id = v_company_id AND transaction_type = 'INVENTORY_SALE');

    INSERT INTO accounting.accounting_mappings (company_id, transaction_type, debit_account_id, credit_account_id, description)
    SELECT v_company_id, 'PAYMENT_RECEIVED',
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '1100'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '1200'),
           'Customer payment received'
    WHERE NOT EXISTS (SELECT 1 FROM accounting.accounting_mappings WHERE company_id = v_company_id AND transaction_type = 'PAYMENT_RECEIVED');

    INSERT INTO accounting.accounting_mappings (company_id, transaction_type, debit_account_id, credit_account_id, description)
    SELECT v_company_id, 'EXPENSE_POSTED',
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '6000'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '2300'),
           'Expense recognition'
    WHERE NOT EXISTS (SELECT 1 FROM accounting.accounting_mappings WHERE company_id = v_company_id AND transaction_type = 'EXPENSE_POSTED');

    INSERT INTO accounting.accounting_mappings (company_id, transaction_type, debit_account_id, credit_account_id, description)
    SELECT v_company_id, 'EXPENSE_PAID',
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '2300'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '1100'),
           'Expense payment'
    WHERE NOT EXISTS (SELECT 1 FROM accounting.accounting_mappings WHERE company_id = v_company_id AND transaction_type = 'EXPENSE_PAID');

    INSERT INTO accounting.accounting_mappings (company_id, transaction_type, debit_account_id, credit_account_id, description)
    SELECT v_company_id, 'PURCHASE_RECEIVED',
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '1300'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '2000'),
           'Purchase goods received'
    WHERE NOT EXISTS (SELECT 1 FROM accounting.accounting_mappings WHERE company_id = v_company_id AND transaction_type = 'PURCHASE_RECEIVED');

    INSERT INTO accounting.accounting_mappings (company_id, transaction_type, debit_account_id, credit_account_id, description)
    SELECT v_company_id, 'SUPPLIER_PAYMENT_MADE',
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '2000'),
           (SELECT account_id FROM accounting.accounts WHERE company_id = v_company_id AND account_code = '1100'),
           'Supplier payment made'
    WHERE NOT EXISTS (SELECT 1 FROM accounting.accounting_mappings WHERE company_id = v_company_id AND transaction_type = 'SUPPLIER_PAYMENT_MADE');

END $$;

COMMIT;