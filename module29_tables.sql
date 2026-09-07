BEGIN;

-- ============================================================
-- MODULE 29 — CART, CHECKOUT & SHOPPING EXPERIENCE
-- DATABASE TABLES
-- ============================================================
-- Design Decisions:
--   1. Cart is not an order. Order is created only after final validation.
--   2. Wishlist is future intent; cart is current purchase intent.
--   3. Cart prices must be snapshotted, but validated before order creation.
--   4. Guest carts must be supported and merged on login.
--   5. Multi-device carts must support customer/session/device tracking.
--   6. Checkout is a workflow with validation steps, not a single submit button.
--   7. Inventory reservation is temporary and expires.
--   8. Shipping/tax/payment selections are checkout decisions.
--   9. Order creation must be idempotent.
--   10. Abandoned cart recovery uses Notification/Marketing modules.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cart;

-- ============================================================
-- 29.0 LOOKUP TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_status_lookup (
    cart_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_open BOOLEAN NOT NULL DEFAULT FALSE,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cart.cart_status_lookup (code, name, description, is_open, is_terminal, sort_order) VALUES
    ('ACTIVE', 'Active', 'Cart is active and editable.', TRUE, FALSE, 10),
    ('CHECKOUT_STARTED', 'Checkout Started', 'Customer started checkout.', TRUE, FALSE, 20),
    ('VALIDATING', 'Validating', 'Checkout validation in progress.', TRUE, FALSE, 30),
    ('PENDING_PAYMENT', 'Pending Payment', 'Cart validated and waiting for payment.', TRUE, FALSE, 40),
    ('ORDER_CREATED', 'Order Created', 'Order has been created from cart.', FALSE, TRUE, 50),
    ('ABANDONED', 'Abandoned', 'Cart is abandoned.', FALSE, FALSE, 60),
    ('EXPIRED', 'Expired', 'Cart expired.', FALSE, TRUE, 70),
    ('MERGED', 'Merged', 'Guest cart merged into customer cart.', FALSE, TRUE, 80),
    ('CANCELLED', 'Cancelled', 'Cart cancelled.', FALSE, TRUE, 90)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_open = EXCLUDED.is_open,
    is_terminal = EXCLUDED.is_terminal;

CREATE TABLE IF NOT EXISTS cart.cart_item_status_lookup (
    cart_item_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cart.cart_item_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Item is active in cart.', 10),
    ('SAVED_FOR_LATER', 'Saved for Later', 'Item moved to save for later.', 20),
    ('REMOVED', 'Removed', 'Item removed from cart.', 30),
    ('OUT_OF_STOCK', 'Out of Stock', 'Item unavailable.', 40),
    ('PRICE_CHANGED', 'Price Changed', 'Item price changed since added.', 50),
    ('NOT_PURCHASABLE', 'Not Purchasable', 'Item cannot be purchased.', 60),
    ('ORDERED', 'Ordered', 'Item converted to order item.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS cart.checkout_step_lookup (
    checkout_step_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cart.checkout_step_lookup (code, name, description, is_required, sort_order) VALUES
    ('CART_REVIEW', 'Cart Review', 'Review cart items and totals.', TRUE, 10),
    ('LOGIN_OR_GUEST', 'Login or Guest', 'Customer signs in or proceeds as guest.', TRUE, 20),
    ('ADDRESS', 'Address', 'Billing and shipping address selection.', TRUE, 30),
    ('SHIPPING', 'Shipping', 'Shipping method/rate selection.', TRUE, 40),
    ('PAYMENT', 'Payment', 'Payment method selection.', TRUE, 50),
    ('REVIEW', 'Review', 'Final checkout review.', TRUE, 60),
    ('PLACE_ORDER', 'Place Order', 'Final submit and order creation.', TRUE, 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS cart.checkout_validation_type_lookup (
    checkout_validation_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'ERROR',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT ck_checkout_validation_severity CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'BLOCKER'))
);

INSERT INTO cart.checkout_validation_type_lookup (code, name, description, severity, sort_order) VALUES
    ('CART_EXISTS', 'Cart Exists', 'Cart must exist.', 'BLOCKER', 10),
    ('CART_OWNERSHIP', 'Cart Ownership', 'Cart must belong to customer/session.', 'BLOCKER', 20),
    ('ITEM_EXISTS', 'Item Exists', 'Cart items must still exist.', 'BLOCKER', 30),
    ('PRODUCT_ACTIVE', 'Product Active', 'Products must be active.', 'BLOCKER', 40),
    ('VARIANT_ACTIVE', 'Variant Active', 'Variants must be active.', 'BLOCKER', 50),
    ('PURCHASABLE', 'Purchasable', 'Products must be purchasable.', 'BLOCKER', 60),
    ('REGIONAL_AVAILABILITY', 'Regional Availability', 'Products must be available in region.', 'ERROR', 70),
    ('CURRENT_PRICE', 'Current Price', 'Prices must be current.', 'ERROR', 80),
    ('PROMOTION_VALID', 'Promotion Valid', 'Promotions/coupons must still be valid.', 'ERROR', 90),
    ('CUSTOMER_ELIGIBILITY', 'Customer Eligibility', 'Customer must be eligible.', 'ERROR', 100),
    ('TAX_VALID', 'Tax Valid', 'Tax must be calculated.', 'ERROR', 110),
    ('SHIPPING_VALID', 'Shipping Valid', 'Shipping method/rate must be valid.', 'ERROR', 120),
    ('INVENTORY_AVAILABLE', 'Inventory Available', 'Inventory must be available/reserved.', 'BLOCKER', 130),
    ('CURRENCY_VALID', 'Currency Valid', 'Currency must be valid and accepted.', 'ERROR', 140),
    ('PAYMENT_METHOD_VALID', 'Payment Method Valid', 'Payment method must be valid.', 'BLOCKER', 150),
    ('ADDRESS_REQUIRED', 'Address Required', 'Required addresses must be present.', 'BLOCKER', 160),
    ('IDEMPOTENCY_VALID', 'Idempotency Valid', 'Order creation request must be idempotent.', 'BLOCKER', 170)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, severity = EXCLUDED.severity;

CREATE TABLE IF NOT EXISTS cart.cart_event_type_lookup (
    cart_event_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cart.cart_event_type_lookup (code, name, description, sort_order) VALUES
    ('CART_CREATED', 'Cart Created', 'Cart created.', 10),
    ('ITEM_ADDED', 'Item Added', 'Item added to cart.', 20),
    ('ITEM_UPDATED', 'Item Updated', 'Cart item updated.', 30),
    ('ITEM_REMOVED', 'Item Removed', 'Item removed from cart.', 40),
    ('COUPON_APPLIED', 'Coupon Applied', 'Coupon applied to cart.', 50),
    ('COUPON_REMOVED', 'Coupon Removed', 'Coupon removed from cart.', 60),
    ('CHECKOUT_STARTED', 'Checkout Started', 'Checkout started.', 70),
    ('ADDRESS_SELECTED', 'Address Selected', 'Address selected.', 80),
    ('SHIPPING_SELECTED', 'Shipping Selected', 'Shipping selected.', 90),
    ('PAYMENT_SELECTED', 'Payment Selected', 'Payment selected.', 100),
    ('VALIDATION_FAILED', 'Validation Failed', 'Checkout validation failed.', 110),
    ('ORDER_CREATED', 'Order Created', 'Order created from cart.', 120),
    ('CART_ABANDONED', 'Cart Abandoned', 'Cart abandoned.', 130),
    ('CART_RECOVERED', 'Cart Recovered', 'Cart recovered.', 140),
    ('CART_MERGED', 'Cart Merged', 'Guest cart merged.', 150)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS cart.recovery_status_lookup (
    recovery_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO cart.recovery_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Recovery pending.', 10),
    ('SENT', 'Sent', 'Recovery message sent.', 20),
    ('OPENED', 'Opened', 'Recovery message opened.', 30),
    ('CLICKED', 'Clicked', 'Recovery link clicked.', 40),
    ('RECOVERED', 'Recovered', 'Cart recovered.', 50),
    ('EXPIRED', 'Expired', 'Recovery expired.', 60),
    ('CANCELLED', 'Cancelled', 'Recovery cancelled.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 29.1 CARTS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.carts (
    cart_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    cart_status_id UUID NULL,

    customer_id UUID NULL,
    user_id UUID NULL,
    session_id VARCHAR(200) NULL,
    device_id VARCHAR(200) NULL,

    sales_channel_id UUID NULL,
    site_id UUID NULL,
    regional_profile_id UUID NULL,

    currency_id UUID NOT NULL,
    language_id UUID NULL,

    cart_token VARCHAR(150) NULL UNIQUE,
    cart_number VARCHAR(80) NULL,

    is_guest BOOLEAN NOT NULL DEFAULT TRUE,
    is_persistent BOOLEAN NOT NULL DEFAULT TRUE,
    is_multi_device BOOLEAN NOT NULL DEFAULT TRUE,

    item_count INTEGER NOT NULL DEFAULT 0,
    quantity_total INTEGER NOT NULL DEFAULT 0,

    subtotal_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    shipping_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    handling_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    grand_total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    pricing_snapshot_at TIMESTAMPTZ NULL,
    last_price_validation_at TIMESTAMPTZ NULL,
    last_inventory_validation_at TIMESTAMPTZ NULL,

    checkout_started_at TIMESTAMPTZ NULL,
    abandoned_at TIMESTAMPTZ NULL,
    recovered_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,

    merged_into_cart_id UUID NULL,
    merged_at TIMESTAMPTZ NULL,

    order_id UUID NULL,
    order_created_at TIMESTAMPTZ NULL,

    ip_address INET NULL,
    user_agent TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cart_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cart_status FOREIGN KEY (cart_status_id) REFERENCES cart.cart_status_lookup(cart_status_id),
    CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_cart_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_cart_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_cart_language FOREIGN KEY (language_id) REFERENCES localization.languages(language_id),
    CONSTRAINT fk_cart_regional_profile FOREIGN KEY (regional_profile_id) REFERENCES localization.regional_profiles(regional_profile_id),
    CONSTRAINT fk_cart_merged FOREIGN KEY (merged_into_cart_id) REFERENCES cart.carts(cart_id),
    CONSTRAINT fk_cart_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT ck_cart_customer_or_session CHECK (customer_id IS NOT NULL OR session_id IS NOT NULL),
    CONSTRAINT ck_cart_totals_nonnegative CHECK (
        subtotal_amount >= 0 AND discount_amount >= 0 AND tax_amount >= 0
        AND shipping_amount >= 0 AND handling_amount >= 0 AND grand_total_amount >= 0
    )
);

CREATE INDEX ix_cart_company ON cart.carts(company_id);
CREATE INDEX ix_cart_customer ON cart.carts(customer_id);
CREATE INDEX ix_cart_session ON cart.carts(session_id);
CREATE INDEX ix_cart_status ON cart.carts(cart_status_id);
CREATE INDEX ix_cart_updated ON cart.carts(updated_at DESC);
CREATE INDEX ix_cart_abandoned ON cart.carts(abandoned_at DESC);

-- ============================================================
-- 29.2 CART DEVICES / MULTI-DEVICE TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_devices (
    cart_device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,
    device_id VARCHAR(200) NOT NULL,

    device_type VARCHAR(30) NULL,
    browser VARCHAR(100) NULL,
    operating_system VARCHAR(100) NULL,

    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ip_address INET NULL,
    user_agent TEXT NULL,

    CONSTRAINT fk_cd_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cd_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT uq_cart_device UNIQUE (cart_id, device_id)
);

CREATE INDEX ix_cd_cart ON cart.cart_devices(cart_id);
CREATE INDEX ix_cd_customer ON cart.cart_devices(customer_id);
CREATE INDEX ix_cd_device ON cart.cart_devices(device_id);

-- ============================================================
-- 29.3 CART ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_items (
    cart_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    cart_item_status_id UUID NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity INTEGER NOT NULL DEFAULT 1,

    product_name_snapshot VARCHAR(300) NULL,
    sku_snapshot VARCHAR(100) NULL,

    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    list_price NUMERIC(19,4) NULL,
    sale_price NUMERIC(19,4) NULL,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_subtotal NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,

    price_source VARCHAR(50) NULL,
    price_list_id UUID NULL,
    promotion_id UUID NULL,

    is_price_locked BOOLEAN NOT NULL DEFAULT FALSE,
    price_snapshot_at TIMESTAMPTZ NULL,

    inventory_reserved_quantity INTEGER NOT NULL DEFAULT 0,
    inventory_reservation_expires_at TIMESTAMPTZ NULL,

    is_gift BOOLEAN NOT NULL DEFAULT FALSE,
    gift_message TEXT NULL,

    added_from VARCHAR(50) NULL,
    added_from_entity_id UUID NULL,

    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMPTZ NULL,
    saved_for_later_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ci_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_ci_status FOREIGN KEY (cart_item_status_id) REFERENCES cart.cart_item_status_lookup(cart_item_status_id),
    CONSTRAINT fk_ci_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ci_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_ci_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_ci_quantity CHECK (quantity > 0),
    CONSTRAINT ck_ci_amounts CHECK (
        unit_price >= 0 AND discount_amount >= 0 AND tax_amount >= 0
        AND line_subtotal >= 0 AND line_total >= 0
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cart_item_product_variant
ON cart.cart_items (cart_id, product_id, COALESCE(product_variant_id, '00000000-0000-0000-0000-000000000000'::uuid))
WHERE removed_at IS NULL;

CREATE INDEX ix_ci_cart ON cart.cart_items(cart_id);
CREATE INDEX ix_ci_product ON cart.cart_items(product_id);
CREATE INDEX ix_ci_status ON cart.cart_items(cart_item_status_id);

-- ============================================================
-- 29.4 CART ITEM PRICE SNAPSHOTS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_item_price_snapshots (
    cart_item_price_snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_item_id UUID NOT NULL,
    cart_id UUID NOT NULL,

    snapshot_reason VARCHAR(50) NOT NULL DEFAULT 'ADD_TO_CART',

    unit_price NUMERIC(19,4) NOT NULL,
    list_price NUMERIC(19,4) NULL,
    sale_price NUMERIC(19,4) NULL,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_subtotal NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    currency_id UUID NOT NULL,
    price_list_id UUID NULL,
    promotion_id UUID NULL,

    captured_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cips_item FOREIGN KEY (cart_item_id) REFERENCES cart.cart_items(cart_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_cips_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cips_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_cips_reason CHECK (snapshot_reason IN ('ADD_TO_CART', 'PRICE_REFRESH', 'PROMOTION_APPLIED', 'CHECKOUT_VALIDATION', 'ORDER_CREATION'))
);

CREATE INDEX ix_cips_item ON cart.cart_item_price_snapshots(cart_item_id);
CREATE INDEX ix_cips_cart ON cart.cart_item_price_snapshots(cart_id);
CREATE INDEX ix_cips_captured ON cart.cart_item_price_snapshots(captured_at DESC);

-- ============================================================
-- 29.5 COUPONS / PROMOTIONS APPLIED TO CART
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_coupons (
    cart_coupon_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,

    coupon_code VARCHAR(100) NOT NULL,
    promotion_id UUID NULL,

    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    is_valid BOOLEAN NOT NULL DEFAULT TRUE,
    validation_message TEXT NULL,

    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cc_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cc_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_cart_coupon UNIQUE (cart_id, coupon_code),
    CONSTRAINT ck_cc_discount CHECK (discount_amount >= 0)
);

CREATE INDEX ix_cc_cart ON cart.cart_coupons(cart_id);
CREATE INDEX ix_cc_code ON cart.cart_coupons(coupon_code);

-- ============================================================
-- 29.6 TAX LINES
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_tax_lines (
    cart_tax_line_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    cart_item_id UUID NULL,

    tax_name VARCHAR(150) NOT NULL,
    tax_code VARCHAR(50) NULL,
    jurisdiction VARCHAR(150) NULL,

    taxable_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    tax_rate NUMERIC(9,6) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    is_inclusive BOOLEAN NOT NULL DEFAULT FALSE,

    calculated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ctl_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_ctl_item FOREIGN KEY (cart_item_id) REFERENCES cart.cart_items(cart_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_ctl_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_ctl_amounts CHECK (taxable_amount >= 0 AND tax_rate >= 0 AND tax_amount >= 0)
);

CREATE INDEX ix_ctl_cart ON cart.cart_tax_lines(cart_id);
CREATE INDEX ix_ctl_item ON cart.cart_tax_lines(cart_item_id);

-- ============================================================
-- 29.7 SHIPPING OPTIONS / SPLIT SHIPMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_shipping_options (
    cart_shipping_option_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,

    shipping_method_id UUID NULL,
    carrier_code VARCHAR(100) NULL,
    service_code VARCHAR(100) NULL,
    service_name VARCHAR(200) NOT NULL,

    shipping_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    estimated_delivery_min_days INTEGER NULL,
    estimated_delivery_max_days INTEGER NULL,

    is_selected BOOLEAN NOT NULL DEFAULT FALSE,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    unavailable_reason TEXT NULL,

    rate_quote_id VARCHAR(200) NULL,
    quoted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cso_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cso_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_cso_amount CHECK (shipping_amount >= 0)
);

CREATE INDEX ix_cso_cart ON cart.cart_shipping_options(cart_id);
CREATE INDEX ix_cso_selected ON cart.cart_shipping_options(is_selected);

CREATE TABLE IF NOT EXISTS cart.cart_shipments (
    cart_shipment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,

    shipment_group_number INTEGER NOT NULL DEFAULT 1,
    warehouse_id UUID NULL,
    shipping_method_id UUID NULL,

    shipping_address_id UUID NULL,
    shipping_option_id UUID NULL,

    shipping_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    is_selected BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_csh_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_csh_option FOREIGN KEY (shipping_option_id) REFERENCES cart.cart_shipping_options(cart_shipping_option_id),
    CONSTRAINT fk_csh_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_cart_shipment_group UNIQUE (cart_id, shipment_group_number),
    CONSTRAINT ck_csh_amount CHECK (shipping_amount >= 0)
);

CREATE INDEX ix_csh_cart ON cart.cart_shipments(cart_id);

CREATE TABLE IF NOT EXISTS cart.cart_shipment_items (
    cart_shipment_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_shipment_id UUID NOT NULL,
    cart_item_id UUID NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT fk_cshi_shipment FOREIGN KEY (cart_shipment_id) REFERENCES cart.cart_shipments(cart_shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_cshi_item FOREIGN KEY (cart_item_id) REFERENCES cart.cart_items(cart_item_id) ON DELETE CASCADE,
    CONSTRAINT uq_cart_shipment_item UNIQUE (cart_shipment_id, cart_item_id),
    CONSTRAINT ck_cshi_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_cshi_shipment ON cart.cart_shipment_items(cart_shipment_id);
CREATE INDEX ix_cshi_item ON cart.cart_shipment_items(cart_item_id);

-- ============================================================
-- 29.8 ADDRESSES SELECTED AT CHECKOUT
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_addresses (
    cart_address_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,

    address_type VARCHAR(30) NOT NULL,
    customer_address_id UUID NULL,

    full_name VARCHAR(200) NULL,
    company_name VARCHAR(200) NULL,
    phone VARCHAR(50) NULL,
    email VARCHAR(300) NULL,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(150) NULL,
    state_id UUID NULL,
    country_id UUID NULL,
    postal_code VARCHAR(50) NULL,

    is_validated BOOLEAN NOT NULL DEFAULT FALSE,
    validation_message TEXT NULL,

    selected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ca_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_ca_state FOREIGN KEY (state_id) REFERENCES localization.states(state_id),
    CONSTRAINT fk_ca_country FOREIGN KEY (country_id) REFERENCES localization.countries(country_id),
    CONSTRAINT ck_ca_type CHECK (address_type IN ('BILLING', 'SHIPPING'))
);

CREATE INDEX ix_ca_cart ON cart.cart_addresses(cart_id);
CREATE INDEX ix_ca_type ON cart.cart_addresses(address_type);

-- ============================================================
-- 29.9 PAYMENT SELECTION
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_payment_selections (
    cart_payment_selection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,

    payment_method_id UUID NULL,
    payment_method_code VARCHAR(100) NULL,
    payment_provider_code VARCHAR(100) NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    is_selected BOOLEAN NOT NULL DEFAULT TRUE,
    is_valid BOOLEAN NOT NULL DEFAULT TRUE,
    validation_message TEXT NULL,

    payment_intent_id VARCHAR(300) NULL,
    provider_session_id VARCHAR(300) NULL,

    selected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cps_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cps_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_cps_amount CHECK (amount >= 0)
);

CREATE INDEX ix_cps_cart ON cart.cart_payment_selections(cart_id);
CREATE INDEX ix_cps_selected ON cart.cart_payment_selections(is_selected);

-- ============================================================
-- 29.10 CHECKOUT SESSIONS / STEPS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.checkout_sessions (
    checkout_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,

    session_token VARCHAR(200) NOT NULL UNIQUE,
    current_step_id UUID NULL,

    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,

    ip_address INET NULL,
    user_agent TEXT NULL,

    CONSTRAINT fk_chs_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_chs_step FOREIGN KEY (current_step_id) REFERENCES cart.checkout_step_lookup(checkout_step_id)
);

CREATE INDEX ix_chs_cart ON cart.checkout_sessions(cart_id);
CREATE INDEX ix_chs_token ON cart.checkout_sessions(session_token);

CREATE TABLE IF NOT EXISTS cart.checkout_step_progress (
    checkout_step_progress_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_session_id UUID NOT NULL,
    checkout_step_id UUID NOT NULL,

    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ NULL,

    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_csp_session FOREIGN KEY (checkout_session_id) REFERENCES cart.checkout_sessions(checkout_session_id) ON DELETE CASCADE,
    CONSTRAINT fk_csp_step FOREIGN KEY (checkout_step_id) REFERENCES cart.checkout_step_lookup(checkout_step_id),
    CONSTRAINT uq_checkout_step_progress UNIQUE (checkout_session_id, checkout_step_id)
);

CREATE INDEX ix_csp_session ON cart.checkout_step_progress(checkout_session_id);

-- ============================================================
-- 29.11 CHECKOUT VALIDATION RESULTS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.checkout_validation_results (
    checkout_validation_result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    checkout_session_id UUID NULL,
    checkout_validation_type_id UUID NOT NULL,

    is_passed BOOLEAN NOT NULL DEFAULT FALSE,
    severity VARCHAR(20) NOT NULL DEFAULT 'ERROR',
    message TEXT NULL,
    details JSONB NULL,

    validated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cvr_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cvr_session FOREIGN KEY (checkout_session_id) REFERENCES cart.checkout_sessions(checkout_session_id) ON DELETE CASCADE,
    CONSTRAINT fk_cvr_type FOREIGN KEY (checkout_validation_type_id) REFERENCES cart.checkout_validation_type_lookup(checkout_validation_type_id),
    CONSTRAINT ck_cvr_severity CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'BLOCKER'))
);

CREATE INDEX ix_cvr_cart ON cart.checkout_validation_results(cart_id);
CREATE INDEX ix_cvr_session ON cart.checkout_validation_results(checkout_session_id);
CREATE INDEX ix_cvr_passed ON cart.checkout_validation_results(is_passed);

-- ============================================================
-- 29.12 INVENTORY RESERVATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_inventory_reservations (
    cart_inventory_reservation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    cart_item_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    warehouse_id UUID NULL,

    reserved_quantity INTEGER NOT NULL,
    reservation_token VARCHAR(150) NULL UNIQUE,

    reserved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    released_at TIMESTAMPTZ NULL,
    converted_to_order_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_cir_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cir_item FOREIGN KEY (cart_item_id) REFERENCES cart.cart_items(cart_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_cir_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_cir_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_cir_quantity CHECK (reserved_quantity > 0),
    CONSTRAINT ck_cir_expiry CHECK (expires_at > reserved_at)
);

CREATE INDEX ix_cir_cart ON cart.cart_inventory_reservations(cart_id);
CREATE INDEX ix_cir_item ON cart.cart_inventory_reservations(cart_item_id);
CREATE INDEX ix_cir_product ON cart.cart_inventory_reservations(product_id);
CREATE INDEX ix_cir_active ON cart.cart_inventory_reservations(is_active);
CREATE INDEX ix_cir_expires ON cart.cart_inventory_reservations(expires_at);

-- ============================================================
-- 29.13 ABANDONED CARTS / RECOVERY
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.abandoned_carts (
    abandoned_cart_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL UNIQUE,
    company_id UUID NOT NULL,
    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,

    abandoned_reason VARCHAR(200) NULL,
    abandoned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    cart_value NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    recovery_status_id UUID NULL,
    recovery_attempt_count INTEGER NOT NULL DEFAULT 0,
    last_recovery_attempt_at TIMESTAMPTZ NULL,
    recovered_at TIMESTAMPTZ NULL,
    recovered_order_id UUID NULL,

    expires_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ac_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_ac_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ac_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ac_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_ac_status FOREIGN KEY (recovery_status_id) REFERENCES cart.recovery_status_lookup(recovery_status_id),
    CONSTRAINT fk_ac_order FOREIGN KEY (recovered_order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT ck_ac_value CHECK (cart_value >= 0)
);

CREATE INDEX ix_ac_company ON cart.abandoned_carts(company_id);
CREATE INDEX ix_ac_customer ON cart.abandoned_carts(customer_id);
CREATE INDEX ix_ac_status ON cart.abandoned_carts(recovery_status_id);
CREATE INDEX ix_ac_abandoned ON cart.abandoned_carts(abandoned_at DESC);

CREATE TABLE IF NOT EXISTS cart.abandoned_cart_recovery_messages (
    recovery_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    abandoned_cart_id UUID NOT NULL,

    recovery_status_id UUID NULL,
    notification_id UUID NULL,
    campaign_id UUID NULL,

    channel VARCHAR(30) NOT NULL DEFAULT 'EMAIL',
    subject VARCHAR(300) NULL,
    message_template_code VARCHAR(100) NULL,

    sent_at TIMESTAMPTZ NULL,
    opened_at TIMESTAMPTZ NULL,
    clicked_at TIMESTAMPTZ NULL,
    recovered_at TIMESTAMPTZ NULL,

    recovery_url VARCHAR(1000) NULL,
    coupon_code VARCHAR(100) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_acrm_abandoned FOREIGN KEY (abandoned_cart_id) REFERENCES cart.abandoned_carts(abandoned_cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_acrm_status FOREIGN KEY (recovery_status_id) REFERENCES cart.recovery_status_lookup(recovery_status_id),
    CONSTRAINT ck_acrm_channel CHECK (channel IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP', 'WHATSAPP'))
);

CREATE INDEX ix_acrm_abandoned ON cart.abandoned_cart_recovery_messages(abandoned_cart_id);
CREATE INDEX ix_acrm_status ON cart.abandoned_cart_recovery_messages(recovery_status_id);

-- ============================================================
-- 29.14 ORDER CREATION IDEMPOTENCY / ATTEMPTS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.checkout_order_attempts (
    checkout_order_attempt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    checkout_session_id UUID NULL,

    idempotency_key VARCHAR(200) NOT NULL,
    request_hash VARCHAR(200) NULL,

    attempt_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    order_id UUID NULL,

    error_code VARCHAR(100) NULL,
    error_message TEXT NULL,

    attempted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_coa_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_coa_session FOREIGN KEY (checkout_session_id) REFERENCES cart.checkout_sessions(checkout_session_id),
    CONSTRAINT fk_coa_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT uq_checkout_idempotency UNIQUE (idempotency_key),
    CONSTRAINT ck_coa_status CHECK (attempt_status IN ('PENDING', 'SUCCESS', 'FAILED', 'DUPLICATE'))
);

CREATE INDEX ix_coa_cart ON cart.checkout_order_attempts(cart_id);
CREATE INDEX ix_coa_status ON cart.checkout_order_attempts(attempt_status);

-- ============================================================
-- 29.15 CART EVENTS / ANALYTICS
-- ============================================================

CREATE TABLE IF NOT EXISTS cart.cart_events (
    cart_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NULL,
    company_id UUID NOT NULL,
    cart_event_type_id UUID NOT NULL,

    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,

    product_id UUID NULL,
    cart_item_id UUID NULL,

    event_data JSONB NULL,

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ip_address INET NULL,
    user_agent TEXT NULL,
    device_type VARCHAR(30) NULL,

    CONSTRAINT fk_ce_cart FOREIGN KEY (cart_id) REFERENCES cart.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_ce_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ce_type FOREIGN KEY (cart_event_type_id) REFERENCES cart.cart_event_type_lookup(cart_event_type_id),
    CONSTRAINT fk_ce_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ce_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ce_item FOREIGN KEY (cart_item_id) REFERENCES cart.cart_items(cart_item_id)
);

CREATE INDEX ix_ce_cart ON cart.cart_events(cart_id);
CREATE INDEX ix_ce_company ON cart.cart_events(company_id);
CREATE INDEX ix_ce_type ON cart.cart_events(cart_event_type_id);
CREATE INDEX ix_ce_occurred ON cart.cart_events(occurred_at DESC);

CREATE TABLE IF NOT EXISTS cart.cart_analytics (
    cart_analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    stat_date DATE NOT NULL,

    carts_created INTEGER NOT NULL DEFAULT 0,
    checkout_started INTEGER NOT NULL DEFAULT 0,
    orders_created INTEGER NOT NULL DEFAULT 0,
    carts_abandoned INTEGER NOT NULL DEFAULT 0,
    carts_recovered INTEGER NOT NULL DEFAULT 0,

    items_added INTEGER NOT NULL DEFAULT 0,
    items_removed INTEGER NOT NULL DEFAULT 0,

    gross_cart_value NUMERIC(19,4) NOT NULL DEFAULT 0,
    recovered_cart_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    checkout_conversion_rate NUMERIC(9,4) NULL,
    abandonment_rate NUMERIC(9,4) NULL,
    recovery_rate NUMERIC(9,4) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_can_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_cart_analytics UNIQUE (company_id, stat_date)
);

CREATE INDEX ix_can_company ON cart.cart_analytics(company_id);
CREATE INDEX ix_can_date ON cart.cart_analytics(stat_date DESC);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION cart.calculate_cart_totals(
    p_cart_id UUID
)
RETURNS TABLE (
    subtotal_amount NUMERIC,
    discount_amount NUMERIC,
    tax_amount NUMERIC,
    shipping_amount NUMERIC,
    grand_total_amount NUMERIC
) AS $$
DECLARE
    v_subtotal NUMERIC(19,4);
    v_discount NUMERIC(19,4);
    v_tax NUMERIC(19,4);
    v_shipping NUMERIC(19,4);
    v_total NUMERIC(19,4);
BEGIN
    SELECT
        COALESCE(SUM(ci.line_subtotal), 0),
        COALESCE(SUM(ci.discount_amount), 0),
        COALESCE(SUM(ci.tax_amount), 0)
    INTO v_subtotal, v_discount, v_tax
    FROM cart.cart_items ci
    LEFT JOIN cart.cart_item_status_lookup cis ON cis.cart_item_status_id = ci.cart_item_status_id
    WHERE ci.cart_id = p_cart_id
      AND ci.removed_at IS NULL
      AND COALESCE(cis.code, 'ACTIVE') = 'ACTIVE';

    SELECT COALESCE(SUM(shipping_amount), 0)
    INTO v_shipping
    FROM cart.cart_shipping_options
    WHERE cart_id = p_cart_id
      AND is_selected = TRUE
      AND is_available = TRUE;

    v_total := GREATEST(v_subtotal - v_discount + v_tax + v_shipping, 0);

    UPDATE cart.carts
    SET subtotal_amount = v_subtotal,
        discount_amount = v_discount,
        tax_amount = v_tax,
        shipping_amount = v_shipping,
        grand_total_amount = v_total,
        item_count = (
            SELECT COUNT(*)
            FROM cart.cart_items ci2
            LEFT JOIN cart.cart_item_status_lookup cis2 ON cis2.cart_item_status_id = ci2.cart_item_status_id
            WHERE ci2.cart_id = p_cart_id
              AND ci2.removed_at IS NULL
              AND COALESCE(cis2.code, 'ACTIVE') = 'ACTIVE'
        ),
        quantity_total = (
            SELECT COALESCE(SUM(ci3.quantity), 0)
            FROM cart.cart_items ci3
            LEFT JOIN cart.cart_item_status_lookup cis3 ON cis3.cart_item_status_id = ci3.cart_item_status_id
            WHERE ci3.cart_id = p_cart_id
              AND ci3.removed_at IS NULL
              AND COALESCE(cis3.code, 'ACTIVE') = 'ACTIVE'
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE cart_id = p_cart_id;

    RETURN QUERY SELECT v_subtotal, v_discount, v_tax, v_shipping, v_total;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cart.validate_checkout(
    p_cart_id UUID,
    p_checkout_session_id UUID DEFAULT NULL
)
RETURNS TABLE (
    validation_code VARCHAR,
    is_passed BOOLEAN,
    severity VARCHAR,
    message TEXT
) AS $$
DECLARE
    v_item_count INTEGER;
    v_shipping_count INTEGER;
    v_payment_count INTEGER;
    v_address_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_item_count
    FROM cart.cart_items ci
    LEFT JOIN cart.cart_item_status_lookup cis ON cis.cart_item_status_id = ci.cart_item_status_id
    WHERE ci.cart_id = p_cart_id
      AND ci.removed_at IS NULL
      AND COALESCE(cis.code, 'ACTIVE') = 'ACTIVE';

    SELECT COUNT(*) INTO v_shipping_count
    FROM cart.cart_shipping_options
    WHERE cart_id = p_cart_id AND is_selected = TRUE AND is_available = TRUE;

    SELECT COUNT(*) INTO v_payment_count
    FROM cart.cart_payment_selections
    WHERE cart_id = p_cart_id AND is_selected = TRUE AND is_valid = TRUE;

    SELECT COUNT(*) INTO v_address_count
    FROM cart.cart_addresses
    WHERE cart_id = p_cart_id AND address_type IN ('BILLING', 'SHIPPING');

    RETURN QUERY SELECT 'CART_EXISTS'::VARCHAR, EXISTS(SELECT 1 FROM cart.carts WHERE cart_id = p_cart_id), 'BLOCKER'::VARCHAR, 'Cart must exist.'::TEXT;
    RETURN QUERY SELECT 'ITEM_EXISTS'::VARCHAR, v_item_count > 0, 'BLOCKER'::VARCHAR, 'Cart must contain at least one active item.'::TEXT;
    RETURN QUERY SELECT 'SHIPPING_VALID'::VARCHAR, v_shipping_count > 0, 'ERROR'::VARCHAR, 'A valid shipping option must be selected.'::TEXT;
    RETURN QUERY SELECT 'PAYMENT_METHOD_VALID'::VARCHAR, v_payment_count > 0, 'BLOCKER'::VARCHAR, 'A valid payment method must be selected.'::TEXT;
    RETURN QUERY SELECT 'ADDRESS_REQUIRED'::VARCHAR, v_address_count >= 2, 'BLOCKER'::VARCHAR, 'Billing and shipping addresses are required.'::TEXT;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cart.record_checkout_validation(
    p_cart_id UUID,
    p_checkout_session_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_result RECORD;
    v_type_id UUID;
    v_count INTEGER := 0;
BEGIN
    FOR v_result IN SELECT * FROM cart.validate_checkout(p_cart_id, p_checkout_session_id)
    LOOP
        SELECT checkout_validation_type_id INTO v_type_id
        FROM cart.checkout_validation_type_lookup
        WHERE code = v_result.validation_code;

        IF v_type_id IS NOT NULL THEN
            INSERT INTO cart.checkout_validation_results (
                cart_id,
                checkout_session_id,
                checkout_validation_type_id,
                is_passed,
                severity,
                message
            )
            VALUES (
                p_cart_id,
                p_checkout_session_id,
                v_type_id,
                v_result.is_passed,
                v_result.severity,
                v_result.message
            );

            v_count := v_count + 1;
        END IF;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cart.merge_guest_cart(
    p_guest_cart_id UUID,
    p_customer_cart_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_item RECORD;
BEGIN
    FOR v_item IN
        SELECT *
        FROM cart.cart_items
        WHERE cart_id = p_guest_cart_id
          AND removed_at IS NULL
    LOOP
        INSERT INTO cart.cart_items (
            cart_id,
            cart_item_status_id,
            product_id,
            product_variant_id,
            quantity,
            product_name_snapshot,
            sku_snapshot,
            unit_price,
            list_price,
            sale_price,
            discount_amount,
            tax_amount,
            line_subtotal,
            line_total,
            currency_id,
            price_source,
            price_list_id,
            promotion_id,
            is_price_locked,
            price_snapshot_at,
            added_from,
            added_from_entity_id
        )
        VALUES (
            p_customer_cart_id,
            v_item.cart_item_status_id,
            v_item.product_id,
            v_item.product_variant_id,
            v_item.quantity,
            v_item.product_name_snapshot,
            v_item.sku_snapshot,
            v_item.unit_price,
            v_item.list_price,
            v_item.sale_price,
            v_item.discount_amount,
            v_item.tax_amount,
            v_item.line_subtotal,
            v_item.line_total,
            v_item.currency_id,
            v_item.price_source,
            v_item.price_list_id,
            v_item.promotion_id,
            v_item.is_price_locked,
            v_item.price_snapshot_at,
            'GUEST_CART_MERGE',
            v_item.cart_item_id
        )
        ON CONFLICT (cart_id, product_id, COALESCE(product_variant_id, '00000000-0000-0000-0000-000000000000'::uuid))
        WHERE removed_at IS NULL
        DO UPDATE SET
            quantity = cart.cart_items.quantity + EXCLUDED.quantity,
            updated_at = CURRENT_TIMESTAMP;
    END LOOP;

    UPDATE cart.carts
    SET merged_into_cart_id = p_customer_cart_id,
        merged_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE cart_id = p_guest_cart_id;

    PERFORM cart.calculate_cart_totals(p_customer_cart_id);

    RETURN p_customer_cart_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;