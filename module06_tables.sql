BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 06: INVENTORY & WAREHOUSE MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   Inventory tracks physical stock; movements record every change.
--   Stock can never be negative. Every change has an audit trail.
--   Cost layers use FIFO for accurate COGS calculation.
-- ============================================================
-- Components:
--   06.1  Warehouses & Locations (enhance existing)
--   06.2  Inventory (stock levels)
--   06.3  Stock Movements
--   06.4  Stock Transfers
--   06.5  Stock Adjustments
--   06.6  Stock Counts / Cycle Counts
--   06.7  Stock Reservations
--   06.8  Batch / Lot Tracking
--   06.9  Serial Number Tracking
--   06.10 Inventory Cost Layers (FIFO)
--   06.11 Inventory Valuation
--   06.12 Reorder Rules
--   06.13 Inventory Accounting Integration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS inventory;

-- ============================================================
-- 06.1 WAREHOUSE STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.warehouse_status_lookup (
    warehouse_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO inventory.warehouse_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Warehouse is operational.', 10),
    ('INACTIVE', 'Inactive', 'Warehouse is disabled.', 20),
    ('MAINTENANCE', 'Maintenance', 'Warehouse under maintenance.', 30),
    ('FULL', 'Full', 'Warehouse at capacity.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 06.2 WAREHOUSE TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.warehouse_type_lookup (
    warehouse_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO inventory.warehouse_type_lookup (code, name, description, sort_order) VALUES
    ('MAIN', 'Main Warehouse', 'Primary warehouse.', 10),
    ('BRANCH', 'Branch Warehouse', 'Branch location warehouse.', 20),
    ('STORE', 'Store Warehouse', 'Retail store backroom.', 30),
    ('TRANSIT', 'Transit', 'In-transit warehouse.', 40),
    ('RETURNS', 'Returns', 'Returns processing warehouse.', 50),
    ('DAMAGED', 'Damaged Goods', 'Damaged goods holding.', 60),
    ('VIRTUAL', 'Virtual', 'Virtual/logical warehouse.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 06.3 STOCK MOVEMENT TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_movement_type_lookup (
    stock_movement_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    direction VARCHAR(10) NOT NULL DEFAULT 'IN',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO inventory.stock_movement_type_lookup (code, name, description, direction, sort_order) VALUES
    ('PURCHASE_RECEIPT', 'Purchase Receipt', 'Goods received from supplier.', 'IN', 10),
    ('SALE_SHIPMENT', 'Sale Shipment', 'Goods shipped to customer.', 'OUT', 20),
    ('RETURN_RECEIPT', 'Return Receipt', 'Customer return received.', 'IN', 30),
    ('PURCHASE_RETURN', 'Purchase Return', 'Goods returned to supplier.', 'OUT', 40),
    ('TRANSFER_IN', 'Transfer In', 'Inter-warehouse transfer in.', 'IN', 50),
    ('TRANSFER_OUT', 'Transfer Out', 'Inter-warehouse transfer out.', 'OUT', 60),
    ('ADJUSTMENT_IN', 'Adjustment In', 'Stock adjustment increase.', 'IN', 70),
    ('ADJUSTMENT_OUT', 'Adjustment Out', 'Stock adjustment decrease.', 'OUT', 80),
    ('STOCK_COUNT_IN', 'Stock Count In', 'Stock count increase.', 'IN', 90),
    ('STOCK_COUNT_OUT', 'Stock Count Out', 'Stock count decrease.', 'OUT', 100),
    ('DAMAGE', 'Damage', 'Damaged goods write-off.', 'OUT', 110),
    ('EXPIRY', 'Expiry', 'Expired goods write-off.', 'OUT', 120),
    ('POS_SALE', 'POS Sale', 'Point of sale sale.', 'OUT', 130),
    ('POS_RETURN', 'POS Return', 'Point of sale return.', 'IN', 140)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, direction = EXCLUDED.direction;

-- ============================================================
-- 06.4 STOCK ADJUSTMENT REASON LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_adjustment_reason_lookup (
    stock_adjustment_reason_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO inventory.stock_adjustment_reason_lookup (code, name, description, requires_approval, sort_order) VALUES
    ('DAMAGE', 'Damage', 'Damaged goods.', TRUE, 10),
    ('EXPIRY', 'Expiry', 'Expired goods.', TRUE, 20),
    ('THEFT', 'Theft/Loss', 'Theft or loss.', TRUE, 30),
    ('COUNT_VARIANCE', 'Count Variance', 'Stock count variance.', TRUE, 40),
    ('DATA_ENTRY_ERROR', 'Data Entry Error', 'Data entry correction.', FALSE, 50),
    ('SAMPLE', 'Sample', 'Sample given away.', TRUE, 60),
    ('SCRAP', 'Scrap', 'Scrapped goods.', TRUE, 70),
    ('OTHER', 'Other', 'Other reason.', TRUE, 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 06.5 STOCK COUNT STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_count_status_lookup (
    stock_count_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO inventory.stock_count_status_lookup (code, name, description, sort_order) VALUES
    ('PLANNED', 'Planned', 'Count planned.', 10),
    ('IN_PROGRESS', 'In Progress', 'Count in progress.', 20),
    ('COMPLETED', 'Completed', 'Count completed.', 30),
    ('APPROVED', 'Approved', 'Count approved.', 40),
    ('CANCELLED', 'Cancelled', 'Count cancelled.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 06.6 TRANSFER STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.transfer_status_lookup (
    transfer_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO inventory.transfer_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Transfer draft.', 10),
    ('APPROVED', 'Approved', 'Transfer approved.', 20),
    ('IN_TRANSIT', 'In Transit', 'Goods in transit.', 30),
    ('RECEIVED', 'Received', 'Goods received.', 40),
    ('CANCELLED', 'Cancelled', 'Transfer cancelled.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 06.7 WAREHOUSES (Enhance existing organization.warehouses)
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.warehouses (
    warehouse_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_status_id UUID NOT NULL DEFAULT (SELECT warehouse_status_id FROM inventory.warehouse_status_lookup WHERE code = 'ACTIVE'),
    warehouse_type_id UUID NOT NULL DEFAULT (SELECT warehouse_type_id FROM inventory.warehouse_type_lookup WHERE code = 'MAIN'),

    warehouse_code VARCHAR(50) NOT NULL,
    warehouse_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state VARCHAR(200) NULL,
    postal_code VARCHAR(20) NULL,
    country_id UUID NULL,

    contact_name VARCHAR(200) NULL,
    contact_phone VARCHAR(50) NULL,
    contact_email VARCHAR(300) NULL,

    capacity_volume NUMERIC(19,4) NULL,
    capacity_weight NUMERIC(19,4) NULL,
    current_volume_used NUMERIC(19,4) NOT NULL DEFAULT 0,
    current_weight_used NUMERIC(19,4) NOT NULL DEFAULT 0,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_receiving BOOLEAN NOT NULL DEFAULT TRUE,
    is_shipping BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_wh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_wh_status FOREIGN KEY (warehouse_status_id) REFERENCES inventory.warehouse_status_lookup(warehouse_status_id),
    CONSTRAINT fk_wh_type FOREIGN KEY (warehouse_type_id) REFERENCES inventory.warehouse_type_lookup(warehouse_type_id),
    CONSTRAINT fk_wh_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT uq_warehouse_code UNIQUE (company_id, warehouse_code)
);

CREATE INDEX ix_wh_company ON inventory.warehouses(company_id);
CREATE INDEX ix_wh_status ON inventory.warehouses(warehouse_status_id);
CREATE INDEX ix_wh_active ON inventory.warehouses(is_active);

-- ============================================================
-- 06.8 WAREHOUSE LOCATIONS / BINS
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.warehouse_locations (
    warehouse_location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id UUID NOT NULL,
    company_id UUID NOT NULL,

    location_code VARCHAR(50) NOT NULL,
    location_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    aisle VARCHAR(20) NULL,
    rack VARCHAR(20) NULL,
    shelf VARCHAR(20) NULL,
    bin VARCHAR(20) NULL,

    location_type VARCHAR(30) NOT NULL DEFAULT 'STORAGE',
    capacity_volume NUMERIC(19,4) NULL,
    capacity_weight NUMERIC(19,4) NULL,

    is_receiving_location BOOLEAN NOT NULL DEFAULT FALSE,
    is_shipping_location BOOLEAN NOT NULL DEFAULT FALSE,
    is_quarantine BOOLEAN NOT NULL DEFAULT FALSE,
    is_damaged BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wl_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id) ON DELETE CASCADE,
    CONSTRAINT fk_wl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_location_code UNIQUE (warehouse_id, location_code),
    CONSTRAINT ck_wl_type CHECK (location_type IN ('STORAGE', 'RECEIVING', 'SHIPPING', 'QUARANTINE', 'DAMAGED', 'STAGING', 'PICKING'))
);

CREATE INDEX ix_wl_warehouse ON inventory.warehouse_locations(warehouse_id);
CREATE INDEX ix_wl_active ON inventory.warehouse_locations(is_active);

-- ============================================================
-- 06.9 INVENTORY (Stock Levels)
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.inventories (
    inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    warehouse_location_id UUID NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,

    quantity_on_hand NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_reserved NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_damaged NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_in_transit NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_in_quarantine NUMERIC(19,4) NOT NULL DEFAULT 0,

    reorder_level NUMERIC(19,4) NOT NULL DEFAULT 0,
    reorder_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    max_stock_level NUMERIC(19,4) NULL,

    average_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    last_cost NUMERIC(19,4) NOT NULL DEFAULT 0,

    last_stock_count_at TIMESTAMPTZ NULL,
    last_received_at TIMESTAMPTZ NULL,
    last_issued_at TIMESTAMPTZ NULL,

    version INTEGER NOT NULL DEFAULT 1,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_inv_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_inv_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_inv_location FOREIGN KEY (warehouse_location_id) REFERENCES inventory.warehouse_locations(warehouse_location_id),
    CONSTRAINT fk_inv_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_inv_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT uq_inventory UNIQUE (warehouse_id, product_variant_id),
    CONSTRAINT ck_inv_quantities CHECK (
        quantity_on_hand >= 0 AND quantity_reserved >= 0 AND quantity_damaged >= 0
        AND quantity_in_transit >= 0 AND quantity_in_quarantine >= 0
    ),
    CONSTRAINT ck_inv_reorder CHECK (reorder_level >= 0 AND reorder_quantity >= 0)
);

CREATE INDEX ix_inv_warehouse ON inventory.inventories(warehouse_id);
CREATE INDEX ix_inv_product ON inventory.inventories(product_id);
CREATE INDEX ix_inv_variant ON inventory.inventories(product_variant_id);
CREATE INDEX ix_inv_reorder ON inventory.inventories(quantity_on_hand, reorder_level);

-- ============================================================
-- 06.10 STOCK MOVEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_movements (
    stock_movement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    warehouse_location_id UUID NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,
    stock_movement_type_id UUID NOT NULL,

    movement_number VARCHAR(50) NOT NULL,
    movement_date DATE NOT NULL DEFAULT CURRENT_DATE,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    unit_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_cost NUMERIC(19,4) NOT NULL DEFAULT 0,

    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,
    expiry_date DATE NULL,

    reference_type VARCHAR(50) NULL,
    reference_id UUID NULL,
    reference_number VARCHAR(100) NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_sm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sm_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_sm_location FOREIGN KEY (warehouse_location_id) REFERENCES inventory.warehouse_locations(warehouse_location_id),
    CONSTRAINT fk_sm_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sm_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_sm_type FOREIGN KEY (stock_movement_type_id) REFERENCES inventory.stock_movement_type_lookup(stock_movement_type_id),
    CONSTRAINT uq_movement_number UNIQUE (company_id, movement_number),
    CONSTRAINT ck_sm_quantity CHECK (quantity <> 0)
);

CREATE INDEX ix_sm_warehouse ON inventory.stock_movements(warehouse_id);
CREATE INDEX ix_sm_product ON inventory.stock_movements(product_id);
CREATE INDEX ix_sm_variant ON inventory.stock_movements(product_variant_id);
CREATE INDEX ix_sm_type ON inventory.stock_movements(stock_movement_type_id);
CREATE INDEX ix_sm_date ON inventory.stock_movements(movement_date);
CREATE INDEX ix_sm_reference ON inventory.stock_movements(reference_type, reference_id);

-- ============================================================
-- 06.11 STOCK TRANSFERS
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_transfers (
    stock_transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    transfer_status_id UUID NOT NULL DEFAULT (SELECT transfer_status_id FROM inventory.transfer_status_lookup WHERE code = 'DRAFT'),

    transfer_number VARCHAR(50) NOT NULL,
    transfer_date DATE NOT NULL DEFAULT CURRENT_DATE,

    from_warehouse_id UUID NOT NULL,
    to_warehouse_id UUID NOT NULL,
    from_location_id UUID NULL,
    to_location_id UUID NULL,

    total_items INTEGER NOT NULL DEFAULT 0,
    total_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_cost NUMERIC(19,4) NOT NULL DEFAULT 0,

    notes TEXT NULL,

    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    shipped_at TIMESTAMPTZ NULL,
    received_at TIMESTAMPTZ NULL,
    received_by_user_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_st_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_st_status FOREIGN KEY (transfer_status_id) REFERENCES inventory.transfer_status_lookup(transfer_status_id),
    CONSTRAINT fk_st_from_wh FOREIGN KEY (from_warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_st_to_wh FOREIGN KEY (to_warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_st_from_loc FOREIGN KEY (from_location_id) REFERENCES inventory.warehouse_locations(warehouse_location_id),
    CONSTRAINT fk_st_to_loc FOREIGN KEY (to_location_id) REFERENCES inventory.warehouse_locations(warehouse_location_id),
    CONSTRAINT uq_transfer_number UNIQUE (company_id, transfer_number),
    CONSTRAINT ck_st_different_warehouses CHECK (from_warehouse_id <> to_warehouse_id),
    CONSTRAINT ck_st_quantities CHECK (total_quantity >= 0 AND total_cost >= 0)
);

CREATE INDEX ix_st_company ON inventory.stock_transfers(company_id);
CREATE INDEX ix_st_status ON inventory.stock_transfers(transfer_status_id);
CREATE INDEX ix_st_from_wh ON inventory.stock_transfers(from_warehouse_id);
CREATE INDEX ix_st_to_wh ON inventory.stock_transfers(to_warehouse_id);

CREATE TABLE IF NOT EXISTS inventory.stock_transfer_items (
    stock_transfer_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_transfer_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    unit_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_cost NUMERIC(19,4) NOT NULL DEFAULT 0,

    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,

    received_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sti_transfer FOREIGN KEY (stock_transfer_id) REFERENCES inventory.stock_transfers(stock_transfer_id) ON DELETE CASCADE,
    CONSTRAINT fk_sti_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sti_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sti_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_sti_quantity CHECK (quantity >= 0 AND received_quantity >= 0)
);

CREATE INDEX ix_sti_transfer ON inventory.stock_transfer_items(stock_transfer_id);

-- ============================================================
-- 06.12 STOCK ADJUSTMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_adjustments (
    stock_adjustment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    stock_adjustment_reason_id UUID NOT NULL,

    adjustment_number VARCHAR(50) NOT NULL,
    adjustment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    notes TEXT NULL,

    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sa_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sa_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_sa_reason FOREIGN KEY (stock_adjustment_reason_id) REFERENCES inventory.stock_adjustment_reason_lookup(stock_adjustment_reason_id),
    CONSTRAINT uq_adjustment_number UNIQUE (company_id, adjustment_number),
    CONSTRAINT ck_sa_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'POSTED'))
);

CREATE INDEX ix_sa_company ON inventory.stock_adjustments(company_id);
CREATE INDEX ix_sa_status ON inventory.stock_adjustments(status);

CREATE TABLE IF NOT EXISTS inventory.stock_adjustment_items (
    stock_adjustment_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_adjustment_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,
    warehouse_location_id UUID NULL,

    current_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    adjusted_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    variance_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    unit_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    adjustment_cost NUMERIC(19,4) NOT NULL DEFAULT 0,

    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,
    expiry_date DATE NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sai_adjustment FOREIGN KEY (stock_adjustment_id) REFERENCES inventory.stock_adjustments(stock_adjustment_id) ON DELETE CASCADE,
    CONSTRAINT fk_sai_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sai_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sai_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_sai_location FOREIGN KEY (warehouse_location_id) REFERENCES inventory.warehouse_locations(warehouse_location_id)
);

CREATE INDEX ix_sai_adjustment ON inventory.stock_adjustment_items(stock_adjustment_id);

-- ============================================================
-- 06.13 STOCK COUNTS / CYCLE COUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_counts (
    stock_count_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    stock_count_status_id UUID NOT NULL DEFAULT (SELECT stock_count_status_id FROM inventory.stock_count_status_lookup WHERE code = 'PLANNED'),

    count_number VARCHAR(50) NOT NULL,
    count_date DATE NOT NULL DEFAULT CURRENT_DATE,
    count_type VARCHAR(30) NOT NULL DEFAULT 'FULL',

    warehouse_location_id UUID NULL,

    total_items_counted INTEGER NOT NULL DEFAULT 0,
    total_variances INTEGER NOT NULL DEFAULT 0,
    total_variance_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    counted_by_user_id UUID NULL,
    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sc_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_sc_status FOREIGN KEY (stock_count_status_id) REFERENCES inventory.stock_count_status_lookup(stock_count_status_id),
    CONSTRAINT fk_sc_location FOREIGN KEY (warehouse_location_id) REFERENCES inventory.warehouse_locations(warehouse_location_id),
    CONSTRAINT uq_count_number UNIQUE (company_id, count_number),
    CONSTRAINT ck_sc_type CHECK (count_type IN ('FULL', 'CYCLE', 'SPOT'))
);

CREATE INDEX ix_sc_company ON inventory.stock_counts(company_id);
CREATE INDEX ix_sc_status ON inventory.stock_counts(stock_count_status_id);

CREATE TABLE IF NOT EXISTS inventory.stock_count_items (
    stock_count_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_count_id UUID NOT NULL,
    company_id UUID NOT NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,
    warehouse_location_id UUID NULL,

    system_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    counted_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    variance_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,

    unit_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    variance_amount NUMERIC(19,4) NOT NULL DEFAULT 0,

    batch_number VARCHAR(100) NULL,
    serial_number VARCHAR(200) NULL,
    expiry_date DATE NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sci_count FOREIGN KEY (stock_count_id) REFERENCES inventory.stock_counts(stock_count_id) ON DELETE CASCADE,
    CONSTRAINT fk_sci_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sci_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sci_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_sci_location FOREIGN KEY (warehouse_location_id) REFERENCES inventory.warehouse_locations(warehouse_location_id)
);

CREATE INDEX ix_sci_count ON inventory.stock_count_items(stock_count_id);

-- ============================================================
-- 06.14 STOCK RESERVATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_reservations (
    stock_reservation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,

    reservation_type VARCHAR(30) NOT NULL DEFAULT 'SALE_ORDER',
    reference_type VARCHAR(50) NULL,
    reference_id UUID NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    reserved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NULL,
    released_at TIMESTAMPTZ NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sr_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_sr_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sr_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_sr_type CHECK (reservation_type IN ('SALE_ORDER', 'PURCHASE_RETURN', 'TRANSFER', 'MANUAL', 'POS')),
    CONSTRAINT ck_sr_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_sr_warehouse ON inventory.stock_reservations(warehouse_id);
CREATE INDEX ix_sr_product ON inventory.stock_reservations(product_id);
CREATE INDEX ix_sr_variant ON inventory.stock_reservations(product_variant_id);
CREATE INDEX ix_sr_reference ON inventory.stock_reservations(reference_type, reference_id);

-- ============================================================
-- 06.15 BATCH / LOT TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_batches (
    stock_batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,

    batch_number VARCHAR(100) NOT NULL,
    lot_number VARCHAR(100) NULL,

    quantity_received NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_remaining NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_damaged NUMERIC(19,4) NOT NULL DEFAULT 0,

    unit_cost NUMERIC(19,4) NOT NULL DEFAULT 0,

    manufacture_date DATE NULL,
    expiry_date DATE NULL,

    supplier_id UUID NULL,
    purchase_order_id UUID NULL,
    goods_receipt_id UUID NULL,

    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sb_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sb_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_sb_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sb_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_sb_supplier FOREIGN KEY (supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT uq_batch UNIQUE (warehouse_id, product_variant_id, batch_number),
    CONSTRAINT ck_sb_quantity CHECK (quantity_received >= 0 AND quantity_remaining >= 0 AND quantity_damaged >= 0)
);

CREATE INDEX ix_sb_warehouse ON inventory.stock_batches(warehouse_id);
CREATE INDEX ix_sb_product ON inventory.stock_batches(product_id);
CREATE INDEX ix_sb_variant ON inventory.stock_batches(product_variant_id);
CREATE INDEX ix_sb_expiry ON inventory.stock_batches(expiry_date);

-- ============================================================
-- 06.16 SERIAL NUMBER TRACKING
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.stock_serial_numbers (
    stock_serial_number_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,

    serial_number VARCHAR(200) NOT NULL,
    batch_number VARCHAR(100) NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'IN_STOCK',

    received_at TIMESTAMPTZ NULL,
    issued_at TIMESTAMPTZ NULL,
    returned_at TIMESTAMPTZ NULL,

    reference_type VARCHAR(50) NULL,
    reference_id UUID NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ssn_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ssn_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_ssn_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_ssn_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT uq_serial UNIQUE (product_variant_id, serial_number),
    CONSTRAINT ck_ssn_status CHECK (status IN ('IN_STOCK', 'RESERVED', 'SHIPPED', 'RETURNED', 'DAMAGED', 'SCRAPPED'))
);

CREATE INDEX ix_ssn_warehouse ON inventory.stock_serial_numbers(warehouse_id);
CREATE INDEX ix_ssn_product ON inventory.stock_serial_numbers(product_id);
CREATE INDEX ix_ssn_variant ON inventory.stock_serial_numbers(product_variant_id);
CREATE INDEX ix_ssn_serial ON inventory.stock_serial_numbers(serial_number);

-- ============================================================
-- 06.17 INVENTORY COST LAYERS (FIFO)
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.inventory_cost_layers (
    inventory_cost_layer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NOT NULL,

    quantity_received NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_remaining NUMERIC(19,4) NOT NULL DEFAULT 0,
    unit_cost NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_cost NUMERIC(19,4) NOT NULL DEFAULT 0,

    source_type VARCHAR(50) NULL,
    source_id UUID NULL,

    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    depleted_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_icl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_icl_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_icl_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_icl_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_icl_quantity CHECK (quantity_received >= 0 AND quantity_remaining >= 0),
    CONSTRAINT ck_icl_cost CHECK (unit_cost >= 0 AND total_cost >= 0)
);

CREATE INDEX ix_icl_warehouse ON inventory.inventory_cost_layers(warehouse_id);
CREATE INDEX ix_icl_product ON inventory.inventory_cost_layers(product_id);
CREATE INDEX ix_icl_variant ON inventory.inventory_cost_layers(product_variant_id);
CREATE INDEX ix_icl_remaining ON inventory.inventory_cost_layers(quantity_remaining);

-- ============================================================
-- 06.18 REORDER RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.reorder_rules (
    reorder_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_id UUID NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    reorder_level NUMERIC(19,4) NOT NULL DEFAULT 0,
    reorder_quantity NUMERIC(19,4) NOT NULL DEFAULT 0,
    max_stock_level NUMERIC(19,4) NULL,
    safety_stock NUMERIC(19,4) NOT NULL DEFAULT 0,

    preferred_supplier_id UUID NULL,
    lead_time_days INTEGER NULL,

    is_auto_reorder BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rr_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT fk_rr_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rr_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_rr_supplier FOREIGN KEY (preferred_supplier_id) REFERENCES purchasing.suppliers(supplier_id),
    CONSTRAINT ck_rr_levels CHECK (reorder_level >= 0 AND reorder_quantity >= 0 AND safety_stock >= 0)
);

CREATE INDEX ix_rr_product ON inventory.reorder_rules(product_id);
CREATE INDEX ix_rr_variant ON inventory.reorder_rules(product_variant_id);

-- ============================================================
-- 06.19 INVENTORY JOURNAL ENTRIES (Accounting Integration)
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.inventory_journal_entries (
    inventory_journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    stock_movement_id UUID NULL,
    stock_adjustment_id UUID NULL,
    stock_transfer_id UUID NULL,
    journal_entry_id UUID NULL,

    posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
    debit_account_id UUID NULL,
    credit_account_id UUID NULL,

    amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NOT NULL,

    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ije_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ije_movement FOREIGN KEY (stock_movement_id) REFERENCES inventory.stock_movements(stock_movement_id),
    CONSTRAINT fk_ije_adjustment FOREIGN KEY (stock_adjustment_id) REFERENCES inventory.stock_adjustments(stock_adjustment_id),
    CONSTRAINT fk_ije_transfer FOREIGN KEY (stock_transfer_id) REFERENCES inventory.stock_transfers(stock_transfer_id),
    CONSTRAINT fk_ije_journal FOREIGN KEY (journal_entry_id) REFERENCES accounting.journal_entries(journal_entry_id),
    CONSTRAINT fk_ije_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_ije_movement ON inventory.inventory_journal_entries(stock_movement_id);
CREATE INDEX ix_ije_adjustment ON inventory.inventory_journal_entries(stock_adjustment_id);

-- ============================================================
-- 06.20 INVENTORY STATUS HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory.inventory_status_history (
    inventory_status_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    inventory_id UUID NULL,
    stock_movement_id UUID NULL,

    product_variant_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,

    quantity_before NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_change NUMERIC(19,4) NOT NULL DEFAULT 0,
    quantity_after NUMERIC(19,4) NOT NULL DEFAULT 0,

    movement_type VARCHAR(50) NULL,
    reference_type VARCHAR(50) NULL,
    reference_id UUID NULL,

    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by_user_id UUID NULL,

    CONSTRAINT fk_ish_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ish_inventory FOREIGN KEY (inventory_id) REFERENCES inventory.inventories(inventory_id),
    CONSTRAINT fk_ish_movement FOREIGN KEY (stock_movement_id) REFERENCES inventory.stock_movements(stock_movement_id),
    CONSTRAINT fk_ish_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_ish_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id)
);

CREATE INDEX ix_ish_inventory ON inventory.inventory_status_history(inventory_id);
CREATE INDEX ix_ish_variant ON inventory.inventory_status_history(product_variant_id);
CREATE INDEX ix_ish_changed ON inventory.inventory_status_history(changed_at);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_wh_main UUID;
    v_wh_returns UUID;
    v_wh_damaged UUID;
    v_loc_receiving UUID;
    v_loc_shipping UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Seed warehouses
    INSERT INTO inventory.warehouses (company_id, warehouse_code, warehouse_name, warehouse_type_id, is_default, is_receiving, is_shipping)
    SELECT v_company_id, 'WH-MAIN', 'Main Warehouse',
           (SELECT warehouse_type_id FROM inventory.warehouse_type_lookup WHERE code = 'MAIN'),
           TRUE, TRUE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM inventory.warehouses WHERE company_id = v_company_id AND warehouse_code = 'WH-MAIN')
    RETURNING warehouse_id INTO v_wh_main;

    INSERT INTO inventory.warehouses (company_id, warehouse_code, warehouse_name, warehouse_type_id, is_receiving, is_shipping)
    SELECT v_company_id, 'WH-RETURNS', 'Returns Warehouse',
           (SELECT warehouse_type_id FROM inventory.warehouse_type_lookup WHERE code = 'RETURNS'),
           TRUE, FALSE
    WHERE NOT EXISTS (SELECT 1 FROM inventory.warehouses WHERE company_id = v_company_id AND warehouse_code = 'WH-RETURNS')
    RETURNING warehouse_id INTO v_wh_returns;

    INSERT INTO inventory.warehouses (company_id, warehouse_code, warehouse_name, warehouse_type_id, is_receiving, is_shipping)
    SELECT v_company_id, 'WH-DAMAGED', 'Damaged Goods',
           (SELECT warehouse_type_id FROM inventory.warehouse_type_lookup WHERE code = 'DAMAGED'),
           FALSE, FALSE
    WHERE NOT EXISTS (SELECT 1 FROM inventory.warehouses WHERE company_id = v_company_id AND warehouse_code = 'WH-DAMAGED')
    RETURNING warehouse_id INTO v_wh_damaged;

    IF v_wh_main IS NULL THEN
        SELECT warehouse_id INTO v_wh_main FROM inventory.warehouses WHERE company_id = v_company_id AND warehouse_code = 'WH-MAIN';
    END IF;

    -- Seed warehouse locations
    INSERT INTO inventory.warehouse_locations (warehouse_id, company_id, location_code, location_name, location_type, is_receiving_location)
    SELECT v_wh_main, v_company_id, 'RECEIVING', 'Receiving Area', 'RECEIVING', TRUE
    WHERE v_wh_main IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.warehouse_locations WHERE warehouse_id = v_wh_main AND location_code = 'RECEIVING')
    RETURNING warehouse_location_id INTO v_loc_receiving;

    INSERT INTO inventory.warehouse_locations (warehouse_id, company_id, location_code, location_name, location_type, is_shipping_location)
    SELECT v_wh_main, v_company_id, 'SHIPPING', 'Shipping Area', 'SHIPPING', TRUE
    WHERE v_wh_main IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.warehouse_locations WHERE warehouse_id = v_wh_main AND location_code = 'SHIPPING')
    RETURNING warehouse_location_id INTO v_loc_shipping;

    INSERT INTO inventory.warehouse_locations (warehouse_id, company_id, location_code, location_name, location_type)
    SELECT v_wh_main, v_company_id, 'A1-R1-S1', 'Aisle 1 - Rack 1 - Shelf 1', 'STORAGE'
    WHERE v_wh_main IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.warehouse_locations WHERE warehouse_id = v_wh_main AND location_code = 'A1-R1-S1');

    INSERT INTO inventory.warehouse_locations (warehouse_id, company_id, location_code, location_name, location_type)
    SELECT v_wh_main, v_company_id, 'A1-R1-S2', 'Aisle 1 - Rack 1 - Shelf 2', 'STORAGE'
    WHERE v_wh_main IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.warehouse_locations WHERE warehouse_id = v_wh_main AND location_code = 'A1-R1-S2');

    INSERT INTO inventory.warehouse_locations (warehouse_id, company_id, location_code, location_name, location_type, is_quarantine)
    SELECT v_wh_main, v_company_id, 'QUARANTINE', 'Quarantine Area', 'QUARANTINE', TRUE
    WHERE v_wh_main IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.warehouse_locations WHERE warehouse_id = v_wh_main AND location_code = 'QUARANTINE');

    INSERT INTO inventory.warehouse_locations (warehouse_id, company_id, location_code, location_name, location_type, is_damaged)
    SELECT v_wh_damaged, v_company_id, 'DAMAGED-AREA', 'Damaged Goods Area', 'DAMAGED', TRUE
    WHERE v_wh_damaged IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.warehouse_locations WHERE warehouse_id = v_wh_damaged AND location_code = 'DAMAGED-AREA');

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 06 Inventory & Warehouse
-- 20 Tables + 6 Lookup Tables + Seed Data
-- ============================================================