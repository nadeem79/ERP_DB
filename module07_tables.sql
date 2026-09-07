BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 07: PURCHASING & SUPPLIER MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   Rule 5 — Return reverses inventory (Purchase Return → Inventory OUT)
--   Rule 6 — Never overwrite history
--   Use Reversal, Adjustment, Credit Note, Debit Note
--   Three-way match: PO → Receipt → Invoice
-- ============================================================
-- Components:
--   07.1  Suppliers & Contacts
--   07.2  Supplier Bank Accounts
--   07.3  Supplier Products & Prices
--   07.4  Payment Terms
--   07.5  Purchase Requisitions
--   07.6  Purchase Approval Rules
--   07.7  Purchase Orders
--   07.8  Goods Receipts
--   07.9  Supplier Invoices
--   07.10 Three-Way Match
--   07.11 Supplier Payments
--   07.12 Purchase Returns
--   07.13 Supplier Credit/Debit Notes
--   07.14 Supplier Documents
--   07.15 Supplier Rating
--   07.16 Landed Cost
--   07.17 Accounting Integration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS purchasing;

-- ============================================================
-- 07.1 SUPPLIER STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_status_lookup (
    supplier_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO purchasing.supplier_status_lookup (code, name, description, sort_order) VALUES
    ('PROSPECT', 'Prospect', 'Potential supplier.', 10),
    ('ACTIVE', 'Active', 'Active supplier.', 20),
    ('ON_HOLD', 'On Hold', 'Supplier on hold.', 30),
    ('BLACKLISTED', 'Blacklisted', 'Supplier blacklisted.', 40),
    ('INACTIVE', 'Inactive', 'Inactive supplier.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 07.2 PURCHASE ORDER STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.po_status_lookup (
    po_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO purchasing.po_status_lookup (code, name, description, is_terminal, sort_order) VALUES
    ('DRAFT', 'Draft', 'PO is being created.', FALSE, 10),
    ('PENDING_APPROVAL', 'Pending Approval', 'Awaiting approval.', FALSE, 20),
    ('APPROVED', 'Approved', 'PO approved.', FALSE, 30),
    ('SENT', 'Sent', 'PO sent to supplier.', FALSE, 40),
    ('PARTIALLY_RECEIVED', 'Partially Received', 'Partially received.', FALSE, 50),
    ('RECEIVED', 'Received', 'Fully received.', FALSE, 60),
    ('PARTIALLY_INVOICED', 'Partially Invoiced', 'Partially invoiced.', FALSE, 70),
    ('INVOICED', 'Invoiced', 'Fully invoiced.', FALSE, 80),
    ('PARTIALLY_PAID', 'Partially Paid', 'Partially paid.', FALSE, 90),
    ('PAID', 'Paid', 'Fully paid.', TRUE, 100),
    ('CANCELLED', 'Cancelled', 'PO cancelled.', TRUE, 110),
    ('CLOSED', 'Closed', 'PO closed.', TRUE, 120)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 07.3 GOODS RECEIPT STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.receipt_status_lookup (
    receipt_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO purchasing.receipt_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Receipt pending.', 10),
    ('RECEIVED', 'Received', 'Goods received.', 20),
    ('INSPECTION_PENDING', 'Inspection Pending', 'Awaiting inspection.', 30),
    ('INSPECTION_COMPLETED', 'Inspection Completed', 'Inspection completed.', 40),
    ('PARTIALLY_ACCEPTED', 'Partially Accepted', 'Partially accepted.', 50),
    ('REJECTED', 'Rejected', 'Goods rejected.', 60),
    ('CANCELLED', 'Cancelled', 'Receipt cancelled.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 07.4 SUPPLIER INVOICE STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_invoice_status_lookup (
    supplier_invoice_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO purchasing.supplier_invoice_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Invoice draft.', 10),
    ('RECEIVED', 'Received', 'Invoice received.', 20),
    ('MATCHED', 'Matched', 'Three-way match completed.', 30),
    ('APPROVED', 'Approved', 'Invoice approved.', 40),
    ('PARTIALLY_PAID', 'Partially Paid', 'Partially paid.', 50),
    ('PAID', 'Paid', 'Fully paid.', 60),
    ('DISPUTED', 'Disputed', 'Invoice disputed.', 70),
    ('CANCELLED', 'Cancelled', 'Invoice cancelled.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 07.5 REQUISITION STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.requisition_status_lookup (
    requisition_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO purchasing.requisition_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Requisition draft.', 10),
    ('SUBMITTED', 'Submitted', 'Submitted for approval.', 20),
    ('APPROVED', 'Approved', 'Approved.', 30),
    ('REJECTED', 'Rejected', 'Rejected.', 40),
    ('CONVERTED_TO_PO', 'Converted to PO', 'Converted to purchase order.', 50),
    ('CANCELLED', 'Cancelled', 'Cancelled.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 07.6 SUPPLIERS (Main Table)
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.suppliers (
    supplier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    supplier_status_id UUID NOT NULL DEFAULT (SELECT supplier_status_id FROM purchasing.supplier_status_lookup WHERE code = 'PROSPECT'),

    supplier_code VARCHAR(50) NOT NULL,
    supplier_name VARCHAR(200) NOT NULL,
    legal_name VARCHAR(300) NULL,
    description TEXT NULL,

    contact_person VARCHAR(200) NULL,
    email VARCHAR(300) NULL,
    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,
    website VARCHAR(500) NULL,

    tax_number VARCHAR(100) NULL,
    tax_type VARCHAR(50) NULL,
    registration_number VARCHAR(100) NULL,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state VARCHAR(200) NULL,
    postal_code VARCHAR(20) NULL,
    country_id UUID NULL,

    currency_id UUID NULL,
    payment_terms_id UUID NULL,

    credit_limit NUMERIC(19,4) NULL,
    current_balance NUMERIC(19,4) NOT NULL DEFAULT 0,

    rating NUMERIC(3,2) NULL,
    total_orders INTEGER NOT NULL DEFAULT 0,
    total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    on_time_delivery_rate NUMERIC(5,2) NULL,
    quality_score NUMERIC(3,2) NULL,

    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sup_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sup_status FOREIGN KEY (supplier_status_id) REFERENCES purchasing.supplier_status_lookup(supplier_status_id),
    CONSTRAINT fk_sup_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_sup_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT uq_supplier_code UNIQUE (company_id, supplier_code),
    CONSTRAINT ck_sup_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5))
);

CREATE INDEX ix_sup_company ON purchasing.suppliers(company_id);
CREATE INDEX ix_sup_status ON purchasing.suppliers(supplier_status_id);
CREATE INDEX ix_sup_active ON purchasing.suppliers(is_active);

-- ============================================================
-- 07.7 SUPPLIER CONTACTS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_contacts (
    supplier_contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    company_id UUID NOT NULL,

    contact_name VARCHAR(200) NOT NULL,
    job_title VARCHAR(200) NULL,
    email VARCHAR(300) NULL,
    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sc_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id) ON DELETE CASCADE,
    CONSTRAINT fk_sc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id)
);

CREATE INDEX ix_sc_supplier ON purchasing.supplier_contacts(supplier_id);

-- ============================================================
-- 07.8 SUPPLIER BANK ACCOUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_bank_accounts (
    supplier_bank_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    company_id UUID NOT NULL,

    bank_name VARCHAR(200) NOT NULL,
    account_title VARCHAR(200) NULL,
    account_number VARCHAR(100) NOT NULL,
    iban VARCHAR(50) NULL,
    swift_code VARCHAR(20) NULL,
    branch_name VARCHAR(200) NULL,
    branch_code VARCHAR(20) NULL,

    currency_id UUID NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sba_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id) ON DELETE CASCADE,
    CONSTRAINT fk_sba_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sba_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_sba_supplier ON purchasing.supplier_bank_accounts(supplier_id);

-- ============================================================
-- 07.9 PAYMENT TERMS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.payment_terms (
    payment_terms_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    terms_code VARCHAR(50) NOT NULL,
    terms_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    days_to_pay INTEGER NOT NULL DEFAULT 30,
    discount_percent NUMERIC(5,2) NULL,
    discount_days INTEGER NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_terms_code UNIQUE (company_id, terms_code),
    CONSTRAINT ck_pt_days CHECK (days_to_pay >= 0)
);

CREATE INDEX ix_pt_company ON purchasing.payment_terms(company_id);

-- ============================================================
-- 07.10 SUPPLIER PRODUCTS & PRICES
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_products (
    supplier_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    supplier_product_code VARCHAR(100) NULL,
    supplier_product_name VARCHAR(300) NULL,

    lead_time_days INTEGER NULL,
    min_order_qty NUMERIC(19,4) NULL,
    max_order_qty NUMERIC(19,4) NULL,

    is_preferred BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sp_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id) ON DELETE CASCADE,
    CONSTRAINT fk_sp_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_supplier_product UNIQUE (supplier_id, product_id)
);

CREATE INDEX ix_sp_supplier ON purchasing.supplier_products(supplier_id);
CREATE INDEX ix_sp_product ON purchasing.supplier_products(product_id);

CREATE TABLE IF NOT EXISTS purchasing.supplier_prices (
    supplier_price_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    price NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    min_quantity NUMERIC(19,4) NULL,

    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sprice_supplier_product FOREIGN KEY (supplier_product_id) REFERENCES purchasing.supplier_products(supplier_product_id) ON DELETE CASCADE,
    CONSTRAINT fk_sprice_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sprice_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_sprice_amount CHECK (price >= 0)
);

CREATE INDEX ix_sprice_supplier_product ON purchasing.supplier_prices(supplier_product_id);

-- ============================================================
-- 07.11 PURCHASE REQUISITIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.purchase_requisitions (
    purchase_requisition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    requisition_status_id UUID NOT NULL DEFAULT (SELECT requisition_status_id FROM purchasing.requisition_status_lookup WHERE code = 'DRAFT'),

    requisition_number VARCHAR(50) NOT NULL,
    requisition_date DATE NOT NULL DEFAULT CURRENT_DATE,
    required_by_date DATE NULL,

    requested_by_user_id UUID NULL,
    department_id UUID NULL,
    business_unit_id UUID NULL,

    purpose TEXT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',

    total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,

    converted_to_po_id UUID NULL,
    converted_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pr_status FOREIGN KEY (requisition_status_id) REFERENCES purchasing.requisition_status_lookup(requisition_status_id),
    CONSTRAINT fk_pr_department FOREIGN KEY (department_id) REFERENCES organization.departments(department_id),
    CONSTRAINT fk_pr_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT fk_pr_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_requisition_number UNIQUE (company_id, requisition_number),
    CONSTRAINT ck_pr_priority CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT'))
);

CREATE INDEX ix_pr_company ON purchasing.purchase_requisitions(company_id);
CREATE INDEX ix_pr_status ON purchasing.purchase_requisitions(requisition_status_id);

CREATE TABLE IF NOT EXISTS purchasing.purchase_requisition_items (
    purchase_requisition_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_requisition_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    estimated_unit_price NUMERIC(19,4) NULL,
    estimated_total NUMERIC(19,4) NULL,

    currency_id UUID NOT NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pri_requisition FOREIGN KEY (purchase_requisition_id) REFERENCES purchasing.purchase_requisitions(purchase_requisition_id) ON DELETE CASCADE,
    CONSTRAINT fk_pri_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pri_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pri_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_pri_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_pri_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_pri_requisition ON purchasing.purchase_requisition_items(purchase_requisition_id);

-- ============================================================
-- 07.12 PURCHASE ORDERS (Main Table)
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.purchase_orders (
    purchase_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    po_status_id UUID NOT NULL DEFAULT (SELECT po_status_id FROM purchasing.po_status_lookup WHERE code = 'DRAFT'),
    purchase_requisition_id UUID NULL,

    po_number VARCHAR(50) NOT NULL,
    po_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE NULL,
    actual_delivery_date DATE NULL,

    supplier_reference VARCHAR(200) NULL,
    payment_terms_id UUID NULL,
    due_date DATE NULL,

    subtotal_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    freight_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    other_charges NUMERIC(19,4) NOT NULL DEFAULT 0,
    grand_total NUMERIC(19,4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    outstanding_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    -- Shipping address
    shipping_address_line1 VARCHAR(300) NULL,
    shipping_address_line2 VARCHAR(300) NULL,
    shipping_city VARCHAR(200) NULL,
    shipping_state VARCHAR(200) NULL,
    shipping_postal_code VARCHAR(20) NULL,
    shipping_country_id UUID NULL,

    -- Status tracking
    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    sent_at TIMESTAMPTZ NULL,
    received_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,
    cancellation_reason TEXT NULL,

    notes TEXT NULL,
    internal_notes TEXT NULL,

    -- Landed cost
    landed_cost_calculated BOOLEAN NOT NULL DEFAULT FALSE,
    total_landed_cost NUMERIC(19,4) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_po_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT fk_po_status FOREIGN KEY (po_status_id) REFERENCES purchasing.po_status_lookup(po_status_id),
    CONSTRAINT fk_po_requisition FOREIGN KEY (purchase_requisition_id) REFERENCES purchasing.purchase_requisitions(purchase_requisition_id),
    CONSTRAINT fk_po_payment_terms FOREIGN KEY (payment_terms_id) REFERENCES purchasing.payment_terms(payment_terms_id),
    CONSTRAINT fk_po_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_po_number UNIQUE (company_id, po_number),
    CONSTRAINT ck_po_amounts CHECK (grand_total >= 0 AND paid_amount >= 0 AND outstanding_amount >= 0)
);

CREATE INDEX ix_po_company ON purchasing.purchase_orders(company_id);
CREATE INDEX ix_po_supplier ON purchasing.purchase_orders(supplier_id);
CREATE INDEX ix_po_status ON purchasing.purchase_orders(po_status_id);
CREATE INDEX ix_po_date ON purchasing.purchase_orders(po_date);
CREATE INDEX ix_po_due_date ON purchasing.purchase_orders(due_date);

-- ============================================================
-- 07.13 PURCHASE ORDER ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.purchase_order_items (
    purchase_order_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    product_name VARCHAR(300) NOT NULL,
    sku VARCHAR(100) NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    received_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    invoiced_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    returned_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    -- Landed cost per item
    freight_cost NUMERIC(19,4) NULL,
    duty_cost NUMERIC(19,4) NULL,
    other_costs NUMERIC(19,4) NULL,
    landed_unit_cost NUMERIC(19,4) NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_poi_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id) ON DELETE CASCADE,
    CONSTRAINT fk_poi_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_poi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_poi_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_poi_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_poi_quantity CHECK (quantity > 0),
    CONSTRAINT ck_poi_amounts CHECK (unit_price >= 0 AND line_total >= 0)
);

CREATE INDEX ix_poi_po ON purchasing.purchase_order_items(purchase_order_id);
CREATE INDEX ix_poi_product ON purchasing.purchase_order_items(product_id);

-- ============================================================
-- 07.14 GOODS RECEIPTS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.goods_receipts (
    goods_receipt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL,
    company_id UUID NOT NULL,
    receipt_status_id UUID NOT NULL DEFAULT (SELECT receipt_status_id FROM purchasing.receipt_status_lookup WHERE code = 'PENDING'),

    receipt_number VARCHAR(50) NOT NULL,
    receipt_date DATE NOT NULL DEFAULT CURRENT_DATE,

    warehouse_id UUID NULL,
    received_by_user_id UUID NULL,

    supplier_delivery_note VARCHAR(200) NULL,
    tracking_number VARCHAR(200) NULL,

    inspection_required BOOLEAN NOT NULL DEFAULT FALSE,
    inspection_completed BOOLEAN NOT NULL DEFAULT FALSE,
    inspected_by_user_id UUID NULL,
    inspected_at TIMESTAMPTZ NULL,
    inspection_notes TEXT NULL,

    total_items INTEGER NOT NULL DEFAULT 0,
    total_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    accepted_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    rejected_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_gr_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id),
    CONSTRAINT fk_gr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_gr_status FOREIGN KEY (receipt_status_id) REFERENCES purchasing.receipt_status_lookup(receipt_status_id),
    CONSTRAINT fk_gr_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_gr_received_by FOREIGN KEY (received_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_receipt_number UNIQUE (company_id, receipt_number),
    CONSTRAINT ck_gr_quantity CHECK (total_quantity >= 0 AND accepted_quantity >= 0 AND rejected_quantity >= 0)
);

CREATE INDEX ix_gr_po ON purchasing.goods_receipts(purchase_order_id);
CREATE INDEX ix_gr_status ON purchasing.goods_receipts(receipt_status_id);

CREATE TABLE IF NOT EXISTS purchasing.goods_receipt_items (
    goods_receipt_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goods_receipt_id UUID NOT NULL,
    purchase_order_item_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    ordered_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    received_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    accepted_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    rejected_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    damaged_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,
    expiry_date DATE NULL,

    inspection_result VARCHAR(30) NULL,
    rejection_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_gri_receipt FOREIGN KEY (goods_receipt_id) REFERENCES purchasing.goods_receipts(goods_receipt_id) ON DELETE CASCADE,
    CONSTRAINT fk_gri_po_item FOREIGN KEY (purchase_order_item_id) REFERENCES purchasing.purchase_order_items(purchase_order_item_id),
    CONSTRAINT fk_gri_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_gri_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_gri_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_gri_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_gri_quantity CHECK (received_quantity >= 0 AND accepted_quantity >= 0 AND rejected_quantity >= 0)
);

CREATE INDEX ix_gri_receipt ON purchasing.goods_receipt_items(goods_receipt_id);

-- ============================================================
-- 07.15 SUPPLIER INVOICES
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_invoices (
    supplier_invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NULL,
    supplier_id UUID NOT NULL,
    company_id UUID NOT NULL,
    supplier_invoice_status_id UUID NOT NULL DEFAULT (SELECT supplier_invoice_status_id FROM purchasing.supplier_invoice_status_lookup WHERE code = 'DRAFT'),

    invoice_number VARCHAR(100) NOT NULL,
    supplier_invoice_number VARCHAR(100) NULL,
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NULL,

    subtotal_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    freight_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    grand_total NUMERIC(19,4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    outstanding_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    -- Three-way match
    po_matched BOOLEAN NOT NULL DEFAULT FALSE,
    receipt_matched BOOLEAN NOT NULL DEFAULT FALSE,
    match_completed BOOLEAN NOT NULL DEFAULT FALSE,
    match_notes TEXT NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_si_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id),
    CONSTRAINT fk_si_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT fk_si_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_si_status FOREIGN KEY (supplier_invoice_status_id) REFERENCES purchasing.supplier_invoice_status_lookup(supplier_invoice_status_id),
    CONSTRAINT fk_si_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_invoice_number UNIQUE (company_id, invoice_number),
    CONSTRAINT ck_si_amounts CHECK (grand_total >= 0 AND paid_amount >= 0 AND outstanding_amount >= 0)
);

CREATE INDEX ix_si_po ON purchasing.supplier_invoices(purchase_order_id);
CREATE INDEX ix_si_supplier ON purchasing.supplier_invoices(supplier_id);
CREATE INDEX ix_si_status ON purchasing.supplier_invoices(supplier_invoice_status_id);
CREATE INDEX ix_si_due_date ON purchasing.supplier_invoices(due_date);

CREATE TABLE IF NOT EXISTS purchasing.supplier_invoice_items (
    supplier_invoice_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_invoice_id UUID NOT NULL,
    purchase_order_item_id UUID NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sii_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES purchasing.supplier_invoices(supplier_invoice_id) ON DELETE CASCADE,
    CONSTRAINT fk_sii_po_item FOREIGN KEY (purchase_order_item_id) REFERENCES purchasing.purchase_order_items(purchase_order_item_id),
    CONSTRAINT fk_sii_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sii_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sii_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_sii_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_sii_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_sii_invoice ON purchasing.supplier_invoice_items(supplier_invoice_id);

-- ============================================================
-- 07.16 THREE-WAY MATCH EXCEPTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.three_way_match_exceptions (
    three_way_match_exception_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_invoice_id UUID NOT NULL,
    purchase_order_id UUID NULL,
    goods_receipt_id UUID NULL,
    company_id UUID NOT NULL,

    exception_type VARCHAR(50) NOT NULL,
    description TEXT NULL,

    po_amount NUMERIC(19,4) NULL,
    receipt_amount NUMERIC(19,4) NULL,
    invoice_amount NUMERIC(19,4) NULL,
    variance_amount NUMERIC(19,4) NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
    resolved_by_user_id UUID NULL,
    resolved_at TIMESTAMPTZ NULL,
    resolution_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_twme_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES purchasing.supplier_invoices(supplier_invoice_id),
    CONSTRAINT fk_twme_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id),
    CONSTRAINT fk_twme_receipt FOREIGN KEY (goods_receipt_id) REFERENCES purchasing.goods_receipts(goods_receipt_id),
    CONSTRAINT fk_twme_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_twme_type CHECK (exception_type IN ('PRICE_VARIANCE', 'QUANTITY_VARIANCE', 'MISSING_RECEIPT', 'MISSING_PO', 'AMOUNT_MISMATCH', 'OTHER')),
    CONSTRAINT ck_twme_status CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'DISPUTED', 'CLOSED'))
);

CREATE INDEX ix_twme_invoice ON purchasing.three_way_match_exceptions(supplier_invoice_id);
CREATE INDEX ix_twme_status ON purchasing.three_way_match_exceptions(status);

-- ============================================================
-- 07.17 SUPPLIER PAYMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_payments (
    supplier_payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    supplier_invoice_id UUID NULL,
    company_id UUID NOT NULL,

    payment_number VARCHAR(50) NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    payment_method VARCHAR(50) NULL,
    payment_reference VARCHAR(200) NULL,
    bank_account_id UUID NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sp_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT fk_sp_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES purchasing.supplier_invoices(supplier_invoice_id),
    CONSTRAINT fk_sp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sp_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_sp_bank FOREIGN KEY (bank_account_id) REFERENCES purchasing.supplier_bank_accounts(supplier_bank_account_id),
    CONSTRAINT uq_payment_number UNIQUE (company_id, payment_number),
    CONSTRAINT ck_sp_amount CHECK (amount > 0),
    CONSTRAINT ck_sp_status CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED'))
);

CREATE INDEX ix_sp_supplier ON purchasing.supplier_payments(supplier_id);
CREATE INDEX ix_sp_invoice ON purchasing.supplier_payments(supplier_invoice_id);

-- ============================================================
-- 07.18 PURCHASE RETURNS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.purchase_returns (
    purchase_return_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    company_id UUID NOT NULL,

    return_number VARCHAR(50) NOT NULL,
    return_date DATE NOT NULL DEFAULT CURRENT_DATE,

    return_reason TEXT NULL,
    return_type VARCHAR(30) NOT NULL DEFAULT 'RETURN',

    total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,

    shipped_to_supplier BOOLEAN NOT NULL DEFAULT FALSE,
    shipped_at TIMESTAMPTZ NULL,
    tracking_number VARCHAR(200) NULL,

    credit_note_received BOOLEAN NOT NULL DEFAULT FALSE,
    credit_note_amount NUMERIC(19,4) NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pret_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id),
    CONSTRAINT fk_pret_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT fk_pret_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pret_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_return_number UNIQUE (company_id, return_number),
    CONSTRAINT ck_pret_amount CHECK (total_amount >= 0),
    CONSTRAINT ck_pret_type CHECK (return_type IN ('RETURN', 'EXCHANGE', 'REPAIR')),
    CONSTRAINT ck_pret_status CHECK (status IN ('PENDING', 'APPROVED', 'SHIPPED', 'COMPLETED', 'CANCELLED'))
);

CREATE INDEX ix_pret_po ON purchasing.purchase_returns(purchase_order_id);
CREATE INDEX ix_pret_supplier ON purchasing.purchase_returns(supplier_id);

CREATE TABLE IF NOT EXISTS purchasing.purchase_return_items (
    purchase_return_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_return_id UUID NOT NULL,
    purchase_order_item_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    return_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pri_return FOREIGN KEY (purchase_return_id) REFERENCES purchasing.purchase_returns(purchase_return_id) ON DELETE CASCADE,
    CONSTRAINT fk_pri_po_item FOREIGN KEY (purchase_order_item_id) REFERENCES purchasing.purchase_order_items(purchase_order_item_id),
    CONSTRAINT fk_pri_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pri_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pri_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_pri_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_pri_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_pri_return ON purchasing.purchase_return_items(purchase_return_id);

-- ============================================================
-- 07.19 SUPPLIER CREDIT/DEBIT NOTES
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_credit_notes (
    supplier_credit_note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    supplier_invoice_id UUID NULL,
    purchase_return_id UUID NULL,
    company_id UUID NOT NULL,

    credit_note_number VARCHAR(50) NOT NULL,
    credit_note_date DATE NOT NULL DEFAULT CURRENT_DATE,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    reason TEXT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    applied_to_invoice BOOLEAN NOT NULL DEFAULT FALSE,
    applied_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_scn_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT fk_scn_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES purchasing.supplier_invoices(supplier_invoice_id),
    CONSTRAINT fk_scn_return FOREIGN KEY (purchase_return_id) REFERENCES purchasing.purchase_returns(purchase_return_id),
    CONSTRAINT fk_scn_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_scn_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_credit_note_number UNIQUE (company_id, credit_note_number),
    CONSTRAINT ck_scn_amount CHECK (amount > 0)
);

CREATE INDEX ix_scn_supplier ON purchasing.supplier_credit_notes(supplier_id);

CREATE TABLE IF NOT EXISTS purchasing.supplier_debit_notes (
    supplier_debit_note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    purchase_order_id UUID NULL,
    company_id UUID NOT NULL,

    debit_note_number VARCHAR(50) NOT NULL,
    debit_note_date DATE NOT NULL DEFAULT CURRENT_DATE,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    reason TEXT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sdn_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT fk_sdn_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id),
    CONSTRAINT fk_sdn_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sdn_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_debit_note_number UNIQUE (company_id, debit_note_number),
    CONSTRAINT ck_sdn_amount CHECK (amount > 0)
);

CREATE INDEX ix_sdn_supplier ON purchasing.supplier_debit_notes(supplier_id);

-- ============================================================
-- 07.20 SUPPLIER DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_documents (
    supplier_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    company_id UUID NOT NULL,

    document_type VARCHAR(50) NOT NULL,
    document_title VARCHAR(300) NULL,
    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,
    file_name VARCHAR(500) NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,

    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    expiry_date DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_sd_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id) ON DELETE CASCADE,
    CONSTRAINT fk_sd_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_sd_type CHECK (document_type IN ('CONTRACT', 'TAX_CERTIFICATE', 'PRICE_LIST', 'PRODUCT_CATALOG', 'BANK_DETAILS', 'AGREEMENT', 'COMPLIANCE', 'OTHER'))
);

CREATE INDEX ix_sd_supplier ON purchasing.supplier_documents(supplier_id);

-- ============================================================
-- 07.21 SUPPLIER RATING
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.supplier_ratings (
    supplier_rating_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    company_id UUID NOT NULL,

    rating_date DATE NOT NULL DEFAULT CURRENT_DATE,
    rated_by_user_id UUID NULL,

    delivery_score NUMERIC(3,2) NULL,
    quality_score NUMERIC(3,2) NULL,
    pricing_score NUMERIC(3,2) NULL,
    communication_score NUMERIC(3,2) NULL,
    overall_score NUMERIC(3,2) NULL,

    comments TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sr_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id) ON DELETE CASCADE,
    CONSTRAINT fk_sr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sr_rated_by FOREIGN KEY (rated_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_sr_scores CHECK (
        (delivery_score IS NULL OR (delivery_score >= 0 AND delivery_score <= 5)) AND
        (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 5)) AND
        (pricing_score IS NULL OR (pricing_score >= 0 AND pricing_score <= 5)) AND
        (communication_score IS NULL OR (communication_score >= 0 AND communication_score <= 5)) AND
        (overall_score IS NULL OR (overall_score >= 0 AND overall_score <= 5))
    )
);

CREATE INDEX ix_sr_supplier ON purchasing.supplier_ratings(supplier_id);

-- ============================================================
-- 07.22 PURCHASE JOURNAL ENTRIES (Accounting Integration)
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.purchase_journal_entries (
    purchase_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    purchase_order_id UUID NULL,
    supplier_invoice_id UUID NULL,
    supplier_payment_id UUID NULL,
    journal_entry_id UUID NULL,

    posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
    debit_account_id UUID NULL,
    credit_account_id UUID NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pje_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pje_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id),
    CONSTRAINT fk_pje_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES purchasing.supplier_invoices(supplier_invoice_id),
    CONSTRAINT fk_pje_payment FOREIGN KEY (supplier_payment_id) REFERENCES purchasing.supplier_payments(supplier_payment_id),
    CONSTRAINT fk_pje_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_pje_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_pje_po ON purchasing.purchase_journal_entries(purchase_order_id);
CREATE INDEX ix_pje_invoice ON purchasing.purchase_journal_entries(supplier_invoice_id);

-- ============================================================
-- 07.23 PURCHASE STATUS HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS purchasing.po_status_history (
    po_status_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    from_status_id UUID NULL,
    to_status_id UUID NOT NULL,

    status_notes TEXT NULL,
    changed_by_user_id UUID NULL,

    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_psh_po FOREIGN KEY (purchase_order_id) REFERENCES purchasing.purchase_orders(purchase_order_id) ON DELETE CASCADE,
    CONSTRAINT fk_psh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_psh_from_status FOREIGN KEY (from_status_id) REFERENCES purchasing.po_status_lookup(po_status_id),
    CONSTRAINT fk_psh_to_status FOREIGN KEY (to_status_id) REFERENCES purchasing.po_status_lookup(po_status_id)
);

CREATE INDEX ix_psh_po ON purchasing.po_status_history(purchase_order_id);

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

    -- Seed payment terms
    INSERT INTO purchasing.payment_terms (company_id, terms_code, terms_name, description, days_to_pay) VALUES
        (v_company_id, 'IMMEDIATE', 'Immediate Payment', 'Payment due immediately.', 0),
        (v_company_id, 'NET-15', 'Net 15 Days', 'Payment due in 15 days.', 15),
        (v_company_id, 'NET-30', 'Net 30 Days', 'Payment due in 30 days.', 30),
        (v_company_id, 'NET-45', 'Net 45 Days', 'Payment due in 45 days.', 45),
        (v_company_id, 'NET-60', 'Net 60 Days', 'Payment due in 60 days.', 60),
        (v_company_id, 'NET-90', 'Net 90 Days', 'Payment due in 90 days.', 90)
    ON CONFLICT (company_id, terms_code) DO NOTHING;

    -- Seed sample suppliers
    INSERT INTO purchasing.suppliers (company_id, supplier_code, supplier_name, email, phone, currency_id, payment_terms_id)
    SELECT v_company_id, 'SUP-001', 'TechWorld Distributors', 'sales@techworld.com', '+92-21-1234567', v_currency_id,
           (SELECT payment_terms_id FROM purchasing.payment_terms WHERE company_id = v_company_id AND terms_code = 'NET-30')
    WHERE NOT EXISTS (SELECT 1 FROM purchasing.suppliers WHERE company_id = v_company_id AND supplier_code = 'SUP-001');

    INSERT INTO purchasing.suppliers (company_id, supplier_code, supplier_name, email, phone, currency_id, payment_terms_id)
    SELECT v_company_id, 'SUP-002', 'Global Electronics Ltd', 'info@globalelec.com', '+92-21-9876543', v_currency_id,
           (SELECT payment_terms_id FROM purchasing.payment_terms WHERE company_id = v_company_id AND terms_code = 'NET-45')
    WHERE NOT EXISTS (SELECT 1 FROM purchasing.suppliers WHERE company_id = v_company_id AND supplier_code = 'SUP-002');

    INSERT INTO purchasing.suppliers (company_id, supplier_code, supplier_name, email, phone, currency_id, payment_terms_id)
    SELECT v_company_id, 'SUP-003', 'Fashion House Pakistan', 'orders@fashionhouse.pk', '+92-21-5551234', v_currency_id,
           (SELECT payment_terms_id FROM purchasing.payment_terms WHERE company_id = v_company_id AND terms_code = 'NET-15')
    WHERE NOT EXISTS (SELECT 1 FROM purchasing.suppliers WHERE company_id = v_company_id AND supplier_code = 'SUP-003');

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 07 Purchasing & Suppliers
-- 23 Tables + 5 Lookup Tables + Seed Data
-- ============================================================