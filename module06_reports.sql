BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 06: INVENTORY & WAREHOUSE MANAGEMENT REPORTING
-- 15 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Inventory Summary (Daily, Critical)
-- Stock levels by warehouse/product
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_inventory_summary AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    p.product_code,
    p.product_name,
    pv.sku,
    i.quantity_on_hand,
    i.quantity_reserved,
    i.quantity_damaged,
    i.quantity_in_transit,
    i.quantity_in_quarantine,
    (i.quantity_on_hand - i.quantity_reserved) AS available_quantity,
    i.reorder_level,
    i.reorder_quantity,
    i.average_cost,
    (i.quantity_on_hand * i.average_cost) AS stock_value,
    CASE
        WHEN i.quantity_on_hand <= 0 THEN 'OUT_OF_STOCK'
        WHEN i.quantity_on_hand <= i.reorder_level THEN 'LOW_STOCK'
        ELSE 'IN_STOCK'
    END AS stock_status
FROM inventory.inventories i
JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
JOIN catalog.products p ON p.product_id = i.product_id
JOIN catalog.product_variants pv ON pv.variant_id = i.product_variant_id
WHERE w.is_active = TRUE
ORDER BY w.warehouse_code, p.product_name;

-- ------------------------------------------------------------
-- Report 2: Stock Movement Report (Daily, Critical)
-- All stock movements
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_movement AS
SELECT
    sm.stock_movement_id,
    sm.movement_number,
    sm.movement_date,
    smt.code AS movement_type,
    smt.direction,
    w.warehouse_name,
    p.product_code,
    p.product_name,
    pv.sku,
    sm.quantity,
    sm.unit_cost,
    sm.total_cost,
    sm.batch_number,
    sm.serial_number,
    sm.reference_type,
    sm.reference_number,
    sm.notes,
    u.username AS created_by
FROM inventory.stock_movements sm
JOIN inventory.stock_movement_type_lookup smt ON smt.stock_movement_type_id = sm.stock_movement_type_id
JOIN inventory.warehouses w ON w.warehouse_id = sm.warehouse_id
JOIN catalog.products p ON p.product_id = sm.product_id
JOIN catalog.product_variants pv ON pv.variant_id = sm.product_variant_id
LEFT JOIN identity.users u ON u.user_id = sm.created_by_user_id
WHERE sm.movement_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY sm.movement_date DESC, sm.created_at DESC;

-- ------------------------------------------------------------
-- Report 3: Stock Transfer Report (Daily, Critical)
-- Inter-warehouse transfers
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_transfer AS
SELECT
    st.stock_transfer_id,
    st.transfer_number,
    st.transfer_date,
    tsl.code AS transfer_status,
    fw.warehouse_name AS from_warehouse,
    tw.warehouse_name AS to_warehouse,
    st.total_items,
    st.total_quantity,
    st.total_cost,
    st.shipped_at,
    st.received_at,
    u.username AS created_by
FROM inventory.stock_transfers st
JOIN inventory.transfer_status_lookup tsl ON tsl.transfer_status_id = st.transfer_status_id
JOIN inventory.warehouses fw ON fw.warehouse_id = st.from_warehouse_id
JOIN inventory.warehouses tw ON tw.warehouse_id = st.to_warehouse_id
LEFT JOIN identity.users u ON u.user_id = st.created_by_user_id
WHERE st.transfer_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY st.transfer_date DESC;

-- ------------------------------------------------------------
-- Report 4: Stock Adjustment Report (Weekly, Important)
-- Adjustments with reasons
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_adjustment AS
SELECT
    sa.stock_adjustment_id,
    sa.adjustment_number,
    sa.adjustment_date,
    sa.status,
    w.warehouse_name,
    sarl.code AS reason_code,
    sarl.name AS reason_name,
    sarl.requires_approval,
    sa.notes,
    sa.approved_at,
    COUNT(DISTINCT sai.stock_adjustment_item_id) AS item_count,
    SUM(sai.variance_quantity) AS total_variance_quantity,
    SUM(sai.adjustment_cost) AS total_adjustment_cost
FROM inventory.stock_adjustments sa
JOIN inventory.warehouses w ON w.warehouse_id = sa.warehouse_id
JOIN inventory.stock_adjustment_reason_lookup sarl ON sarl.stock_adjustment_reason_id = sa.stock_adjustment_reason_id
LEFT JOIN inventory.stock_adjustment_items sai ON sai.stock_adjustment_id = sa.stock_adjustment_id
WHERE sa.adjustment_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY sa.stock_adjustment_id, sa.adjustment_number, sa.adjustment_date, sa.status,
         w.warehouse_name, sarl.code, sarl.name, sarl.requires_approval, sa.notes, sa.approved_at
ORDER BY sa.adjustment_date DESC;

-- ------------------------------------------------------------
-- Report 5: Stock Count Report (Weekly, Important)
-- Cycle count results
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_count AS
SELECT
    sc.stock_count_id,
    sc.count_number,
    sc.count_date,
    sc.count_type,
    scsl.code AS count_status,
    w.warehouse_name,
    sc.total_items_counted,
    sc.total_variances,
    sc.total_variance_amount,
    sc.counted_by_user_id,
    sc.approved_at,
    COUNT(DISTINCT sci.stock_count_item_id) AS items_counted,
    SUM(sci.variance_quantity) AS total_variance_qty,
    SUM(sci.variance_amount) AS total_variance_amount
FROM inventory.stock_counts sc
JOIN inventory.stock_count_status_lookup scsl ON scsl.stock_count_status_id = sc.stock_count_status_id
JOIN inventory.warehouses w ON w.warehouse_id = sc.warehouse_id
LEFT JOIN inventory.stock_count_items sci ON sci.stock_count_id = sc.stock_count_id
WHERE sc.count_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY sc.stock_count_id, sc.count_number, sc.count_date, sc.count_type,
         scsl.code, w.warehouse_name, sc.total_items_counted, sc.total_variances,
         sc.total_variance_amount, sc.counted_by_user_id, sc.approved_at
ORDER BY sc.count_date DESC;

-- ------------------------------------------------------------
-- Report 6: Low Stock Alert (Daily, Critical)
-- Items below reorder level
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_low_stock_alert AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    p.product_code,
    p.product_name,
    pv.sku,
    i.quantity_on_hand,
    i.quantity_reserved,
    (i.quantity_on_hand - i.quantity_reserved) AS available_quantity,
    i.reorder_level,
    i.reorder_quantity,
    i.last_received_at,
    rr.preferred_supplier_id,
    s.supplier_name,
    rr.lead_time_days,
    CASE
        WHEN i.quantity_on_hand <= 0 THEN 'OUT_OF_STOCK'
        WHEN i.quantity_on_hand <= i.reorder_level THEN 'REORDER_NEEDED'
        ELSE 'OK'
    END AS alert_status
FROM inventory.inventories i
JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
JOIN catalog.products p ON p.product_id = i.product_id
JOIN catalog.product_variants pv ON pv.variant_id = i.product_variant_id
LEFT JOIN inventory.reorder_rules rr ON rr.product_variant_id = i.product_variant_id AND rr.is_active = TRUE
LEFT JOIN purchasing.suppliers s ON s.supplier_id = rr.preferred_supplier_id
WHERE i.quantity_on_hand <= i.reorder_level
ORDER BY (i.quantity_on_hand - i.reorder_level) ASC;

-- ------------------------------------------------------------
-- Report 7: Stock Valuation Report (Monthly, Critical)
-- Inventory value by method
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_valuation AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    COUNT(DISTINCT i.product_variant_id) AS unique_skus,
    SUM(i.quantity_on_hand) AS total_quantity,
    SUM(i.quantity_on_hand * i.average_cost) AS total_value_avg_cost,
    SUM(i.quantity_on_hand * i.last_cost) AS total_value_last_cost,
    SUM(i.quantity_reserved * i.average_cost) AS reserved_value,
    SUM(i.quantity_damaged * i.average_cost) AS damaged_value
FROM inventory.inventories i
JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
WHERE w.is_active = TRUE
GROUP BY w.warehouse_id, w.warehouse_code, w.warehouse_name
ORDER BY total_value_avg_cost DESC;

-- ------------------------------------------------------------
-- Report 8: Stock Aging Report (Monthly, Important)
-- Inventory age analysis
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_aging AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    p.product_code,
    p.product_name,
    pv.sku,
    sb.batch_number,
    sb.quantity_remaining,
    sb.manufacture_date,
    sb.expiry_date,
    CURRENT_DATE - sb.manufacture_date AS age_days,
    CASE
        WHEN CURRENT_DATE - sb.manufacture_date <= 30 THEN '0-30 Days'
        WHEN CURRENT_DATE - sb.manufacture_date <= 90 THEN '31-90 Days'
        WHEN CURRENT_DATE - sb.manufacture_date <= 180 THEN '91-180 Days'
        WHEN CURRENT_DATE - sb.manufacture_date <= 365 THEN '181-365 Days'
        ELSE '365+ Days'
    END AS age_bucket,
    CASE
        WHEN sb.expiry_date IS NOT NULL AND sb.expiry_date <= CURRENT_DATE THEN 'EXPIRED'
        WHEN sb.expiry_date IS NOT NULL AND sb.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING_SOON'
        ELSE 'OK'
    END AS expiry_status
FROM inventory.stock_batches sb
JOIN inventory.warehouses w ON w.warehouse_id = sb.warehouse_id
JOIN catalog.products p ON p.product_id = sb.product_id
JOIN catalog.product_variants pv ON pv.variant_id = sb.product_variant_id
WHERE sb.is_active = TRUE AND sb.quantity_remaining > 0
ORDER BY sb.manufacture_date ASC;

-- ------------------------------------------------------------
-- Report 9: Stock Turnover Report (Monthly, Important)
-- Turnover rates by product
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_turnover AS
SELECT
    p.product_code,
    p.product_name,
    pv.sku,
    SUM(CASE WHEN smt.direction = 'OUT' THEN ABS(sm.quantity) ELSE 0 END) AS total_issued,
    SUM(CASE WHEN smt.direction = 'IN' THEN sm.quantity ELSE 0 END) AS total_received,
    AVG(i.quantity_on_hand) AS avg_stock_level,
    CASE
        WHEN AVG(i.quantity_on_hand) > 0
        THEN ROUND((SUM(CASE WHEN smt.direction = 'OUT' THEN ABS(sm.quantity) ELSE 0 END) / AVG(i.quantity_on_hand))::NUMERIC, 2)
        ELSE 0
    END AS turnover_rate
FROM inventory.stock_movements sm
JOIN inventory.stock_movement_type_lookup smt ON smt.stock_movement_type_id = sm.stock_movement_type_id
JOIN catalog.products p ON p.product_id = sm.product_id
JOIN catalog.product_variants pv ON pv.variant_id = sm.product_variant_id
LEFT JOIN inventory.inventories i ON i.product_variant_id = sm.product_variant_id AND i.warehouse_id = sm.warehouse_id
WHERE sm.movement_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY p.product_code, p.product_name, pv.sku
ORDER BY turnover_rate DESC;

-- ------------------------------------------------------------
-- Report 10: Warehouse Utilization (Monthly, Important)
-- Space/capacity usage
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_warehouse_utilization AS
SELECT
    w.warehouse_id,
    w.warehouse_code,
    w.warehouse_name,
    w.capacity_volume,
    w.current_volume_used,
    w.capacity_weight,
    w.current_weight_used,
    CASE
        WHEN w.capacity_volume > 0
        THEN ROUND((w.current_volume_used / w.capacity_volume * 100)::NUMERIC, 2)
        ELSE NULL
    END AS volume_utilization_percent,
    CASE
        WHEN w.capacity_weight > 0
        THEN ROUND((w.current_weight_used / w.capacity_weight * 100)::NUMERIC, 2)
        ELSE NULL
    END AS weight_utilization_percent,
    COUNT(DISTINCT wl.warehouse_location_id) AS total_locations,
    COUNT(DISTINCT CASE WHEN wl.is_active = TRUE THEN wl.warehouse_location_id END) AS active_locations,
    COUNT(DISTINCT i.product_variant_id) AS unique_skus,
    SUM(i.quantity_on_hand) AS total_stock_quantity
FROM inventory.warehouses w
LEFT JOIN inventory.warehouse_locations wl ON wl.warehouse_id = w.warehouse_id
LEFT JOIN inventory.inventories i ON i.warehouse_id = w.warehouse_id
WHERE w.is_active = TRUE
GROUP BY w.warehouse_id, w.warehouse_code, w.warehouse_name, w.capacity_volume,
         w.current_volume_used, w.capacity_weight, w.current_weight_used
ORDER BY w.warehouse_code;

-- ------------------------------------------------------------
-- Report 11: Stock by Location (Daily, Critical)
-- Stock by bin/location
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_stock_by_location AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    wl.location_code,
    wl.location_name,
    wl.aisle,
    wl.rack,
    wl.shelf,
    wl.bin,
    p.product_code,
    p.product_name,
    pv.sku,
    i.quantity_on_hand,
    i.quantity_reserved,
    (i.quantity_on_hand - i.quantity_reserved) AS available_quantity
FROM inventory.inventories i
JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
LEFT JOIN inventory.warehouse_locations wl ON wl.warehouse_location_id = i.warehouse_location_id
JOIN catalog.products p ON p.product_id = i.product_id
JOIN catalog.product_variants pv ON pv.variant_id = i.product_variant_id
WHERE i.quantity_on_hand > 0
ORDER BY w.warehouse_code, wl.location_code, p.product_name;

-- ------------------------------------------------------------
-- Report 12: Batch Tracking Report (Daily, Important)
-- Batch/lot tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_batch_tracking AS
SELECT
    sb.stock_batch_id,
    sb.batch_number,
    sb.lot_number,
    w.warehouse_code,
    w.warehouse_name,
    p.product_code,
    p.product_name,
    pv.sku,
    sb.quantity_received,
    sb.quantity_remaining,
    sb.quantity_damaged,
    sb.unit_cost,
    sb.manufacture_date,
    sb.expiry_date,
    sb.is_expired,
    s.supplier_name,
    CASE
        WHEN sb.expiry_date IS NOT NULL AND sb.expiry_date <= CURRENT_DATE THEN 'EXPIRED'
        WHEN sb.expiry_date IS NOT NULL AND sb.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING_SOON'
        ELSE 'OK'
    END AS expiry_status
FROM inventory.stock_batches sb
JOIN inventory.warehouses w ON w.warehouse_id = sb.warehouse_id
JOIN catalog.products p ON p.product_id = sb.product_id
JOIN catalog.product_variants pv ON pv.variant_id = sb.product_variant_id
LEFT JOIN purchasing.suppliers s ON s.supplier_id = sb.supplier_id
WHERE sb.is_active = TRUE AND sb.quantity_remaining > 0
ORDER BY sb.expiry_date ASC NULLS LAST;

-- ------------------------------------------------------------
-- Report 13: Serial Number Tracking (On-demand, Important)
-- Serial number tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_serial_number_tracking AS
SELECT
    ssn.stock_serial_number_id,
    ssn.serial_number,
    ssn.batch_number,
    w.warehouse_code,
    w.warehouse_name,
    p.product_code,
    p.product_name,
    pv.sku,
    ssn.status,
    ssn.received_at,
    ssn.issued_at,
    ssn.returned_at,
    ssn.reference_type,
    ssn.notes
FROM inventory.stock_serial_numbers ssn
JOIN inventory.warehouses w ON w.warehouse_id = ssn.warehouse_id
JOIN catalog.products p ON p.product_id = ssn.product_id
JOIN catalog.product_variants pv ON pv.variant_id = ssn.product_variant_id
ORDER BY ssn.created_at DESC;

-- ------------------------------------------------------------
-- Report 14: Dead Stock Report (Monthly, Important)
-- Non-moving inventory
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_dead_stock AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    p.product_code,
    p.product_name,
    pv.sku,
    i.quantity_on_hand,
    i.average_cost,
    (i.quantity_on_hand * i.average_cost) AS stock_value,
    i.last_issued_at,
    CURRENT_DATE - COALESCE(i.last_issued_at, i.created_at::DATE) AS days_since_last_movement,
    CASE
        WHEN CURRENT_DATE - COALESCE(i.last_issued_at, i.created_at::DATE) <= 30 THEN 'ACTIVE'
        WHEN CURRENT_DATE - COALESCE(i.last_issued_at, i.created_at::DATE) <= 90 THEN 'SLOW_MOVING'
        WHEN CURRENT_DATE - COALESCE(i.last_issued_at, i.created_at::DATE) <= 180 THEN 'DEAD_STOCK'
        ELSE 'OBSOLETE'
    END AS stock_classification
FROM inventory.inventories i
JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
JOIN catalog.products p ON p.product_id = i.product_id
JOIN catalog.product_variants pv ON pv.variant_id = i.product_variant_id
WHERE i.quantity_on_hand > 0
  AND (i.last_issued_at IS NULL OR i.last_issued_at <= CURRENT_TIMESTAMP - INTERVAL '90 days')
ORDER BY days_since_last_movement DESC;

-- ------------------------------------------------------------
-- Report 15: Inventory Health Dashboard (Daily, Critical)
-- Health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_inventory_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT product_variant_id) FROM inventory.inventories WHERE quantity_on_hand > 0) AS total_skus_in_stock,
    (SELECT COUNT(DISTINCT product_variant_id) FROM inventory.inventories WHERE quantity_on_hand <= 0) AS out_of_stock_skus,
    (SELECT COUNT(DISTINCT product_variant_id) FROM inventory.inventories WHERE quantity_on_hand > 0 AND quantity_on_hand <= reorder_level) AS low_stock_skus,
    (SELECT COUNT(DISTINCT product_variant_id) FROM inventory.inventories WHERE quantity_on_hand <= 0) AS out_of_stock_count,
    (SELECT SUM(quantity_on_hand * average_cost) FROM inventory.inventories) AS total_inventory_value,
    (SELECT SUM(quantity_reserved * average_cost) FROM inventory.inventories) AS total_reserved_value,
    (SELECT SUM(quantity_damaged * average_cost) FROM inventory.inventories) AS total_damaged_value,
    (SELECT COUNT(DISTINCT warehouse_id) FROM inventory.warehouses WHERE is_active = TRUE) AS active_warehouses,
    (SELECT COUNT(DISTINCT stock_movement_id) FROM inventory.stock_movements WHERE movement_date >= CURRENT_DATE - INTERVAL '7 days') AS movements_7d,
    (SELECT COUNT(DISTINCT stock_transfer_id) FROM inventory.stock_transfers WHERE transfer_date >= CURRENT_DATE - INTERVAL '7 days') AS transfers_7d,
    (SELECT COUNT(DISTINCT stock_adjustment_id) FROM inventory.stock_adjustments WHERE adjustment_date >= CURRENT_DATE - INTERVAL '7 days') AS adjustments_7d,
    (SELECT COUNT(DISTINCT stock_count_id) FROM inventory.stock_counts WHERE count_date >= CURRENT_DATE - INTERVAL '30 days') AS counts_30d;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Stock Level for Product Variant
CREATE OR REPLACE FUNCTION reports.fn_get_stock_level(
    p_product_variant_id UUID,
    p_warehouse_id UUID DEFAULT NULL
)
RETURNS TABLE (
    warehouse_code VARCHAR,
    warehouse_name VARCHAR,
    quantity_on_hand NUMERIC,
    quantity_reserved NUMERIC,
    available_quantity NUMERIC,
    reorder_level NUMERIC,
    average_cost NUMERIC,
    stock_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        w.warehouse_code::VARCHAR,
        w.warehouse_name::VARCHAR,
        i.quantity_on_hand,
        i.quantity_reserved,
        (i.quantity_on_hand - i.quantity_reserved),
        i.reorder_level,
        i.average_cost,
        (i.quantity_on_hand * i.average_cost)
    FROM inventory.inventories i
    JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
    WHERE i.product_variant_id = p_product_variant_id
      AND (p_warehouse_id IS NULL OR i.warehouse_id = p_warehouse_id)
    ORDER BY w.warehouse_code;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Stock Movements by Period
CREATE OR REPLACE FUNCTION reports.fn_stock_movements(
    p_start_date DATE,
    p_end_date DATE,
    p_warehouse_id UUID DEFAULT NULL,
    p_product_id UUID DEFAULT NULL
)
RETURNS TABLE (
    movement_date DATE,
    movement_type VARCHAR,
    direction VARCHAR,
    warehouse_name VARCHAR,
    product_name VARCHAR,
    quantity NUMERIC,
    total_cost NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sm.movement_date,
        smt.code::VARCHAR,
        smt.direction::VARCHAR,
        w.warehouse_name::VARCHAR,
        p.product_name::VARCHAR,
        sm.quantity,
        sm.total_cost
    FROM inventory.stock_movements sm
    JOIN inventory.stock_movement_type_lookup smt ON smt.stock_movement_type_id = sm.stock_movement_type_id
    JOIN inventory.warehouses w ON w.warehouse_id = sm.warehouse_id
    JOIN catalog.products p ON p.product_id = sm.product_id
    WHERE sm.movement_date BETWEEN p_start_date AND p_end_date
      AND (p_warehouse_id IS NULL OR sm.warehouse_id = p_warehouse_id)
      AND (p_product_id IS NULL OR sm.product_id = p_product_id)
    ORDER BY sm.movement_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Low Stock Items
CREATE OR REPLACE FUNCTION reports.fn_low_stock_items(
    p_warehouse_id UUID DEFAULT NULL
)
RETURNS TABLE (
    warehouse_code VARCHAR,
    product_code VARCHAR,
    product_name VARCHAR,
    sku VARCHAR,
    quantity_on_hand NUMERIC,
    reorder_level NUMERIC,
    reorder_quantity NUMERIC,
    preferred_supplier VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        w.warehouse_code::VARCHAR,
        p.product_code::VARCHAR,
        p.product_name::VARCHAR,
        pv.sku::VARCHAR,
        i.quantity_on_hand,
        i.reorder_level,
        i.reorder_quantity,
        s.supplier_name::VARCHAR
    FROM inventory.inventories i
    JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
    JOIN catalog.products p ON p.product_id = i.product_id
    JOIN catalog.product_variants pv ON pv.variant_id = i.product_variant_id
    LEFT JOIN inventory.reorder_rules rr ON rr.product_variant_id = i.product_variant_id AND rr.is_active = TRUE
    LEFT JOIN purchasing.suppliers s ON s.supplier_id = rr.preferred_supplier_id
    WHERE i.quantity_on_hand <= i.reorder_level
      AND (p_warehouse_id IS NULL OR i.warehouse_id = p_warehouse_id)
    ORDER BY (i.quantity_on_hand - i.reorder_level) ASC;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Inventory Valuation Summary
CREATE OR REPLACE FUNCTION reports.fn_inventory_valuation(
    p_warehouse_id UUID DEFAULT NULL
)
RETURNS TABLE (
    warehouse_code VARCHAR,
    warehouse_name VARCHAR,
    unique_skus BIGINT,
    total_quantity NUMERIC,
    total_value NUMERIC,
    reserved_value NUMERIC,
    damaged_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        w.warehouse_code::VARCHAR,
        w.warehouse_name::VARCHAR,
        COUNT(DISTINCT i.product_variant_id),
        SUM(i.quantity_on_hand),
        SUM(i.quantity_on_hand * i.average_cost),
        SUM(i.quantity_reserved * i.average_cost),
        SUM(i.quantity_damaged * i.average_cost)
    FROM inventory.inventories i
    JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
    WHERE w.is_active = TRUE
      AND (p_warehouse_id IS NULL OR i.warehouse_id = p_warehouse_id)
    GROUP BY w.warehouse_id, w.warehouse_code, w.warehouse_name
    ORDER BY total_value DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Stock Aging Summary
CREATE OR REPLACE FUNCTION reports.fn_stock_aging_summary(
    p_warehouse_id UUID DEFAULT NULL
)
RETURNS TABLE (
    age_bucket VARCHAR,
    batch_count BIGINT,
    total_quantity NUMERIC,
    total_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN CURRENT_DATE - sb.manufacture_date <= 30 THEN '0-30 Days'
            WHEN CURRENT_DATE - sb.manufacture_date <= 90 THEN '31-90 Days'
            WHEN CURRENT_DATE - sb.manufacture_date <= 180 THEN '91-180 Days'
            WHEN CURRENT_DATE - sb.manufacture_date <= 365 THEN '181-365 Days'
            ELSE '365+ Days'
        END::VARCHAR,
        COUNT(DISTINCT sb.stock_batch_id),
        SUM(sb.quantity_remaining),
        SUM(sb.quantity_remaining * sb.unit_cost)
    FROM inventory.stock_batches sb
    WHERE sb.is_active = TRUE
      AND sb.quantity_remaining > 0
      AND sb.manufacture_date IS NOT NULL
      AND (p_warehouse_id IS NULL OR sb.warehouse_id = p_warehouse_id)
    GROUP BY 1
    ORDER BY MIN(sb.manufacture_date);
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 06 Inventory & Warehouse
-- 15 Views + 5 Functions = 20 Report Objects
-- 15 Reports as per reports02.html catalog
-- ============================================================