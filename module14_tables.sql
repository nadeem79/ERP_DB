BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 14 — EXPENSE MANAGEMENT
-- DATABASE TABLES (RE-CREATION FROM EXISTING BACKUP)
-- ============================================================
-- Key Principle:
--   An expense is a business cost;
--   payment/reimbursement is a separate financial event.
-- ============================================================
-- Components:
--   14.1  Expense Categories
--   14.2  Expense Payment Methods
--   14.3  Expense Claims
--   14.4  Expense Claim Items
--   14.5  Expense Attachments
--   14.6  Expense Policies & Rules
--   14.7  Policy Violations
--   14.8  Approval Rules & Approvals
--   14.9  Expense Budgets & Periods
--   14.10 Reimbursements
--   14.11 Petty Cash Accounts & Transactions
--   14.12 Corporate Cards & Transactions
--   14.13 Vehicles & Mileage Claims
--   14.14 Recurring Expenses
--   14.15 Expense Accounting Integration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS expenses;

-- ============================================================
-- 14.1 EXPENSE CATEGORIES
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_categories (
    expense_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    parent_category_id UUID NULL,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_taxable BOOLEAN NOT NULL DEFAULT TRUE,
    is_reimbursable BOOLEAN NOT NULL DEFAULT TRUE,
    is_billable BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ec_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ec_parent FOREIGN KEY (parent_category_id) REFERENCES expenses.expense_categories(expense_category_id),
    CONSTRAINT uq_ec_code UNIQUE (company_id, code)
);

CREATE INDEX ix_ec_company ON expenses.expense_categories(company_id);
CREATE INDEX ix_ec_parent ON expenses.expense_categories(parent_category_id);
CREATE INDEX ix_ec_active ON expenses.expense_categories(is_active);

-- ============================================================
-- 14.2 EXPENSE PAYMENT METHODS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_payment_methods (
    expense_payment_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    requires_receipt BOOLEAN NOT NULL DEFAULT FALSE,
    requires_approval BOOLEAN NOT NULL DEFAULT TRUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_epm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_epm_code UNIQUE (company_id, code)
);

CREATE INDEX ix_epm_company ON expenses.expense_payment_methods(company_id);

-- ============================================================
-- 14.3 EXPENSE CLAIMS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_claims (
    expense_claim_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    employee_id UUID NOT NULL,
    business_unit_id UUID NULL,
    department_id UUID NULL,
    cost_center_id UUID NULL,

    claim_number VARCHAR(50) NOT NULL,
    claim_date DATE NOT NULL DEFAULT CURRENT_DATE,
    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    approved_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    rejected_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    reimbursed_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    description TEXT NULL,

    submitted_at TIMESTAMPTZ NULL,
    approved_at TIMESTAMPTZ NULL,
    approved_by_user_id UUID NULL,
    rejected_at TIMESTAMPTZ NULL,
    rejected_by_user_id UUID NULL,
    rejection_reason TEXT NULL,
    paid_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ecl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ecl_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_ecl_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT fk_ecl_dept FOREIGN KEY (department_id) REFERENCES organization.departments(department_id),
    CONSTRAINT fk_ecl_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_claim_number UNIQUE (company_id, claim_number),
    CONSTRAINT ck_ecl_status CHECK (status IN ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'PARTIALLY_APPROVED', 'REJECTED', 'PAYMENT_PENDING', 'PAID', 'CANCELLED')),
    CONSTRAINT ck_ecl_amounts CHECK (total_amount >= 0 AND approved_amount >= 0 AND rejected_amount >= 0 AND reimbursed_amount >= 0)
);

CREATE INDEX ix_ecl_company ON expenses.expense_claims(company_id);
CREATE INDEX ix_ecl_employee ON expenses.expense_claims(employee_id);
CREATE INDEX ix_ecl_status ON expenses.expense_claims(status);
CREATE INDEX ix_ecl_claim_date ON expenses.expense_claims(claim_date);

-- ============================================================
-- 14.4 EXPENSE CLAIM ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_claim_items (
    expense_claim_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    expense_claim_id UUID NOT NULL,
    expense_category_id UUID NOT NULL,

    expense_date DATE NOT NULL,
    description TEXT NOT NULL,
    merchant_name VARCHAR(200) NULL,
    reference_number VARCHAR(100) NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_category_id UUID NULL,

    approved_amount NUMERIC(19,4) NULL,
    rejected_amount NUMERIC(19,4) NULL,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,
    base_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    payment_method_id UUID NULL,
    is_billable BOOLEAN NOT NULL DEFAULT FALSE,
    customer_id UUID NULL,
    project_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_eci_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_eci_claim FOREIGN KEY (expense_claim_id) REFERENCES expenses.expense_claims(expense_claim_id) ON DELETE CASCADE,
    CONSTRAINT fk_eci_category FOREIGN KEY (expense_category_id) REFERENCES expenses.expense_categories(expense_category_id),
    CONSTRAINT fk_eci_tax_category FOREIGN KEY (tax_category_id) REFERENCES accounting.tax_categories(tax_category_id),
    CONSTRAINT fk_eci_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_eci_payment_method FOREIGN KEY (payment_method_id) REFERENCES expenses.expense_payment_methods(expense_payment_method_id),
    CONSTRAINT fk_eci_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT ck_eci_amount CHECK (amount >= 0 AND tax_amount >= 0 AND base_amount >= 0)
);

CREATE INDEX ix_eci_claim ON expenses.expense_claim_items(expense_claim_id);
CREATE INDEX ix_eci_category ON expenses.expense_claim_items(expense_category_id);
CREATE INDEX ix_eci_expense_date ON expenses.expense_claim_items(expense_date);

-- ============================================================
-- 14.5 EXPENSE ATTACHMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_attachments (
    expense_attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    expense_claim_id UUID NULL,
    expense_claim_item_id UUID NULL,

    attachment_type VARCHAR(30) NOT NULL DEFAULT 'RECEIPT',
    file_name VARCHAR(500) NOT NULL,
    content_type VARCHAR(200) NULL,
    storage_path VARCHAR(1000) NULL,
    file_size_bytes BIGINT NULL,
    description TEXT NULL,

    uploaded_by_user_id UUID NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ea_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ea_claim FOREIGN KEY (expense_claim_id) REFERENCES expenses.expense_claims(expense_claim_id) ON DELETE CASCADE,
    CONSTRAINT fk_ea_item FOREIGN KEY (expense_claim_item_id) REFERENCES expenses.expense_claim_items(expense_claim_item_id) ON DELETE CASCADE,
    CONSTRAINT ck_ea_type CHECK (attachment_type IN ('RECEIPT', 'INVOICE', 'APPROVAL_DOCUMENT', 'SUPPORTING_DOCUMENT', 'OTHER'))
);

CREATE INDEX ix_ea_claim ON expenses.expense_attachments(expense_claim_id);
CREATE INDEX ix_ea_item ON expenses.expense_attachments(expense_claim_item_id);

-- ============================================================
-- 14.6 EXPENSE POLICIES & RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_policies (
    expense_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    policy_code VARCHAR(50) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    effective_from DATE NULL,
    effective_to DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ep_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_ep_code UNIQUE (company_id, policy_code)
);

CREATE INDEX ix_ep_company ON expenses.expense_policies(company_id);

CREATE TABLE IF NOT EXISTS expenses.expense_policy_rules (
    expense_policy_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_policy_id UUID NOT NULL,
    expense_category_id UUID NULL,

    rule_name VARCHAR(200) NOT NULL,
    rule_type VARCHAR(50) NOT NULL DEFAULT 'MAX_AMOUNT',

    maximum_amount NUMERIC(19,4) NULL,
    minimum_amount NUMERIC(19,4) NULL,
    maximum_per_day NUMERIC(19,4) NULL,
    maximum_per_month NUMERIC(19,4) NULL,

    requires_receipt BOOLEAN NOT NULL DEFAULT TRUE,
    requires_pre_approval BOOLEAN NOT NULL DEFAULT FALSE,
    requires_manager_approval BOOLEAN NOT NULL DEFAULT TRUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_epr_policy FOREIGN KEY (expense_policy_id) REFERENCES expenses.expense_policies(expense_policy_id) ON DELETE CASCADE,
    CONSTRAINT fk_epr_category FOREIGN KEY (expense_category_id) REFERENCES expenses.expense_categories(expense_category_id),
    CONSTRAINT ck_epr_type CHECK (rule_type IN ('MAX_AMOUNT', 'MIN_AMOUNT', 'DAILY_LIMIT', 'MONTHLY_LIMIT', 'RECEIPT_REQUIRED', 'PRE_APPROVAL', 'MANAGER_APPROVAL', 'CUSTOM'))
);

CREATE INDEX ix_epr_policy ON expenses.expense_policy_rules(expense_policy_id);

-- ============================================================
-- 14.7 POLICY VIOLATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_policy_violations (
    expense_policy_violation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    expense_claim_item_id UUID NOT NULL,
    expense_policy_rule_id UUID NULL,

    violation_type VARCHAR(50) NOT NULL,
    expected_value NUMERIC(19,4) NULL,
    actual_value NUMERIC(19,4) NULL,

    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    description TEXT NULL,
    resolution_notes TEXT NULL,
    resolved_by_user_id UUID NULL,
    resolved_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_epv_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_epv_item FOREIGN KEY (expense_claim_item_id) REFERENCES expenses.expense_claim_items(expense_claim_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_epv_rule FOREIGN KEY (expense_policy_rule_id) REFERENCES expenses.expense_policy_rules(expense_policy_rule_id),
    CONSTRAINT ck_epv_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_epv_status CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'WAIVED', 'ESCALATED'))
);

CREATE INDEX ix_epv_item ON expenses.expense_policy_violations(expense_claim_item_id);
CREATE INDEX ix_epv_status ON expenses.expense_policy_violations(status);

-- ============================================================
-- 14.8 APPROVAL RULES & APPROVALS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_approval_rules (
    expense_approval_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    expense_policy_id UUID NULL,

    rule_name VARCHAR(200) NOT NULL,
    sequence INTEGER NOT NULL DEFAULT 1,

    minimum_amount NUMERIC(19,4) NULL,
    maximum_amount NUMERIC(19,4) NULL,

    required_role_code VARCHAR(50) NULL,
    required_department_id UUID NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ear_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ear_policy FOREIGN KEY (expense_policy_id) REFERENCES expenses.expense_policies(expense_policy_id),
    CONSTRAINT fk_ear_dept FOREIGN KEY (required_department_id) REFERENCES organization.departments(department_id)
);

CREATE INDEX ix_ear_company ON expenses.expense_approval_rules(company_id);

CREATE TABLE IF NOT EXISTS expenses.expense_approvals (
    expense_approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_claim_id UUID NOT NULL,
    expense_approval_rule_id UUID NULL,

    sequence INTEGER NOT NULL DEFAULT 1,
    required_role_code VARCHAR(50) NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    approved_amount NUMERIC(19,4) NULL,

    rejected_by_user_id UUID NULL,
    rejected_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_eap_claim FOREIGN KEY (expense_claim_id) REFERENCES expenses.expense_claims(expense_claim_id) ON DELETE CASCADE,
    CONSTRAINT fk_eap_rule FOREIGN KEY (expense_approval_rule_id) REFERENCES expenses.expense_approval_rules(expense_approval_rule_id),
    CONSTRAINT fk_eap_approved_by FOREIGN KEY (approved_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_eap_rejected_by FOREIGN KEY (rejected_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_eap_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'ESCALATED', 'CANCELLED'))
);

CREATE INDEX ix_eap_claim ON expenses.expense_approvals(expense_claim_id);
CREATE INDEX ix_eap_status ON expenses.expense_approvals(status);

-- ============================================================
-- 14.9 EXPENSE BUDGETS & PERIODS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_budgets (
    expense_budget_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    fiscal_year_id UUID NULL,
    business_unit_id UUID NULL,
    department_id UUID NULL,
    expense_category_id UUID NULL,

    budget_code VARCHAR(50) NOT NULL,
    budget_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    budget_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    allocated_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    spent_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    committed_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_eb_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_eb_fiscal_year FOREIGN KEY (fiscal_year_id) REFERENCES accounting.fiscal_years(fiscal_year_id),
    CONSTRAINT fk_eb_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT fk_eb_dept FOREIGN KEY (department_id) REFERENCES organization.departments(department_id),
    CONSTRAINT fk_eb_category FOREIGN KEY (expense_category_id) REFERENCES expenses.expense_categories(expense_category_id),
    CONSTRAINT fk_eb_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_eb_code UNIQUE (company_id, budget_code),
    CONSTRAINT ck_eb_amounts CHECK (budget_amount >= 0 AND allocated_amount >= 0 AND spent_amount >= 0 AND committed_amount >= 0)
);

CREATE INDEX ix_eb_company ON expenses.expense_budgets(company_id);
CREATE INDEX ix_eb_fiscal_year ON expenses.expense_budgets(fiscal_year_id);

CREATE TABLE IF NOT EXISTS expenses.expense_budget_periods (
    expense_budget_period_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_budget_id UUID NOT NULL,
    fiscal_period_id UUID NULL,

    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,

    budget_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    actual_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    committed_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ebp_budget FOREIGN KEY (expense_budget_id) REFERENCES expenses.expense_budgets(expense_budget_id) ON DELETE CASCADE,
    CONSTRAINT fk_ebp_fiscal_period FOREIGN KEY (fiscal_period_id) REFERENCES accounting.fiscal_periods(fiscal_period_id),
    CONSTRAINT ck_ebp_dates CHECK (period_end_date >= period_start_date),
    CONSTRAINT ck_ebp_amounts CHECK (budget_amount >= 0 AND actual_amount >= 0 AND committed_amount >= 0)
);

CREATE INDEX ix_ebp_budget ON expenses.expense_budget_periods(expense_budget_id);

-- ============================================================
-- 14.10 REIMBURSEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_reimbursements (
    reimbursement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    employee_id UUID NOT NULL,
    expense_claim_id UUID NULL,

    reimbursement_number VARCHAR(50) NOT NULL,
    payment_method_id UUID NULL,
    currency_id UUID NOT NULL,

    requested_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    approved_amount NUMERIC(19,4) NULL,
    paid_amount NUMERIC(19,4) NULL,

    payment_date DATE NULL,
    payment_reference VARCHAR(100) NULL,
    payment_account_id UUID NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED',

    processed_by_user_id UUID NULL,
    processed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_er_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_er_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_er_claim FOREIGN KEY (expense_claim_id) REFERENCES expenses.expense_claims(expense_claim_id),
    CONSTRAINT fk_er_payment_method FOREIGN KEY (payment_method_id) REFERENCES expenses.expense_payment_methods(expense_payment_method_id),
    CONSTRAINT fk_er_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_reimbursement_number UNIQUE (company_id, reimbursement_number),
    CONSTRAINT ck_er_status CHECK (status IN ('REQUESTED', 'APPROVED', 'PROCESSING', 'PARTIALLY_PAID', 'PAID', 'REJECTED', 'CANCELLED')),
    CONSTRAINT ck_er_amounts CHECK (requested_amount >= 0 AND (approved_amount IS NULL OR approved_amount >= 0) AND (paid_amount IS NULL OR paid_amount >= 0))
);

CREATE INDEX ix_er_company ON expenses.expense_reimbursements(company_id);
CREATE INDEX ix_er_employee ON expenses.expense_reimbursements(employee_id);
CREATE INDEX ix_er_status ON expenses.expense_reimbursements(status);

-- ============================================================
-- 14.11 PETTY CASH
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.petty_cash_accounts (
    petty_cash_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    business_unit_id UUID NULL,
    currency_id UUID NOT NULL,

    account_code VARCHAR(50) NOT NULL,
    account_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    opening_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    current_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    maximum_balance NUMERIC(19,4) NULL,

    custodian_employee_id UUID NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',

    last_reconciliation_at TIMESTAMPTZ NULL,
    last_reconciled_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pca_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pca_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT fk_pca_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_pca_custodian FOREIGN KEY (custodian_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT uq_pca_code UNIQUE (company_id, account_code),
    CONSTRAINT ck_pca_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED'))
);

CREATE INDEX ix_pca_company ON expenses.petty_cash_accounts(company_id);

CREATE TABLE IF NOT EXISTS expenses.petty_cash_transactions (
    petty_cash_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    petty_cash_account_id UUID NOT NULL,
    company_id UUID NOT NULL,

    transaction_number VARCHAR(50) NOT NULL,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    transaction_type VARCHAR(30) NOT NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,
    reference_number VARCHAR(100) NULL,

    expense_claim_id UUID NULL,
    expense_claim_item_id UUID NULL,

    processed_by_user_id UUID NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pct_account FOREIGN KEY (petty_cash_account_id) REFERENCES expenses.petty_cash_accounts(petty_cash_account_id) ON DELETE CASCADE,
    CONSTRAINT fk_pct_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pct_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_pct_claim FOREIGN KEY (expense_claim_id) REFERENCES expenses.expense_claims(expense_claim_id),
    CONSTRAINT fk_pct_item FOREIGN KEY (expense_claim_item_id) REFERENCES expenses.expense_claim_items(expense_claim_item_id),
    CONSTRAINT uq_pct_number UNIQUE (petty_cash_account_id, transaction_number),
    CONSTRAINT ck_pct_type CHECK (transaction_type IN ('OPENING_BALANCE', 'CASH_IN', 'REPLENISHMENT', 'EXPENSE', 'CASH_OUT', 'ADJUSTMENT', 'RECONCILIATION')),
    CONSTRAINT ck_pct_amount CHECK (amount <> 0)
);

CREATE INDEX ix_pct_account ON expenses.petty_cash_transactions(petty_cash_account_id);
CREATE INDEX ix_pct_date ON expenses.petty_cash_transactions(transaction_date);

-- ============================================================
-- 14.12 CORPORATE CARDS
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.corporate_cards (
    corporate_card_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    employee_id UUID NULL,

    card_number_masked VARCHAR(50) NOT NULL,
    card_provider VARCHAR(100) NULL,
    card_type VARCHAR(30) NULL,

    credit_limit NUMERIC(19,4) NULL,
    current_balance NUMERIC(19,4) NOT NULL DEFAULT 0,

    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    issued_date DATE NULL,
    expiry_date DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cc_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT ck_cc_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CANCELLED', 'EXPIRED')),
    CONSTRAINT ck_cc_card_type CHECK (card_type IS NULL OR card_type IN ('CREDIT', 'DEBIT', 'PREPAID'))
);

CREATE INDEX ix_cc_company ON expenses.corporate_cards(company_id);
CREATE INDEX ix_cc_employee ON expenses.corporate_cards(employee_id);

CREATE TABLE IF NOT EXISTS expenses.corporate_card_transactions (
    corporate_card_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    corporate_card_id UUID NOT NULL,
    company_id UUID NOT NULL,

    transaction_date DATE NOT NULL,
    merchant_name VARCHAR(200) NULL,
    reference_number VARCHAR(100) NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    matched_expense_claim_item_id UUID NULL,
    reconciliation_status VARCHAR(30) NOT NULL DEFAULT 'UNMATCHED',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cct_card FOREIGN KEY (corporate_card_id) REFERENCES expenses.corporate_cards(corporate_card_id) ON DELETE CASCADE,
    CONSTRAINT fk_cct_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cct_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_cct_item FOREIGN KEY (matched_expense_claim_item_id) REFERENCES expenses.expense_claim_items(expense_claim_item_id),
    CONSTRAINT ck_cct_reconciliation CHECK (reconciliation_status IN ('UNMATCHED', 'MATCHED', 'DISPUTED', 'WRITTEN_OFF')),
    CONSTRAINT ck_cct_amount CHECK (amount <> 0)
);

CREATE INDEX ix_cct_card ON expenses.corporate_card_transactions(corporate_card_id);
CREATE INDEX ix_cct_date ON expenses.corporate_card_transactions(transaction_date);
CREATE INDEX ix_cct_reconciliation ON expenses.corporate_card_transactions(reconciliation_status);

-- ============================================================
-- 14.13 VEHICLES & MILEAGE
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.vehicles (
    vehicle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    vehicle_number VARCHAR(50) NOT NULL,
    registration_number VARCHAR(50) NULL,
    vehicle_type VARCHAR(50) NULL,
    make VARCHAR(100) NULL,
    model VARCHAR(100) NULL,
    year INTEGER NULL,

    fuel_type VARCHAR(30) NULL,
    mileage_rate NUMERIC(19,4) NULL,

    assigned_employee_id UUID NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_v_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_v_employee FOREIGN KEY (assigned_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT uq_vehicle_number UNIQUE (company_id, vehicle_number),
    CONSTRAINT ck_v_status CHECK (status IN ('ACTIVE', 'IN_MAINTENANCE', 'RETIRED', 'SOLD'))
);

CREATE INDEX ix_v_company ON expenses.vehicles(company_id);

CREATE TABLE IF NOT EXISTS expenses.mileage_claims (
    mileage_claim_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_claim_item_id UUID NOT NULL,
    vehicle_id UUID NULL,

    travel_date DATE NOT NULL,
    start_location VARCHAR(200) NULL,
    end_location VARCHAR(200) NULL,

    distance NUMERIC(19,4) NOT NULL DEFAULT 0,
    distance_unit VARCHAR(10) NOT NULL DEFAULT 'KM',
    rate_per_unit NUMERIC(19,4) NOT NULL DEFAULT 0,
    calculated_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    purpose TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_mc_item FOREIGN KEY (expense_claim_item_id) REFERENCES expenses.expense_claim_items(expense_claim_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_mc_vehicle FOREIGN KEY (vehicle_id) REFERENCES expenses.vehicles(vehicle_id),
    CONSTRAINT ck_mc_distance CHECK (distance > 0),
    CONSTRAINT ck_mc_unit CHECK (distance_unit IN ('KM', 'MILES'))
);

CREATE INDEX ix_mc_item ON expenses.mileage_claims(expense_claim_item_id);
CREATE INDEX ix_mc_vehicle ON expenses.mileage_claims(vehicle_id);

-- ============================================================
-- 14.14 RECURRING EXPENSES
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.recurring_expenses (
    recurring_expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    employee_id UUID NULL,
    expense_category_id UUID NOT NULL,
    business_unit_id UUID NULL,
    department_id UUID NULL,

    expense_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    merchant_name VARCHAR(200) NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    frequency VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
    day_of_month INTEGER NULL,
    day_of_week INTEGER NULL,

    start_date DATE NOT NULL,
    end_date DATE NULL,
    next_due_date DATE NULL,
    last_generated_date DATE NULL,

    total_generated INTEGER NOT NULL DEFAULT 0,
    total_amount_generated NUMERIC(19,4) NOT NULL DEFAULT 0,

    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    is_auto_approve BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_re_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_re_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_re_category FOREIGN KEY (expense_category_id) REFERENCES expenses.expense_categories(expense_category_id),
    CONSTRAINT fk_re_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT fk_re_dept FOREIGN KEY (department_id) REFERENCES organization.departments(department_id),
    CONSTRAINT fk_re_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_re_frequency CHECK (frequency IN ('DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL')),
    CONSTRAINT ck_re_status CHECK (status IN ('ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT ck_re_amount CHECK (amount > 0)
);

CREATE INDEX ix_re_company ON expenses.recurring_expenses(company_id);
CREATE INDEX ix_re_next_due ON expenses.recurring_expenses(next_due_date);
CREATE INDEX ix_re_status ON expenses.recurring_expenses(status);

-- ============================================================
-- 14.15 EXPENSE ACCOUNTING INTEGRATION
-- ============================================================

CREATE TABLE IF NOT EXISTS expenses.expense_journal_entries (
    expense_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    expense_claim_id UUID NULL,
    expense_claim_item_id UUID NULL,
    journal_entry_id UUID NULL,

    posting_date DATE NOT NULL,
    debit_account_id UUID NULL,
    credit_account_id UUID NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_eje_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_eje_claim FOREIGN KEY (expense_claim_id) REFERENCES expenses.expense_claims(expense_claim_id),
    CONSTRAINT fk_eje_item FOREIGN KEY (expense_claim_item_id) REFERENCES expenses.expense_claim_items(expense_claim_item_id),
    CONSTRAINT fk_eje_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_eje_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_eje_claim ON expenses.expense_journal_entries(expense_claim_id);

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

    -- Seed Expense Categories
    INSERT INTO expenses.expense_categories (company_id, code, name, description, sort_order) VALUES
        (v_company_id, 'TRAVEL', 'Travel', 'Travel expenses including flights, trains, taxis.', 10),
        (v_company_id, 'ACCOMMODATION', 'Accommodation', 'Hotel and accommodation expenses.', 20),
        (v_company_id, 'MEALS', 'Meals & Entertainment', 'Meals and business entertainment.', 30),
        (v_company_id, 'TRANSPORT', 'Local Transport', 'Local transportation expenses.', 40),
        (v_company_id, 'OFFICE_SUPPLIES', 'Office Supplies', 'Office supplies and stationery.', 50),
        (v_company_id, 'EQUIPMENT', 'Equipment', 'Equipment purchases.', 60),
        (v_company_id, 'SOFTWARE', 'Software & Subscriptions', 'Software licenses and subscriptions.', 70),
        (v_company_id, 'TRAINING', 'Training & Development', 'Training and development expenses.', 80),
        (v_company_id, 'MARKETING', 'Marketing', 'Marketing and advertising expenses.', 90),
        (v_company_id, 'UTILITIES', 'Utilities', 'Utility bills.', 100),
        (v_company_id, 'RENT', 'Rent', 'Office rent.', 110),
        (v_company_id, 'INSURANCE', 'Insurance', 'Insurance premiums.', 120),
        (v_company_id, 'MISCELLANEOUS', 'Miscellaneous', 'Other miscellaneous expenses.', 130)
    ON CONFLICT (company_id, code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

    -- Seed Payment Methods
    INSERT INTO expenses.expense_payment_methods (company_id, code, name, description, requires_receipt, sort_order) VALUES
        (v_company_id, 'PERSONAL_CARD', 'Personal Card', 'Employee personal credit/debit card.', TRUE, 10),
        (v_company_id, 'PERSONAL_CASH', 'Personal Cash', 'Employee personal cash.', TRUE, 20),
        (v_company_id, 'CORPORATE_CARD', 'Corporate Card', 'Company corporate card.', TRUE, 30),
        (v_company_id, 'COMPANY_CASH', 'Company Cash', 'Company cash/petty cash.', TRUE, 40),
        (v_company_id, 'BANK_TRANSFER', 'Bank Transfer', 'Direct bank transfer.', FALSE, 50),
        (v_company_id, 'DIGITAL_WALLET', 'Digital Wallet', 'Digital wallet payment.', TRUE, 60)
    ON CONFLICT (company_id, code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

    -- Seed Default Expense Policy
    INSERT INTO expenses.expense_policies (company_id, policy_code, policy_name, description, is_default, is_active)
    SELECT v_company_id, 'DEFAULT-POLICY', 'Default Expense Policy', 'Default expense policy for all employees.', TRUE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM expenses.expense_policies WHERE company_id = v_company_id AND policy_code = 'DEFAULT-POLICY');

    -- Seed Default Approval Rules
    INSERT INTO expenses.expense_approval_rules (company_id, rule_name, sequence, minimum_amount, maximum_amount, required_role_code)
    SELECT v_company_id, 'Manager Approval', 1, 0, 50000, 'MANAGER'
    WHERE NOT EXISTS (SELECT 1 FROM expenses.expense_approval_rules WHERE company_id = v_company_id AND rule_name = 'Manager Approval');

    INSERT INTO expenses.expense_approval_rules (company_id, rule_name, sequence, minimum_amount, required_role_code)
    SELECT v_company_id, 'Director Approval', 2, 50000, 'DIRECTOR'
    WHERE NOT EXISTS (SELECT 1 FROM expenses.expense_approval_rules WHERE company_id = v_company_id AND rule_name = 'Director Approval');

END $$;

COMMIT;