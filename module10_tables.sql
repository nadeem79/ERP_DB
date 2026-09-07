BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 10: SHIPPING / COURIER MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   A shipment moves physical goods from warehouse to customer.
--   Shipping is operational; payment/accounting are financial events.
-- ============================================================
-- Components:
--   10.1  Shipping Providers & Credentials
--   10.2  Shipping Methods
--   10.3  Shipping Zones & Zone Locations
--   10.4  Shipping Rates & Surcharges
--   10.5  Shipments & Shipment Items
--   10.6  Shipment Status History
--   10.7  Shipment Tracking & Tracking Events
--   10.8  Shipment Exceptions
--   10.9  Shipment Insurance
--   10.10 COD Collections
--   10.11 Shipment Documents
--   10.12 Accounting Integration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS shipping;

-- ============================================================
-- 10.1 SHIPPING PROVIDER STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipping_provider_status_lookup (
    shipping_provider_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO shipping.shipping_provider_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Provider is operational.', 10),
    ('INACTIVE', 'Inactive', 'Provider is disabled.', 20),
    ('SUSPENDED', 'Suspended', 'Provider is suspended.', 30),
    ('MAINTENANCE', 'Maintenance', 'Provider under maintenance.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 10.2 SHIPMENT STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_status_lookup (
    shipment_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO shipping.shipment_status_lookup (code, name, description, is_terminal, sort_order) VALUES
    ('PENDING', 'Pending', 'Shipment created, awaiting processing.', FALSE, 10),
    ('PICKING', 'Picking', 'Items being picked from warehouse.', FALSE, 20),
    ('PACKED', 'Packed', 'Items packed and ready.', FALSE, 30),
    ('READY_FOR_PICKUP', 'Ready for Pickup', 'Ready for courier pickup.', FALSE, 40),
    ('PICKED_UP', 'Picked Up', 'Courier has picked up shipment.', FALSE, 50),
    ('IN_TRANSIT', 'In Transit', 'Shipment in transit.', FALSE, 60),
    ('OUT_FOR_DELIVERY', 'Out for Delivery', 'Out for final delivery.', FALSE, 70),
    ('DELIVERED', 'Delivered', 'Shipment delivered.', TRUE, 80),
    ('DELIVERY_FAILED', 'Delivery Failed', 'Delivery attempt failed.', FALSE, 90),
    ('RETURNED', 'Returned', 'Shipment returned to sender.', TRUE, 100),
    ('LOST', 'Lost', 'Shipment lost.', TRUE, 110),
    ('CANCELLED', 'Cancelled', 'Shipment cancelled.', TRUE, 120),
    ('ON_HOLD', 'On Hold', 'Shipment on hold.', FALSE, 130)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 10.3 SHIPMENT TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_type_lookup (
    shipment_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO shipping.shipment_type_lookup (code, name, description, sort_order) VALUES
    ('STANDARD', 'Standard', 'Standard delivery.', 10),
    ('EXPRESS', 'Express', 'Express delivery.', 20),
    ('SAME_DAY', 'Same Day', 'Same day delivery.', 30),
    ('OVERNIGHT', 'Overnight', 'Overnight delivery.', 40),
    ('FREIGHT', 'Freight', 'Freight/LTL delivery.', 50),
    ('INTERNATIONAL', 'International', 'International shipping.', 60),
    ('RETURN', 'Return', 'Return shipment.', 70),
    ('TRANSFER', 'Transfer', 'Inter-warehouse transfer.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 10.4 SHIPPING METHOD LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipping_method_lookup (
    shipping_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO shipping.shipping_method_lookup (code, name, description, sort_order) VALUES
    ('DOOR_DELIVERY', 'Door Delivery', 'Delivery to customer address.', 10),
    ('PICKUP_POINT', 'Pickup Point', 'Delivery to pickup point.', 20),
    ('STORE_PICKUP', 'Store Pickup', 'Customer picks up from store.', 30),
    ('LOCKER', 'Locker Delivery', 'Delivery to locker.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 10.5 SHIPPING PROVIDERS
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipping_providers (
    shipping_provider_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    shipping_provider_status_id UUID NOT NULL DEFAULT (SELECT shipping_provider_status_id FROM shipping.shipping_provider_status_lookup WHERE code = 'ACTIVE'),

    provider_code VARCHAR(50) NOT NULL,
    provider_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    contact_name VARCHAR(200) NULL,
    contact_email VARCHAR(300) NULL,
    contact_phone VARCHAR(50) NULL,
    website VARCHAR(500) NULL,

    api_endpoint VARCHAR(500) NULL,
    api_version VARCHAR(50) NULL,
    supports_tracking BOOLEAN NOT NULL DEFAULT FALSE,
    supports_cod BOOLEAN NOT NULL DEFAULT FALSE,
    supports_insurance BOOLEAN NOT NULL DEFAULT FALSE,
    supports_international BOOLEAN NOT NULL DEFAULT FALSE,

    api_key_encrypted TEXT NULL,
    api_secret_encrypted TEXT NULL,
    account_number VARCHAR(100) NULL,

    pickup_cutoff_time TIME NULL,
    max_weight_kg NUMERIC(19,4) NULL,
    max_dimensions_cm VARCHAR(50) NULL,

    rating NUMERIC(3,2) NULL,
    total_shipments INTEGER NOT NULL DEFAULT 0,
    successful_deliveries INTEGER NOT NULL DEFAULT 0,
    failed_deliveries INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sp_status FOREIGN KEY (shipping_provider_status_id) REFERENCES shipping.shipping_provider_status_lookup(shipping_provider_status_id),
    CONSTRAINT uq_provider_code UNIQUE (company_id, provider_code),
    CONSTRAINT ck_sp_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5))
);

CREATE INDEX ix_sp_company ON shipping.shipping_providers(company_id);
CREATE INDEX ix_sp_status ON shipping.shipping_providers(shipping_provider_status_id);
CREATE INDEX ix_sp_active ON shipping.shipping_providers(is_active);

-- ============================================================
-- 10.6 SHIPPING ZONES
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipping_zones (
    shipping_zone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    zone_code VARCHAR(50) NOT NULL,
    zone_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    zone_type VARCHAR(30) NOT NULL DEFAULT 'DOMESTIC',
    priority INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sz_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_zone_code UNIQUE (company_id, zone_code),
    CONSTRAINT ck_sz_type CHECK (zone_type IN ('DOMESTIC', 'INTERNATIONAL', 'LOCAL', 'REGIONAL'))
);

CREATE INDEX ix_sz_company ON shipping.shipping_zones(company_id);

-- Zone Locations
CREATE TABLE IF NOT EXISTS shipping.shipping_zone_locations (
    shipping_zone_location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipping_zone_id UUID NOT NULL,
    company_id UUID NOT NULL,

    location_type VARCHAR(30) NOT NULL DEFAULT 'COUNTRY',
    country_id UUID NULL,
    state_id UUID NULL,
    city VARCHAR(200) NULL,
    postal_code VARCHAR(20) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_szl_zone FOREIGN KEY (shipping_zone_id) REFERENCES shipping.shipping_zones(shipping_zone_id) ON DELETE CASCADE,
    CONSTRAINT fk_szl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_szl_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT fk_szl_state FOREIGN KEY (state_id) REFERENCES reference.state_lookup(state_id),
    CONSTRAINT ck_szl_type CHECK (location_type IN ('COUNTRY', 'STATE', 'CITY', 'POSTAL_CODE'))
);

CREATE INDEX ix_szl_zone ON shipping.shipping_zone_locations(shipping_zone_id);

-- ============================================================
-- 10.7 SHIPPING RATES
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipping_rates (
    shipping_rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    shipping_provider_id UUID NOT NULL,
    shipping_zone_id UUID NOT NULL,
    shipping_method_id UUID NOT NULL,

    rate_code VARCHAR(50) NOT NULL,
    rate_name VARCHAR(200) NOT NULL,

    rate_type VARCHAR(30) NOT NULL DEFAULT 'FLAT',
    base_rate NUMERIC(19,4) NOT NULL DEFAULT 0,
    per_kg_rate NUMERIC(19,4) NULL,
    per_item_rate NUMERIC(19,4) NULL,
    minimum_charge NUMERIC(19,4) NULL,
    maximum_charge NUMERIC(19,4) NULL,

    free_shipping_threshold NUMERIC(19,4) NULL,
    cod_surcharge NUMERIC(19,4) NULL,
    insurance_rate NUMERIC(5,2) NULL,

    estimated_delivery_days_min INTEGER NULL,
    estimated_delivery_days_max INTEGER NULL,

    currency_id UUID NOT NULL,

    effective_from DATE NULL,
    effective_to DATE NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sr_provider FOREIGN KEY (shipping_provider_id) REFERENCES shipping.shipping_providers(shipping_provider_id),
    CONSTRAINT fk_sr_zone FOREIGN KEY (shipping_zone_id) REFERENCES shipping.shipping_zones(shipping_zone_id),
    CONSTRAINT fk_sr_method FOREIGN KEY (shipping_method_id) REFERENCES shipping.shipping_method_lookup(shipping_method_id),
    CONSTRAINT fk_sr_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_rate_code UNIQUE (company_id, rate_code),
    CONSTRAINT ck_sr_type CHECK (rate_type IN ('FLAT', 'WEIGHT_BASED', 'ITEM_BASED', 'TIERED', 'CALCULATED')),
    CONSTRAINT ck_sr_amounts CHECK (base_rate >= 0 AND (per_kg_rate IS NULL OR per_kg_rate >= 0) AND (per_item_rate IS NULL OR per_item_rate >= 0))
);

CREATE INDEX ix_sr_company ON shipping.shipping_rates(company_id);
CREATE INDEX ix_sr_provider ON shipping.shipping_rates(shipping_provider_id);
CREATE INDEX ix_sr_zone ON shipping.shipping_rates(shipping_zone_id);
CREATE INDEX ix_sr_active ON shipping.shipping_rates(is_active);

-- Shipping Surcharges
CREATE TABLE IF NOT EXISTS shipping.shipping_surcharges (
    shipping_surcharge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    shipping_provider_id UUID NULL,

    surcharge_code VARCHAR(50) NOT NULL,
    surcharge_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    surcharge_type VARCHAR(30) NOT NULL DEFAULT 'FIXED',
    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    percentage NUMERIC(5,2) NULL,

    applies_to_cod BOOLEAN NOT NULL DEFAULT FALSE,
    applies_to_international BOOLEAN NOT NULL DEFAULT FALSE,
    applies_to_oversized BOOLEAN NOT NULL DEFAULT FALSE,
    applies_to_remote BOOLEAN NOT NULL DEFAULT FALSE,

    currency_id UUID NOT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ss_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ss_provider FOREIGN KEY (shipping_provider_id) REFERENCES shipping.shipping_providers(shipping_provider_id),
    CONSTRAINT fk_ss_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_surcharge_code UNIQUE (company_id, surcharge_code),
    CONSTRAINT ck_ss_type CHECK (surcharge_type IN ('FIXED', 'PERCENTAGE', 'PER_KG', 'PER_ITEM')),
    CONSTRAINT ck_ss_amount CHECK (amount >= 0)
);

CREATE INDEX ix_ss_company ON shipping.shipping_surcharges(company_id);

-- ============================================================
-- 10.8 SHIPMENTS (Main Table)
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipments (
    shipment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    order_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    shipping_provider_id UUID NULL,
    shipping_zone_id UUID NULL,
    shipping_method_id UUID NULL,
    shipment_status_id UUID NOT NULL DEFAULT (SELECT shipment_status_id FROM shipping.shipment_status_lookup WHERE code = 'PENDING'),
    shipment_type_id UUID NOT NULL DEFAULT (SELECT shipment_type_id FROM shipping.shipment_type_lookup WHERE code = 'STANDARD'),

    shipment_number VARCHAR(50) NOT NULL,
    shipment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Warehouse info
    warehouse_id UUID NULL,
    warehouse_location_id UUID NULL,

    -- Shipping address (snapshot from order)
    shipping_address_line1 VARCHAR(300) NULL,
    shipping_address_line2 VARCHAR(300) NULL,
    shipping_city VARCHAR(200) NULL,
    shipping_state VARCHAR(200) NULL,
    shipping_postal_code VARCHAR(20) NULL,
    shipping_country_id UUID NULL,

    -- Tracking info
    tracking_number VARCHAR(100) NULL,
    tracking_url VARCHAR(500) NULL,

    -- Package info
    total_weight_kg NUMERIC(19,4) NULL,
    total_volume_cm3 NUMERIC(19,4) NULL,
    package_count INTEGER NOT NULL DEFAULT 1,
    total_items INTEGER NOT NULL DEFAULT 0,

    -- Cost info
    shipping_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    surcharge_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    insurance_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_shipping_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    -- COD info
    is_cod BOOLEAN NOT NULL DEFAULT FALSE,
    cod_amount NUMERIC(19,4) NULL,
    cod_collected BOOLEAN NOT NULL DEFAULT FALSE,
    cod_collected_at TIMESTAMPTZ NULL,

    -- Insurance info
    is_insured BOOLEAN NOT NULL DEFAULT FALSE,
    insured_value NUMERIC(19,4) NULL,

    -- Delivery info
    estimated_delivery_date DATE NULL,
    actual_delivery_date DATE NULL,
    delivered_to VARCHAR(200) NULL,
    delivery_attempts INTEGER NOT NULL DEFAULT 0,
    delivery_notes TEXT NULL,

    -- Signature
    signature_required BOOLEAN NOT NULL DEFAULT FALSE,
    signature_received BOOLEAN NOT NULL DEFAULT FALSE,
    signature_image_url VARCHAR(500) NULL,

    -- Status tracking
    picked_at TIMESTAMPTZ NULL,
    packed_at TIMESTAMPTZ NULL,
    shipped_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,
    cancellation_reason TEXT NULL,

    -- Priority
    is_priority BOOLEAN NOT NULL DEFAULT FALSE,
    is_fragile BOOLEAN NOT NULL DEFAULT FALSE,

    -- Return info
    is_return_shipment BOOLEAN NOT NULL DEFAULT FALSE,
    original_shipment_id UUID NULL,
    return_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sh_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_sh_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_sh_provider FOREIGN KEY (shipping_provider_id) REFERENCES shipping.shipping_providers(shipping_provider_id),
    CONSTRAINT fk_sh_zone FOREIGN KEY (shipping_zone_id) REFERENCES shipping.shipping_zones(shipping_zone_id),
    CONSTRAINT fk_sh_method FOREIGN KEY (shipping_method_id) REFERENCES shipping.shipping_method_lookup(shipping_method_id),
    CONSTRAINT fk_sh_status FOREIGN KEY (shipment_status_id) REFERENCES shipping.shipment_status_lookup(shipment_status_id),
    CONSTRAINT fk_sh_type FOREIGN KEY (shipment_type_id) REFERENCES shipping.shipment_type_lookup(shipment_type_id),
    CONSTRAINT fk_sh_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_sh_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_sh_original FOREIGN KEY (original_shipment_id) REFERENCES shipping.shipments(shipment_id),
    CONSTRAINT uq_shipment_number UNIQUE (company_id, shipment_number),
    CONSTRAINT ck_sh_amounts CHECK (shipping_cost >= 0 AND total_shipping_cost >= 0),
    CONSTRAINT ck_sh_cod CHECK (NOT is_cod OR cod_amount IS NOT NULL),
    CONSTRAINT ck_sh_insurance CHECK (NOT is_insured OR insured_value IS NOT NULL)
);

CREATE INDEX ix_sh_company ON shipping.shipments(company_id);
CREATE INDEX ix_sh_order ON shipping.shipments(order_id);
CREATE INDEX ix_sh_customer ON shipping.shipments(customer_id);
CREATE INDEX ix_sh_provider ON shipping.shipments(shipping_provider_id);
CREATE INDEX ix_sh_status ON shipping.shipments(shipment_status_id);
CREATE INDEX ix_sh_date ON shipping.shipments(shipment_date);
CREATE INDEX ix_sh_tracking ON shipping.shipments(tracking_number);

-- ============================================================
-- 10.9 SHIPMENT ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_items (
    shipment_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    company_id UUID NOT NULL,
    order_item_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    line_total NUMERIC(19,4) NOT NULL DEFAULT 0,

    weight_kg NUMERIC(19,4) NULL,
    volume_cm3 NUMERIC(19,4) NULL,

    currency_id UUID NOT NULL,

    -- Batch/serial tracking
    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,
    expiry_date DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_si_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_si_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_si_order_item FOREIGN KEY (order_item_id) REFERENCES sales.order_items(order_item_id),
    CONSTRAINT fk_si_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_si_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_si_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_si_amounts CHECK (quantity >= 0 AND unit_price >= 0 AND line_total >= 0)
);

CREATE INDEX ix_si_shipment ON shipping.shipment_items(shipment_id);
CREATE INDEX ix_si_product ON shipping.shipment_items(product_id);
CREATE INDEX ix_si_order_item ON shipping.shipment_items(order_item_id);

-- ============================================================
-- 10.10 SHIPMENT STATUS HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_status_history (
    shipment_status_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    from_status_id UUID NULL,
    to_status_id UUID NOT NULL,

    status_notes TEXT NULL,
    location VARCHAR(300) NULL,
    latitude NUMERIC(10,7) NULL,
    longitude NUMERIC(10,7) NULL,

    changed_by_user_id UUID NULL,
    changed_by_provider BOOLEAN NOT NULL DEFAULT FALSE,

    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ssh_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_ssh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ssh_from_status FOREIGN KEY (from_status_id) REFERENCES shipping.shipment_status_lookup(shipment_status_id),
    CONSTRAINT fk_ssh_to_status FOREIGN KEY (to_status_id) REFERENCES shipping.shipment_status_lookup(shipment_status_id)
);

CREATE INDEX ix_ssh_shipment ON shipping.shipment_status_history(shipment_id);
CREATE INDEX ix_ssh_changed_at ON shipping.shipment_status_history(changed_at);

-- ============================================================
-- 10.11 SHIPMENT TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_tracking (
    shipment_tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    tracking_number VARCHAR(100) NOT NULL,
    tracking_url VARCHAR(500) NULL,

    current_status VARCHAR(50) NULL,
    last_tracking_update_at TIMESTAMPTZ NULL,
    last_known_location VARCHAR(300) NULL,

    total_tracking_events INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_st_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_st_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_tracking_number UNIQUE (company_id, tracking_number)
);

CREATE INDEX ix_st_shipment ON shipping.shipment_tracking(shipment_id);
CREATE INDEX ix_st_tracking ON shipping.shipment_tracking(tracking_number);

-- Tracking Events (from courier)
CREATE TABLE IF NOT EXISTS shipping.shipment_tracking_events (
    shipment_tracking_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_tracking_id UUID NOT NULL,
    shipment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    event_code VARCHAR(50) NULL,
    event_description TEXT NULL,
    event_status VARCHAR(50) NULL,

    event_location VARCHAR(300) NULL,
    latitude NUMERIC(10,7) NULL,
    longitude NUMERIC(10,7) NULL,

    event_timestamp TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Idempotency key to prevent duplicate events
    provider_event_id VARCHAR(200) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ste_tracking FOREIGN KEY (shipment_tracking_id) REFERENCES shipping.shipment_tracking(shipment_tracking_id) ON DELETE CASCADE,
    CONSTRAINT fk_ste_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_ste_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_provider_event UNIQUE (shipment_tracking_id, provider_event_id)
);

CREATE INDEX ix_ste_tracking ON shipping.shipment_tracking_events(shipment_tracking_id);
CREATE INDEX ix_ste_shipment ON shipping.shipment_tracking_events(shipment_id);
CREATE INDEX ix_ste_timestamp ON shipping.shipment_tracking_events(event_timestamp);

-- ============================================================
-- 10.12 SHIPMENT EXCEPTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_exceptions (
    shipment_exception_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    exception_type VARCHAR(50) NOT NULL,
    exception_description TEXT NULL,

    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    resolution_notes TEXT NULL,
    resolved_by_user_id UUID NULL,
    resolved_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_se_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_se_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_se_type CHECK (exception_type IN (
        'ADDRESS_ISSUE', 'DAMAGED_IN_TRANSIT', 'LOST_IN_TRANSIT', 'CUSTOMS_HOLD',
        'WEATHER_DELAY', 'DELIVERY_FAILED', 'WRONG_ADDRESS', 'CUSTOMER_UNAVAILABLE',
        'PAYMENT_ISSUE', 'DOCUMENTATION_ISSUE', 'OTHER'
    )),
    CONSTRAINT ck_se_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_se_status CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'CLOSED', 'ESCALATED'))
);

CREATE INDEX ix_se_shipment ON shipping.shipment_exceptions(shipment_id);
CREATE INDEX ix_se_status ON shipping.shipment_exceptions(status);

-- ============================================================
-- 10.13 SHIPMENT INSURANCE
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_insurance (
    shipment_insurance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    insurance_provider VARCHAR(200) NULL,
    policy_number VARCHAR(100) NULL,

    insured_value NUMERIC(19,4) NOT NULL DEFAULT 0,
    premium_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    coverage_type VARCHAR(50) NULL,
    deductible NUMERIC(19,4) NULL,

    is_claim_filed BOOLEAN NOT NULL DEFAULT FALSE,
    claim_amount NUMERIC(19,4) NULL,
    claim_status VARCHAR(30) NULL,
    claim_filed_at TIMESTAMPTZ NULL,
    claim_resolved_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_si_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_si_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_si_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_si_amounts CHECK (insured_value >= 0 AND premium_amount >= 0)
);

CREATE INDEX ix_si_shipment ON shipping.shipment_insurance(shipment_id);

-- ============================================================
-- 10.14 COD COLLECTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.cod_collections (
    cod_collection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    company_id UUID NOT NULL,
    order_id UUID NOT NULL,

    cod_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    collected_amount NUMERIC(19,4) NULL,
    currency_id UUID NOT NULL,

    collection_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    collected_at TIMESTAMPTZ NULL,
    collected_by VARCHAR(200) NULL,

    payment_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cc_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_cc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cc_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_cc_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_cc_payment FOREIGN KEY (payment_id) REFERENCES payments.payments(payment_id),
    CONSTRAINT ck_cc_amounts CHECK (cod_amount >= 0 AND (collected_amount IS NULL OR collected_amount >= 0)),
    CONSTRAINT ck_cc_status CHECK (collection_status IN ('PENDING', 'COLLECTED', 'PARTIALLY_COLLECTED', 'FAILED', 'WAIVED'))
);

CREATE INDEX ix_cc_shipment ON shipping.cod_collections(shipment_id);
CREATE INDEX ix_cc_status ON shipping.cod_collections(collection_status);

-- ============================================================
-- 10.15 SHIPMENT DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_documents (
    shipment_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
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

    CONSTRAINT fk_sd_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_sd_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_sd_type CHECK (document_type IN (
        'INVOICE', 'PACKING_SLIP', 'SHIPPING_LABEL', 'CUSTOMS_DECLARATION',
        'CERTIFICATE_OF_ORIGIN', 'INSURANCE_CERTIFICATE', 'PHOTO', 'OTHER'
    ))
);

CREATE INDEX ix_sd_shipment ON shipping.shipment_documents(shipment_id);

-- ============================================================
-- 10.16 SHIPMENT ACCOUNTING INTEGRATION
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping.shipment_journal_entries (
    shipment_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    shipment_id UUID NULL,
    journal_entry_id UUID NULL,

    posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
    debit_account_id UUID NULL,
    credit_account_id UUID NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sje_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sje_shipment FOREIGN KEY (shipment_id) REFERENCES shipping.shipments(shipment_id),
    CONSTRAINT fk_sje_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_sje_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_sje_shipment ON shipping.shipment_journal_entries(shipment_id);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_currency_id UUID;
    v_zone_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT currency_id INTO v_currency_id FROM reference.currency_lookup WHERE code = 'PKR' LIMIT 1;

    -- Seed shipping providers
    INSERT INTO shipping.shipping_providers (company_id, provider_code, provider_name, description, supports_tracking, supports_cod)
    SELECT v_company_id, 'TCS', 'TCS Express', 'TCS courier service.', TRUE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM shipping.shipping_providers WHERE company_id = v_company_id AND provider_code = 'TCS');

    INSERT INTO shipping.shipping_providers (company_id, provider_code, provider_name, description, supports_tracking, supports_cod)
    SELECT v_company_id, 'LEOPARDS', 'Leopards Courier', 'Leopards courier service.', TRUE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM shipping.shipping_providers WHERE company_id = v_company_id AND provider_code = 'LEOPARDS');

    INSERT INTO shipping.shipping_providers (company_id, provider_code, provider_name, description, supports_tracking, supports_cod)
    SELECT v_company_id, 'POSTPAK', 'PostPak', 'Pakistan Post delivery service.', TRUE, FALSE
    WHERE NOT EXISTS (SELECT 1 FROM shipping.shipping_providers WHERE company_id = v_company_id AND provider_code = 'POSTPAK');

    -- Seed shipping zones
    INSERT INTO shipping.shipping_zones (company_id, zone_code, zone_name, description, zone_type)
    SELECT v_company_id, 'DOMESTIC-PK', 'Pakistan Domestic', 'Domestic shipping within Pakistan.', 'DOMESTIC'
    WHERE NOT EXISTS (SELECT 1 FROM shipping.shipping_zones WHERE company_id = v_company_id AND zone_code = 'DOMESTIC-PK')
    RETURNING shipping_zone_id INTO v_zone_id;

    INSERT INTO shipping.shipping_zones (company_id, zone_code, zone_name, description, zone_type)
    SELECT v_company_id, 'INTERNATIONAL', 'International', 'International shipping.', 'INTERNATIONAL'
    WHERE NOT EXISTS (SELECT 1 FROM shipping.shipping_zones WHERE company_id = v_company_id AND zone_code = 'INTERNATIONAL');

    -- Seed shipping rates
    INSERT INTO shipping.shipping_rates (company_id, shipping_provider_id, shipping_zone_id, shipping_method_id, rate_code, rate_name, rate_type, base_rate, per_kg_rate, currency_id)
    SELECT v_company_id,
           (SELECT shipping_provider_id FROM shipping.shipping_providers WHERE company_id = v_company_id AND provider_code = 'TCS'),
           (SELECT shipping_zone_id FROM shipping.shipping_zones WHERE company_id = v_company_id AND zone_code = 'DOMESTIC-PK'),
           (SELECT shipping_method_id FROM shipping.shipping_method_lookup WHERE code = 'DOOR_DELIVERY'),
           'TCS-STANDARD', 'TCS Standard Delivery', 'WEIGHT_BASED', 250.00, 50.00, v_currency_id
    WHERE NOT EXISTS (SELECT 1 FROM shipping.shipping_rates WHERE company_id = v_company_id AND rate_code = 'TCS-STANDARD');

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 10 Shipping
-- 16 Tables + 4 Lookup Tables + Seed Data
-- ============================================================