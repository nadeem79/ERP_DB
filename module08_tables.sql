BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 08: SALES ORDERS / ORDER MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   An order is a commercial commitment;
--   payment/shipping/fulfillment are separate operational events.
--   Order status flow: DRAFT → CONFIRMED → PROCESSING → SHIPPED → DELIVERED
-- ============================================================
-- Components:
--   08.1  Sales Orders (existing - enhanced)
--   08.2  Order Items (existing - enhanced)
--   08.3  Order Status History
--   08.4  Order Notes
--   08.5  Order Documents
--   08.6  Order Tags
--   08.7  Order Holds
--   08.8  Order Fulfillment
--   08.9  Order Shipping
--   08.10 Order Payments
--   08.11 Order Cancellations
--   08.12 Order Priority
--   08.13 Order Notifications
--   08.14 Order Custom Fields
--   08.15 Order Accounting Integration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS sales;

-- ============================================================
-- 08.1 ORDER STATUS LOOKUP (if not exists)
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_status_lookup (
    order_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO sales.order_status_lookup (code, name, description, is_terminal, sort_order) VALUES
    ('DRAFT', 'Draft', 'Order is being created.', FALSE, 10),
    ('PENDING', 'Pending', 'Order awaiting confirmation.', FALSE, 20),
    ('CONFIRMED', 'Confirmed', 'Order confirmed.', FALSE, 30),
    ('PROCESSING', 'Processing', 'Order being processed.', FALSE, 40),
    ('PARTIALLY_SHIPPED', 'Partially Shipped', 'Part of order shipped.', FALSE, 50),
    ('SHIPPED', 'Shipped', 'Order shipped.', FALSE, 60),
    ('OUT_FOR_DELIVERY', 'Out for Delivery', 'Order out for delivery.', FALSE, 70),
    ('DELIVERED', 'Delivered', 'Order delivered.', TRUE, 80),
    ('COMPLETED', 'Completed', 'Order completed.', TRUE, 90),
    ('ON_HOLD', 'On Hold', 'Order on hold.', FALSE, 100),
    ('CANCELLED', 'Cancelled', 'Order cancelled.', TRUE, 110),
    ('RETURNED', 'Returned', 'Order returned.', TRUE, 120),
    ('REFUNDED', 'Refunded', 'Order refunded.', TRUE, 130)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 08.2 SALES CHANNEL LOOKUP (if not exists)
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.sales_channel_lookup (
    sales_channel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    channel_type VARCHAR(30) NOT NULL DEFAULT 'ONLINE',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO sales.sales_channel_lookup (code, name, description, channel_type, sort_order) VALUES
    ('WEBSITE', 'Website', 'Online website orders.', 'ONLINE', 10),
    ('POS', 'POS', 'Point of Sale orders.', 'OFFLINE', 20),
    ('MOBILE_APP', 'Mobile App', 'Mobile app orders.', 'ONLINE', 30),
    ('PHONE', 'Phone', 'Phone orders.', 'OFFLINE', 40),
    ('EMAIL', 'Email', 'Email orders.', 'OFFLINE', 50),
    ('WHATSAPP', 'WhatsApp', 'WhatsApp orders.', 'OFFLINE', 60),
    ('MARKETPLACE', 'Marketplace', 'Marketplace orders.', 'ONLINE', 70),
    ('SOCIAL_MEDIA', 'Social Media', 'Social media orders.', 'ONLINE', 80),
    ('B2B_PORTAL', 'B2B Portal', 'B2B portal orders.', 'ONLINE', 90),
    ('MANUAL', 'Manual', 'Manually created orders.', 'OFFLINE', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 08.3 ORDER PRIORITY LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_priority_lookup (
    order_priority_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO sales.order_priority_lookup (code, name, description, sort_order) VALUES
    ('LOW', 'Low', 'Low priority order.', 10),
    ('NORMAL', 'Normal', 'Normal priority order.', 20),
    ('HIGH', 'High', 'High priority order.', 30),
    ('URGENT', 'Urgent', 'Urgent priority order.', 40),
    ('CRITICAL', 'Critical', 'Critical priority order.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 08.4 ORDER HOLD REASON LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_hold_reason_lookup (
    order_hold_reason_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO sales.order_hold_reason_lookup (code, name, description, requires_approval, sort_order) VALUES
    ('PAYMENT_PENDING', 'Payment Pending', 'Awaiting payment confirmation.', FALSE, 10),
    ('FRAUD_SUSPECTED', 'Fraud Suspected', 'Suspected fraudulent order.', TRUE, 20),
    ('ADDRESS_VERIFICATION', 'Address Verification', 'Address needs verification.', FALSE, 30),
    ('STOCK_ISSUE', 'Stock Issue', 'Stock availability issue.', FALSE, 40),
    ('PRICING_ISSUE', 'Pricing Issue', 'Pricing discrepancy.', TRUE, 50),
    ('CUSTOMER_REQUEST', 'Customer Request', 'Customer requested hold.', FALSE, 60),
    ('MANUAL_REVIEW', 'Manual Review', 'Requires manual review.', TRUE, 70),
    ('CREDIT_LIMIT', 'Credit Limit', 'Customer credit limit exceeded.', TRUE, 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 08.5 ORDER CANCELLATION REASON LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_cancellation_reason_lookup (
    order_cancellation_reason_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_customer_initiated BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO sales.order_cancellation_reason_lookup (code, name, description, is_customer_initiated, sort_order) VALUES
    ('CUSTOMER_REQUEST', 'Customer Request', 'Customer requested cancellation.', TRUE, 10),
    ('CHANGED_MIND', 'Changed Mind', 'Customer changed their mind.', TRUE, 20),
    ('FOUND_BETTER_PRICE', 'Found Better Price', 'Customer found better price.', TRUE, 30),
    ('ORDER_ERROR', 'Order Error', 'Order placed by mistake.', TRUE, 40),
    ('PAYMENT_FAILED', 'Payment Failed', 'Payment could not be processed.', FALSE, 50),
    ('STOCK_UNAVAILABLE', 'Stock Unavailable', 'Items out of stock.', FALSE, 60),
    ('FRAUD', 'Fraud', 'Order identified as fraudulent.', FALSE, 70),
    ('DUPLICATE_ORDER', 'Duplicate Order', 'Duplicate order detected.', FALSE, 80),
    ('PRICING_ERROR', 'Pricing Error', 'Pricing error on order.', FALSE, 90),
    ('OTHER', 'Other', 'Other reason.', FALSE, 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 08.6 SALES ORDERS (Main Table - Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    sales_channel_id UUID NOT NULL,
    order_status_id UUID NOT NULL DEFAULT (SELECT order_status_id FROM sales.order_status_lookup WHERE code = 'DRAFT'),
    order_priority_id UUID NULL DEFAULT (SELECT order_priority_id FROM sales.order_priority_lookup WHERE code = 'NORMAL'),

    order_number VARCHAR(50) NOT NULL,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    order_time TIME NOT NULL DEFAULT CURRENT_TIME,

    -- Amounts
    subtotal_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    shipping_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    handling_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    grand_total NUMERIC(19,4) NOT NULL DEFAULT 0,
    paid_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    outstanding_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    exchange_rate NUMERIC(19,8) NOT NULL DEFAULT 1.0,

    -- Customer info (snapshot)
    customer_name VARCHAR(200) NULL,
    customer_email VARCHAR(300) NULL,
    customer_phone VARCHAR(50) NULL,

    -- Shipping address (snapshot)
    shipping_address_line1 VARCHAR(300) NULL,
    shipping_address_line2 VARCHAR(300) NULL,
    shipping_city VARCHAR(200) NULL,
    shipping_state VARCHAR(200) NULL,
    shipping_postal_code VARCHAR(20) NULL,
    shipping_country_id UUID NULL,

    -- Billing address (snapshot)
    billing_address_line1 VARCHAR(300) NULL,
    billing_address_line2 VARCHAR(300) NULL,
    billing_city VARCHAR(200) NULL,
    billing_state VARCHAR(200) NULL,
    billing_postal_code VARCHAR(20) NULL,
    billing_country_id UUID NULL,

    -- Shipping info
    shipping_method VARCHAR(100) NULL,
    shipping_provider VARCHAR(100) NULL,
    tracking_number VARCHAR(200) NULL,
    estimated_delivery_date DATE NULL,
    actual_delivery_date DATE NULL,

    -- Payment info
    payment_method VARCHAR(100) NULL,
    payment_status VARCHAR(30) NULL,
    is_cod BOOLEAN NOT NULL DEFAULT FALSE,

    -- Order metadata
    notes TEXT NULL,
    internal_notes TEXT NULL,
    customer_reference VARCHAR(200) NULL,
    purchase_order_number VARCHAR(100) NULL,

    -- Status tracking
    confirmed_at TIMESTAMPTZ NULL,
    processed_at TIMESTAMPTZ NULL,
    shipped_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,
    cancellation_reason_id UUID NULL,
    cancellation_notes TEXT NULL,

    -- Hold tracking
    is_on_hold BOOLEAN NOT NULL DEFAULT FALSE,
    hold_reason_id UUID NULL,
    hold_notes TEXT NULL,
    held_at TIMESTAMPTZ NULL,
    released_at TIMESTAMPTZ NULL,

    -- Fulfillment tracking
    fulfillment_status VARCHAR(30) NULL,
    fulfillment_notes TEXT NULL,

    -- Flags
    is_gift_order BOOLEAN NOT NULL DEFAULT FALSE,
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    is_wholesale BOOLEAN NOT NULL DEFAULT FALSE,
    requires_signature BOOLEAN NOT NULL DEFAULT FALSE,

    -- Source tracking
    source_url VARCHAR(500) NULL,
    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    -- IP and device
    ip_address INET NULL,
    user_agent TEXT NULL,
    device_type VARCHAR(30) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ord_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ord_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ord_channel FOREIGN KEY (sales_channel_id) REFERENCES sales.sales_channel_lookup(sales_channel_id),
    CONSTRAINT fk_ord_status FOREIGN KEY (order_status_id) REFERENCES sales.order_status_lookup(order_status_id),
    CONSTRAINT fk_ord_priority FOREIGN KEY (order_priority_id) REFERENCES sales.order_priority_lookup(order_priority_id),
    CONSTRAINT fk_ord_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_ord_cancel_reason FOREIGN KEY (cancellation_reason_id) REFERENCES sales.order_cancellation_reason_lookup(order_cancellation_reason_id),
    CONSTRAINT fk_ord_hold_reason FOREIGN KEY (hold_reason_id) REFERENCES sales.order_hold_reason_lookup(order_hold_reason_id),
    CONSTRAINT uq_order_number UNIQUE (company_id, order_number),
    CONSTRAINT ck_ord_amounts CHECK (subtotal_amount >= 0 AND grand_total >= 0 AND paid_amount >= 0),
    CONSTRAINT ck_ord_fulfillment CHECK (fulfillment_status IS NULL OR fulfillment_status IN ('PENDING', 'PROCESSING', 'PARTIALLY_FULFILLED', 'FULFILLED', 'CANCELLED'))
);

CREATE INDEX ix_ord_company ON sales.orders(company_id);
CREATE INDEX ix_ord_customer ON sales.orders(customer_id);
CREATE INDEX ix_ord_channel ON sales.orders(sales_channel_id);
CREATE INDEX ix_ord_status ON sales.orders(order_status_id);
CREATE INDEX ix_ord_date ON sales.orders(order_date);
CREATE INDEX ix_ord_priority ON sales.orders(order_priority_id);
CREATE INDEX ix_ord_hold ON sales.orders(is_on_hold);

-- ============================================================
-- 08.7 ORDER ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_items (
    order_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    product_name VARCHAR(300) NOT NULL,
    sku VARCHAR(100) NULL,
    barcode VARCHAR(100) NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    list_price NUMERIC(19,4) NULL,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_percent NUMERIC(5,2) NULL,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_rate NUMERIC(5,2) NULL,
    line_subtotal NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    -- Cost tracking
    cost_price NUMERIC(19,4) NULL,
    margin_amount NUMERIC(19,4) NULL,
    margin_percent NUMERIC(5,2) NULL,

    -- Fulfillment tracking
    shipped_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    returned_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    fulfilled_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    -- Warehouse info
    warehouse_id UUID NULL,
    location_id UUID NULL,
    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,

    -- Metadata
    notes TEXT NULL,
    is_gift_item BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_oi_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_oi_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_oi_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_oi_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT ck_oi_amounts CHECK (quantity >= 0 AND unit_price >= 0 AND line_total >= 0)
);

CREATE INDEX ix_oi_order ON sales.order_items(order_id);
CREATE INDEX ix_oi_product ON sales.order_items(product_id);
CREATE INDEX ix_oi_variant ON sales.order_items(product_variant_id);

-- ============================================================
-- 08.8 ORDER STATUS HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_status_history (
    order_status_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    from_status_id UUID NULL,
    to_status_id UUID NOT NULL,

    status_notes TEXT NULL,
    changed_by_user_id UUID NULL,

    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_osh_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_osh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_osh_from_status FOREIGN KEY (from_status_id) REFERENCES sales.order_status_lookup(order_status_id),
    CONSTRAINT fk_osh_to_status FOREIGN KEY (to_status_id) REFERENCES sales.order_status_lookup(order_status_id)
);

CREATE INDEX ix_osh_order ON sales.order_status_history(order_id);
CREATE INDEX ix_osh_changed ON sales.order_status_history(changed_at);

-- ============================================================
-- 08.9 ORDER NOTES
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_notes (
    order_note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    note_type VARCHAR(30) NOT NULL DEFAULT 'GENERAL',
    note_text TEXT NOT NULL,
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    is_visible_to_customer BOOLEAN NOT NULL DEFAULT FALSE,

    created_by_user_id UUID NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_on_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_on_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_on_user FOREIGN KEY (created_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_on_type CHECK (note_type IN ('GENERAL', 'INTERNAL', 'CUSTOMER', 'SHIPPING', 'PAYMENT', 'FULFILLMENT', 'OTHER'))
);

CREATE INDEX ix_on_order ON sales.order_notes(order_id);

-- ============================================================
-- 08.10 ORDER DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_documents (
    order_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
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

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_od_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_od_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_od_user FOREIGN KEY (created_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_od_type CHECK (document_type IN ('INVOICE', 'RECEIPT', 'PACKING_SLIP', 'SHIPPING_LABEL', 'CUSTOMS_DECLARATION', 'PHOTO', 'OTHER'))
);

CREATE INDEX ix_od_order ON sales.order_documents(order_id);

-- ============================================================
-- 08.11 ORDER TAGS
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_tags (
    order_tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    tag_name VARCHAR(100) NOT NULL,
    tag_color VARCHAR(20) NULL,
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ot_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_tag_name UNIQUE (company_id, tag_name)
);

CREATE INDEX ix_ot_company ON sales.order_tags(company_id);

CREATE TABLE IF NOT EXISTS sales.order_tag_assignments (
    order_tag_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    order_tag_id UUID NOT NULL,

    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by_user_id UUID NULL,

    CONSTRAINT fk_ota_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_ota_tag FOREIGN KEY (order_tag_id) REFERENCES sales.order_tags(order_tag_id) ON DELETE CASCADE,
    CONSTRAINT uq_order_tag UNIQUE (order_id, order_tag_id)
);

CREATE INDEX ix_ota_order ON sales.order_tag_assignments(order_id);
CREATE INDEX ix_ota_tag ON sales.order_tag_assignments(order_tag_id);

-- ============================================================
-- 08.12 ORDER HOLDS
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_holds (
    order_hold_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,
    hold_reason_id UUID NOT NULL,

    hold_notes TEXT NULL,
    held_by_user_id UUID NULL,
    held_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    released_at TIMESTAMPTZ NULL,
    released_by_user_id UUID NULL,
    release_notes TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_oh_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_oh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_oh_reason FOREIGN KEY (hold_reason_id) REFERENCES sales.order_hold_reason_lookup(order_hold_reason_id),
    CONSTRAINT fk_oh_held_by FOREIGN KEY (held_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_oh_released_by FOREIGN KEY (released_by_user_id) REFERENCES identity.users(user_id)
);

CREATE INDEX ix_oh_order ON sales.order_holds(order_id);
CREATE INDEX ix_oh_active ON sales.order_holds(is_active);

-- ============================================================
-- 08.13 ORDER FULFILLMENT
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_fulfillments (
    order_fulfillment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    fulfillment_number VARCHAR(50) NOT NULL,
    fulfillment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    warehouse_id UUID NULL,
    fulfillment_notes TEXT NULL,

    fulfilled_at TIMESTAMPTZ NULL,
    fulfilled_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_of_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_of_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_of_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_of_user FOREIGN KEY (fulfilled_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_fulfillment_number UNIQUE (company_id, fulfillment_number),
    CONSTRAINT ck_of_status CHECK (fulfillment_status IN ('PENDING', 'PROCESSING', 'PARTIALLY_FULFILLED', 'FULFILLED', 'CANCELLED'))
);

CREATE INDEX ix_of_order ON sales.order_fulfillments(order_id);
CREATE INDEX ix_of_status ON sales.order_fulfillments(fulfillment_status);

-- Fulfillment Items
CREATE TABLE IF NOT EXISTS sales.order_fulfillment_items (
    order_fulfillment_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_fulfillment_id UUID NOT NULL,
    order_item_id UUID NOT NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    fulfilled_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ofi_fulfillment FOREIGN KEY (order_fulfillment_id) REFERENCES sales.order_fulfillments(order_fulfillment_id) ON DELETE CASCADE,
    CONSTRAINT fk_ofi_item FOREIGN KEY (order_item_id) REFERENCES sales.order_items(order_item_id),
    CONSTRAINT ck_ofi_quantity CHECK (quantity >= 0 AND fulfilled_quantity >= 0)
);

CREATE INDEX ix_ofi_fulfillment ON sales.order_fulfillment_items(order_fulfillment_id);

-- ============================================================
-- 08.14 ORDER SHIPPING
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_shipments (
    order_shipment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    shipment_number VARCHAR(50) NOT NULL,
    shipping_provider VARCHAR(100) NULL,
    shipping_method VARCHAR(100) NULL,
    tracking_number VARCHAR(200) NULL,
    tracking_url VARCHAR(500) NULL,

    shipped_at TIMESTAMPTZ NULL,
    estimated_delivery_date DATE NULL,
    actual_delivery_date DATE NULL,

    shipping_cost NUMERIC(19,4) NULL,
    currency_id UUID NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_os_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_os_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_os_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_shipment_number UNIQUE (company_id, shipment_number),
    CONSTRAINT ck_os_status CHECK (status IN ('PENDING', 'SHIPPED', 'IN_TRANSIT', 'DELIVERED', 'RETURNED', 'LOST'))
);

CREATE INDEX ix_os_order ON sales.order_shipments(order_id);
CREATE INDEX ix_os_status ON sales.order_shipments(status);

-- ============================================================
-- 08.15 ORDER PAYMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_payments (
    order_payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    payment_method VARCHAR(100) NOT NULL,
    payment_gateway VARCHAR(100) NULL,
    payment_reference VARCHAR(200) NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    payment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    payment_date TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_op_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_op_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_op_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_op_amount CHECK (amount >= 0),
    CONSTRAINT ck_op_status CHECK (payment_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'REFUNDED'))
);

CREATE INDEX ix_op_order ON sales.order_payments(order_id);
CREATE INDEX ix_op_status ON sales.order_payments(payment_status);

-- ============================================================
-- 08.16 ORDER CANCELLATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_cancellations (
    order_cancellation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,
    cancellation_reason_id UUID NOT NULL,

    cancellation_notes TEXT NULL,
    cancelled_by_user_id UUID NULL,
    is_customer_initiated BOOLEAN NOT NULL DEFAULT TRUE,

    refund_required BOOLEAN NOT NULL DEFAULT FALSE,
    refund_amount NUMERIC(19,4) NULL,
    refund_status VARCHAR(30) NULL,

    cancelled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_oc_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_oc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_oc_reason FOREIGN KEY (cancellation_reason_id) REFERENCES sales.order_cancellation_reason_lookup(order_cancellation_reason_id),
    CONSTRAINT fk_oc_user FOREIGN KEY (cancelled_by_user_id) REFERENCES identity.users(user_id)
);

CREATE INDEX ix_oc_order ON sales.order_cancellations(order_id);

-- ============================================================
-- 08.17 ORDER CUSTOM FIELDS
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_custom_fields (
    order_custom_field_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    company_id UUID NOT NULL,

    field_name VARCHAR(100) NOT NULL,
    field_value TEXT NULL,
    field_type VARCHAR(30) NOT NULL DEFAULT 'TEXT',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ocf_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_ocf_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_ocf_type CHECK (field_type IN ('TEXT', 'NUMBER', 'DATE', 'BOOLEAN', 'JSON'))
);

CREATE INDEX ix_ocf_order ON sales.order_custom_fields(order_id);

-- ============================================================
-- 08.18 ORDER JOURNAL ENTRIES (Accounting Integration)
-- ============================================================

CREATE TABLE IF NOT EXISTS sales.order_journal_entries (
    order_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

    CONSTRAINT fk_oje_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_oje_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_oje_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_oje_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_oje_order ON sales.order_journal_entries(order_id);

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

    -- Seed order tags
    INSERT INTO sales.order_tags (company_id, tag_name, tag_color, description) VALUES
        (v_company_id, 'VIP', '#FFD700', 'VIP customer order.'),
        (v_company_id, 'WHOLESALE', '#4CAF50', 'Wholesale order.'),
        (v_company_id, 'GIFT', '#E91E63', 'Gift order.'),
        (v_company_id, 'FRAGILE', '#FF9800', 'Fragile items order.'),
        (v_company_id, 'RUSH', '#F44336', 'Rush delivery order.')
    ON CONFLICT (company_id, tag_name) DO NOTHING;

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 08 Sales Orders
-- 18 Tables + 5 Lookup Tables + Seed Data
-- ============================================================