BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 11: RETURNS / EXCHANGES / REFUNDS
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   A return is a customer-initiated request;
--   refund/exchange is the financial/operational resolution.
--   Returns must integrate with Orders, Inventory, Payments, Accounting.
-- ============================================================
-- Components:
--   11.1  Return Requests
--   11.2  Return Request Items
--   11.3  Return Reasons
--   11.4  Return Shipments
--   11.5  Return Inspections
--   11.6  Refunds
--   11.7  Refund Methods
--   11.8  Exchange Orders
--   11.9  Exchange Items
--   11.10  Return Inventory Impact
--   11.11  Return Policies
--   11.12  Return Approvals
--   11.13  Return Notifications
--   11.14  Accounting Integration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS returns;

-- ============================================================
-- 11.1 RETURN REQUEST STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_status_lookup (
    return_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO returns.return_status_lookup (code, name, description, is_terminal, sort_order) VALUES
    ('REQUESTED', 'Requested', 'Return request submitted by customer.', FALSE, 10),
    ('PENDING_APPROVAL', 'Pending Approval', 'Awaiting manager approval.', FALSE, 20),
    ('APPROVED', 'Approved', 'Return approved.', FALSE, 30),
    ('REJECTED', 'Rejected', 'Return rejected.', TRUE, 40),
    ('ITEMS_RECEIVED', 'Items Received', 'Items received at warehouse.', FALSE, 50),
    ('INSPECTION_PENDING', 'Inspection Pending', 'Items awaiting inspection.', FALSE, 60),
    ('INSPECTION_COMPLETED', 'Inspection Completed', 'Inspection completed.', FALSE, 70),
    ('REFUND_PROCESSING', 'Refund Processing', 'Refund being processed.', FALSE, 80),
    ('REFUND_COMPLETED', 'Refund Completed', 'Refund completed.', TRUE, 90),
    ('EXCHANGE_PROCESSING', 'Exchange Processing', 'Exchange being processed.', FALSE, 100),
    ('EXCHANGE_COMPLETED', 'Exchange Completed', 'Exchange completed.', TRUE, 110),
    ('CANCELLED', 'Cancelled', 'Return request cancelled.', TRUE, 120)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 11.2 RETURN TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_type_lookup (
    return_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    requires_inspection BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO returns.return_type_lookup (code, name, description, requires_inspection, sort_order) VALUES
    ('RETURN_REFUND', 'Return & Refund', 'Customer returns items for refund.', TRUE, 10),
    ('EXCHANGE', 'Exchange', 'Customer exchanges items for different items.', TRUE, 20),
    ('REFUND_ONLY', 'Refund Only', 'Refund without physical return.', FALSE, 30),
    ('WARRANTY_CLAIM', 'Warranty Claim', 'Warranty replacement or repair.', TRUE, 40),
    ('DAMAGED_IN_TRANSIT', 'Damaged in Transit', 'Item damaged during shipping.', TRUE, 50),
    ('WRONG_ITEM', 'Wrong Item', 'Wrong item shipped.', TRUE, 60),
    ('DEFECTIVE', 'Defective', 'Defective product.', TRUE, 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 11.3 RETURN REASON LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_reason_lookup (
    return_reason_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    requires_photo BOOLEAN NOT NULL DEFAULT FALSE,
    requires_inspection BOOLEAN NOT NULL DEFAULT FALSE,
    is_customer_fault BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO returns.return_reason_lookup (code, name, description, requires_photo, requires_inspection, is_customer_fault, sort_order) VALUES
    ('DEFECTIVE', 'Defective Product', 'Product is defective or not working.', TRUE, TRUE, FALSE, 10),
    ('DAMAGED_IN_TRANSIT', 'Damaged in Transit', 'Product damaged during shipping.', TRUE, TRUE, FALSE, 20),
    ('WRONG_ITEM', 'Wrong Item', 'Wrong item received.', TRUE, TRUE, FALSE, 30),
    ('WRONG_SIZE', 'Wrong Size', 'Size does not fit.', FALSE, FALSE, TRUE, 40),
    ('CHANGED_MIND', 'Changed Mind', 'Customer changed their mind.', FALSE, FALSE, TRUE, 50),
    ('BETTER_PRICE', 'Better Price', 'Found better price elsewhere.', FALSE, FALSE, TRUE, 60),
    ('NOT_AS_DESCRIBED', 'Not as Described', 'Product not as described.', TRUE, TRUE, FALSE, 70),
    ('MISSING_PARTS', 'Missing Parts', 'Parts or accessories missing.', TRUE, TRUE, FALSE, 80),
    ('QUALITY_ISSUE', 'Quality Issue', 'Product quality below expectations.', TRUE, TRUE, FALSE, 90),
    ('DUPLICATE_ORDER', 'Duplicate Order', 'Duplicate order placed.', FALSE, FALSE, TRUE, 100),
    ('LATE_DELIVERY', 'Late Delivery', 'Delivery was too late.', FALSE, FALSE, FALSE, 110),
    ('OTHER', 'Other', 'Other reason.', FALSE, FALSE, FALSE, 120)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 11.4 INSPECTION RESULT LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.inspection_result_lookup (
    inspection_result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    allows_restocking BOOLEAN NOT NULL DEFAULT FALSE,
    allows_refund BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO returns.inspection_result_lookup (code, name, description, allows_restocking, allows_refund, sort_order) VALUES
    ('ACCEPTED_AS_IS', 'Accepted As-Is', 'Item accepted in received condition.', TRUE, TRUE, 10),
    ('ACCEPTED_WITH_DAMAGE', 'Accepted with Damage', 'Item accepted but damaged.', FALSE, TRUE, 20),
    ('REJECTED_DEFECTIVE', 'Rejected - Defective', 'Item rejected due to defect.', FALSE, FALSE, 30),
    ('REJECTED_DAMAGED', 'Rejected - Damaged', 'Item rejected due to damage.', FALSE, FALSE, 40),
    ('PARTIAL_ACCEPTANCE', 'Partial Acceptance', 'Only part of return accepted.', FALSE, TRUE, 50),
    ('REJECTED_NOT_ELIGIBLE', 'Rejected - Not Eligible', 'Return not eligible per policy.', FALSE, FALSE, 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 11.5 REFUND STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.refund_status_lookup (
    refund_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO returns.refund_status_lookup (code, name, description, is_terminal, sort_order) VALUES
    ('PENDING', 'Pending', 'Refund pending approval.', FALSE, 10),
    ('APPROVED', 'Approved', 'Refund approved.', FALSE, 20),
    ('PROCESSING', 'Processing', 'Refund being processed.', FALSE, 30),
    ('COMPLETED', 'Completed', 'Refund completed.', TRUE, 40),
    ('FAILED', 'Failed', 'Refund failed.', FALSE, 50),
    ('CANCELLED', 'Cancelled', 'Refund cancelled.', TRUE, 60),
    ('PARTIALLY_COMPLETED', 'Partially Completed', 'Partial refund completed.', FALSE, 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 11.6 REFUND METHOD LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.refund_method_lookup (
    refund_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO returns.refund_method_lookup (code, name, description, sort_order) VALUES
    ('ORIGINAL_PAYMENT', 'Original Payment Method', 'Refund to original payment method.', 10),
    ('STORE_CREDIT', 'Store Credit', 'Refund as store credit.', 20),
    ('BANK_TRANSFER', 'Bank Transfer', 'Refund via bank transfer.', 30),
    ('CASH', 'Cash', 'Refund in cash.', 40),
    ('CREDIT_NOTE', 'Credit Note', 'Refund as credit note.', 50),
    ('EXCHANGE', 'Exchange', 'Exchange for another product.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 11.7 RETURN REQUESTS (Main Table)
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_requests (
    return_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    order_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    return_status_id UUID NOT NULL DEFAULT (SELECT return_status_id FROM returns.return_status_lookup WHERE code = 'REQUESTED'),
    return_type_id UUID NOT NULL,
    return_reason_id UUID NULL,

    return_number VARCHAR(50) NOT NULL,
    request_date DATE NOT NULL DEFAULT CURRENT_DATE,
    requested_by_user_id UUID NULL,

    customer_comments TEXT NULL,
    admin_notes TEXT NULL,

    total_items INTEGER NOT NULL DEFAULT 0,
    total_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    restocking_fee NUMERIC(19,4) NOT NULL DEFAULT 0,
    shipping_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    -- Approval tracking
    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,

    -- Inspection tracking
    inspection_required BOOLEAN NOT NULL DEFAULT FALSE,
    inspection_completed BOOLEAN NOT NULL DEFAULT FALSE,
    inspected_by_user_id UUID NULL,
    inspected_at TIMESTAMPTZ NULL,

    -- Refund tracking
    refund_id UUID NULL,
    refund_completed_at TIMESTAMPTZ NULL,

    -- Exchange tracking
    exchange_order_id UUID NULL,
    exchange_completed_at TIMESTAMPTZ NULL,

    -- Return shipment tracking
    return_shipment_id UUID NULL,
    items_received BOOLEAN NOT NULL DEFAULT FALSE,
    items_received_at TIMESTAMPTZ NULL,

    -- Return window tracking
    return_window_days INTEGER NOT NULL DEFAULT 30,
    return_window_expires_at DATE NULL,

    -- RMA (Return Merchandise Authorization)
    rma_number VARCHAR(50) NULL,
    rma_issued_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rr_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_rr_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rr_status FOREIGN KEY (return_status_id) REFERENCES returns.return_status_lookup(return_status_id),
    CONSTRAINT fk_rr_type FOREIGN KEY (return_type_id) REFERENCES returns.return_type_lookup(return_type_id),
    CONSTRAINT fk_rr_reason FOREIGN KEY (return_reason_id) REFERENCES returns.return_reason_lookup(return_reason_id),
    CONSTRAINT fk_rr_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_return_number UNIQUE (company_id, return_number),
    CONSTRAINT ck_rr_amounts CHECK (refund_amount >= 0 AND restocking_fee >= 0 AND shipping_cost >= 0 AND total_refund_amount >= 0),
    CONSTRAINT ck_rr_quantity CHECK (total_quantity >= 0)
);

CREATE INDEX ix_rr_company ON returns.return_requests(company_id);
CREATE INDEX ix_rr_order ON returns.return_requests(order_id);
CREATE INDEX ix_rr_customer ON returns.return_requests(customer_id);
CREATE INDEX ix_rr_status ON returns.return_requests(return_status_id);
CREATE INDEX ix_rr_date ON returns.return_requests(request_date);

-- ============================================================
-- 11.8 RETURN REQUEST ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_request_items (
    return_request_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID NOT NULL,
    company_id UUID NOT NULL,
    order_item_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    restocking_fee NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    return_reason_id UUID NULL,
    item_comments TEXT NULL,

    -- Inspection fields
    inspection_result_id UUID NULL,
    inspection_notes TEXT NULL,
    inspected_quantity NUMERIC(19,4) NULL,
    accepted_quantity NUMERIC(19,4) NULL,
    rejected_quantity NUMERIC(19,4) NULL,

    -- Restocking fields
    restock_to_inventory BOOLEAN NOT NULL DEFAULT FALSE,
    restocked_quantity NUMERIC(19,4) NULL,
    restocked_at TIMESTAMPTZ NULL,
    restock_location_id UUID NULL,

    -- Exchange fields
    exchange_product_id UUID NULL,
    exchange_variant_id UUID NULL,
    exchange_quantity NUMERIC(19,4) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rri_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_rri_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rri_order_item FOREIGN KEY (order_item_id) REFERENCES sales.order_items(order_item_id),
    CONSTRAINT fk_rri_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rri_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_rri_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_rri_reason FOREIGN KEY (return_reason_id) REFERENCES returns.return_reason_lookup(return_reason_id),
    CONSTRAINT fk_rri_inspection_result FOREIGN KEY (inspection_result_id) REFERENCES returns.inspection_result_lookup(inspection_result_id),
    CONSTRAINT ck_rri_amounts CHECK (unit_price >= 0 AND refund_amount >= 0 AND restocking_fee >= 0),
    CONSTRAINT ck_rri_quantity CHECK (quantity >= 0)
);

CREATE INDEX ix_rri_return ON returns.return_request_items(return_request_id);
CREATE INDEX ix_rri_product ON returns.return_request_items(product_id);
CREATE INDEX ix_rri_order_item ON returns.return_request_items(order_item_id);

-- ============================================================
-- 11.9 RETURN SHIPMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_shipments (
    return_shipment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID NOT NULL,
    company_id UUID NOT NULL,

    shipment_number VARCHAR(50) NOT NULL,
    tracking_number VARCHAR(100) NULL,
    courier_name VARCHAR(100) NULL,

    shipped_at TIMESTAMPTZ NULL,
    received_at TIMESTAMPTZ NULL,
    received_by_user_id UUID NULL,
    received_location_id UUID NULL,

    shipping_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rs_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_rs_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rs_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_shipment_number UNIQUE (company_id, shipment_number),
    CONSTRAINT ck_rs_status CHECK (status IN ('PENDING', 'SHIPPED', 'IN_TRANSIT', 'RECEIVED', 'LOST', 'CANCELLED'))
);

CREATE INDEX ix_rs_return ON returns.return_shipments(return_request_id);

-- ============================================================
-- 11.10 RETURN INSPECTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_inspections (
    return_inspection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID NOT NULL,
    company_id UUID NOT NULL,

    inspection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    inspected_by_user_id UUID NULL,

    overall_result VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    inspection_notes TEXT NULL,

    total_items_inspected INTEGER NOT NULL DEFAULT 0,
    total_items_accepted INTEGER NOT NULL DEFAULT 0,
    total_items_rejected INTEGER NOT NULL DEFAULT 0,

    photos_taken INTEGER NOT NULL DEFAULT 0,
    photo_urls TEXT[] NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ri_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_ri_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_ri_result CHECK (overall_result IN ('PENDING', 'ACCEPTED', 'PARTIALLY_ACCEPTED', 'REJECTED'))
);

CREATE INDEX ix_ri_return ON returns.return_inspections(return_request_id);

-- ============================================================
-- 11.11 REFUNDS
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.refunds (
    refund_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    return_request_id UUID NOT NULL,
    order_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    refund_status_id UUID NOT NULL DEFAULT (SELECT refund_status_id FROM returns.refund_status_lookup WHERE code = 'PENDING'),
    refund_method_id UUID NOT NULL,

    refund_number VARCHAR(50) NOT NULL,
    refund_date DATE NOT NULL DEFAULT CURRENT_DATE,

    refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    restocking_fee NUMERIC(19,4) NOT NULL DEFAULT 0,
    shipping_refund NUMERIC(19,4) NOT NULL DEFAULT 0,
    net_refund_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    -- Payment gateway tracking
    payment_id UUID NULL,
    payment_gateway VARCHAR(100) NULL,
    gateway_refund_id VARCHAR(200) NULL,
    gateway_refunded_at TIMESTAMPTZ NULL,

    -- Store credit tracking
    store_credit_amount NUMERIC(19,4) NULL,
    store_credit_issued BOOLEAN NOT NULL DEFAULT FALSE,

    -- Approval tracking
    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,

    -- Processing tracking
    processed_by_user_id UUID NULL,
    processed_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,

    refund_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ref_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ref_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id),
    CONSTRAINT fk_ref_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_ref_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ref_status FOREIGN KEY (refund_status_id) REFERENCES returns.refund_status_lookup(refund_status_id),
    CONSTRAINT fk_ref_method FOREIGN KEY (refund_method_id) REFERENCES returns.refund_method_lookup(refund_method_id),
    CONSTRAINT fk_ref_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_ref_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id),
    CONSTRAINT uq_refund_number UNIQUE (company_id, refund_number),
    CONSTRAINT ck_ref_amounts CHECK (refund_amount >= 0 AND restocking_fee >= 0 AND net_refund_amount >= 0)
);

CREATE INDEX ix_ref_company ON returns.refunds(company_id);
CREATE INDEX ix_ref_return ON returns.refunds(return_request_id);
CREATE INDEX ix_ref_customer ON returns.refunds(customer_id);
CREATE INDEX ix_ref_status ON returns.refunds(refund_status_id);
CREATE INDEX ix_ref_date ON returns.refunds(refund_date);

-- ============================================================
-- 11.12 EXCHANGE ORDERS
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.exchange_orders (
    exchange_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID NOT NULL,
    company_id UUID NOT NULL,
    original_order_id UUID NOT NULL,
    new_order_id UUID NULL,
    customer_id UUID NOT NULL,

    exchange_number VARCHAR(50) NOT NULL,
    exchange_date DATE NOT NULL DEFAULT CURRENT_DATE,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    price_difference NUMERIC(19,4) NOT NULL DEFAULT 0,
    additional_charge NUMERIC(19,4) NOT NULL DEFAULT 0,
    refund_due NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    exchange_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_eo_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id),
    CONSTRAINT fk_eo_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_eo_original_order FOREIGN KEY (original_order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_eo_new_order FOREIGN KEY (new_order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_eo_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_eo_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_exchange_number UNIQUE (company_id, exchange_number),
    CONSTRAINT ck_eo_status CHECK (status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'COMPLETED', 'CANCELLED'))
);

CREATE INDEX ix_eo_return ON returns.exchange_orders(return_request_id);
CREATE INDEX ix_eo_customer ON returns.exchange_orders(customer_id);

-- ============================================================
-- 11.13 EXCHANGE ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.exchange_items (
    exchange_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exchange_order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    -- Original item being returned
    original_product_id UUID NOT NULL,
    original_variant_id UUID NULL,
    original_quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    original_price NUMERIC(19,4) NOT NULL DEFAULT 0,

    -- New item being exchanged for
    new_product_id UUID NOT NULL,
    new_variant_id UUID NULL,
    new_quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    new_price NUMERIC(19,4) NOT NULL DEFAULT 0,

    price_difference NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ei_exchange FOREIGN KEY (exchange_order_id) REFERENCES returns.exchange_orders(exchange_order_id) ON DELETE CASCADE,
    CONSTRAINT fk_ei_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ei_orig_product FOREIGN KEY (original_product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ei_orig_variant FOREIGN KEY (original_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_ei_new_product FOREIGN KEY (new_product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ei_new_variant FOREIGN KEY (new_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_ei_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_ei_exchange ON returns.exchange_items(exchange_order_id);

-- ============================================================
-- 11.14 RETURN POLICIES
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_policies (
    return_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    policy_code VARCHAR(50) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    return_window_days INTEGER NOT NULL DEFAULT 30,
    requires_receipt BOOLEAN NOT NULL DEFAULT TRUE,
    requires_original_packaging BOOLEAN NOT NULL DEFAULT FALSE,
    requires_inspection BOOLEAN NOT NULL DEFAULT FALSE,
    requires_approval BOOLEAN NOT NULL DEFAULT TRUE,

    restocking_fee_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    max_restocking_fee NUMERIC(19,4) NULL,

    allows_exchange BOOLEAN NOT NULL DEFAULT TRUE,
    allows_store_credit BOOLEAN NOT NULL DEFAULT TRUE,
    allows_cash_refund BOOLEAN NOT NULL DEFAULT TRUE,

    excluded_product_categories UUID[] NULL,
    excluded_product_types UUID[] NULL,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    effective_from DATE NULL,
    effective_to DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_policy_code UNIQUE (company_id, policy_code),
    CONSTRAINT ck_rp_window CHECK (return_window_days >= 0),
    CONSTRAINT ck_rp_fee CHECK (restocking_fee_percent >= 0 AND restocking_fee_percent <= 100)
);

CREATE INDEX ix_rp_company ON returns.return_policies(company_id);

-- ============================================================
-- 11.15 RETURN APPROVALS
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_approvals (
    return_approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID NOT NULL,
    company_id UUID NOT NULL,

    approval_level INTEGER NOT NULL DEFAULT 1,
    required_role_code VARCHAR(50) NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,
    approval_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ra_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_ra_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_ra_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'ESCALATED'))
);

CREATE INDEX ix_ra_return ON returns.return_approvals(return_request_id);

-- ============================================================
-- 11.16 RETURN ATTACHMENTS (Photos/Documents)
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_attachments (
    return_attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID NOT NULL,
    company_id UUID NOT NULL,

    attachment_type VARCHAR(30) NOT NULL DEFAULT 'PHOTO',
    file_name VARCHAR(500) NOT NULL,
    content_type VARCHAR(200) NULL,
    storage_path VARCHAR(1000) NULL,
    file_size_bytes BIGINT NULL,
    description TEXT NULL,

    uploaded_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ratt_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_ratt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_ratt_type CHECK (attachment_type IN ('PHOTO', 'DOCUMENT', 'RECEIPT', 'OTHER'))
);

CREATE INDEX ix_ratt_return ON returns.return_attachments(return_request_id);

-- ============================================================
-- 11.17 RETURN ACCOUNTING INTEGRATION
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_journal_entries (
    return_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    return_request_id UUID NULL,
    refund_id UUID NULL,
    journal_entry_id UUID NULL,

    posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
    debit_account_id UUID NULL,
    credit_account_id UUID NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rje_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rje_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id),
    CONSTRAINT fk_rje_refund FOREIGN KEY (refund_id) REFERENCES returns.refunds(refund_id),
    CONSTRAINT fk_rje_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_rje_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_rje_return ON returns.return_journal_entries(return_request_id);

-- ============================================================
-- 11.18 RETURN STATUS HISTORY (Audit Trail)
-- ============================================================

CREATE TABLE IF NOT EXISTS returns.return_status_history (
    return_status_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID NOT NULL,
    company_id UUID NOT NULL,

    from_status_id UUID NULL,
    to_status_id UUID NOT NULL,

    changed_by_user_id UUID NULL,
    change_notes TEXT NULL,

    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rsh_return FOREIGN KEY (return_request_id) REFERENCES returns.return_requests(return_request_id) ON DELETE CASCADE,
    CONSTRAINT fk_rsh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rsh_from_status FOREIGN KEY (from_status_id) REFERENCES returns.return_status_lookup(return_status_id),
    CONSTRAINT fk_rsh_to_status FOREIGN KEY (to_status_id) REFERENCES returns.return_status_lookup(return_status_id)
);

CREATE INDEX ix_rsh_return ON returns.return_status_history(return_request_id);

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

    -- Seed default return policy
    INSERT INTO returns.return_policies (company_id, policy_code, policy_name, description, return_window_days, requires_receipt, requires_inspection, requires_approval, restocking_fee_percent, is_default)
    SELECT v_company_id, 'DEFAULT-RETURN', 'Standard Return Policy', 'Standard 30-day return policy.', 30, TRUE, FALSE, TRUE, 0, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM returns.return_policies WHERE company_id = v_company_id AND policy_code = 'DEFAULT-RETURN');

    -- Seed extended return policy
    INSERT INTO returns.return_policies (company_id, policy_code, policy_name, description, return_window_days, requires_receipt, requires_inspection, requires_approval, restocking_fee_percent, is_default)
    SELECT v_company_id, 'EXTENDED-RETURN', 'Extended Return Policy', 'Extended 60-day return policy for VIP customers.', 60, TRUE, FALSE, TRUE, 0, FALSE
    WHERE NOT EXISTS (SELECT 1 FROM returns.return_policies WHERE company_id = v_company_id AND policy_code = 'EXTENDED-RETURN');

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 11 Returns
-- 18 Tables + 7 Lookup Tables + Seed Data
-- ============================================================