BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 04: PRODUCT CATALOG REPORTING
-- 15 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Product Master List (Daily, Critical)
-- Complete product inventory with variants, categories
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_master_list AS
SELECT
    p.product_id,
    p.product_code,
    p.product_name,
    p.slug,
    psl.code AS product_status,
    pt.type_name AS product_type,
    b.brand_name,
    p.is_featured,
    p.is_visible,
    p.is_active,
    p.published_at,
    p.created_at,
    COUNT(DISTINCT pv.variant_id) AS variant_count,
    COUNT(DISTINCT pc.category_id) AS category_count,
    COUNT(DISTINCT pm.product_media_id) AS media_count
FROM catalog.products p
JOIN catalog.product_status_lookup psl ON psl.product_status_id = p.product_status_id
JOIN catalog.product_types pt ON pt.product_type_id = p.product_type_id
LEFT JOIN catalog.brands b ON b.brand_id = p.brand_id
LEFT JOIN catalog.product_variants pv ON pv.product_id = p.product_id AND pv.is_active = TRUE
LEFT JOIN catalog.product_categories pc ON pc.product_id = p.product_id
LEFT JOIN catalog.product_media pm ON pm.product_id = p.product_id AND pm.is_active = TRUE
WHERE p.company_id = (SELECT company_id FROM organization.companies LIMIT 1)
GROUP BY p.product_id, p.product_code, p.product_name, p.slug, psl.code, pt.type_name,
         b.brand_name, p.is_featured, p.is_visible, p.is_active, p.published_at, p.created_at
ORDER BY p.created_at DESC;

-- ------------------------------------------------------------
-- Report 2: Variant Report (Weekly, Critical)
-- All variants with SKUs, barcodes, attributes
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_variant_report AS
SELECT
    pv.variant_id,
    p.product_code,
    p.product_name,
    pv.sku,
    pv.barcode,
    pv.gtin,
    pv.upc,
    pv.ean,
    pv.isbn,
    pv.weight,
    pv.cost_price,
    pv.list_price,
    pv.is_active,
    COUNT(DISTINCT pi.product_identifier_id) AS identifier_count,
    COUNT(DISTINCT pav.product_attribute_value_id) AS attribute_count
FROM catalog.product_variants pv
JOIN catalog.products p ON p.product_id = pv.product_id
LEFT JOIN catalog.product_identifiers pi ON pi.product_variant_id = pv.variant_id AND pi.is_active = TRUE
LEFT JOIN catalog.product_attribute_values pav ON pav.product_variant_id = pv.variant_id
GROUP BY pv.variant_id, p.product_code, p.product_name, pv.sku, pv.barcode, pv.gtin,
         pv.upc, pv.ean, pv.isbn, pv.weight, pv.cost_price, pv.list_price, pv.is_active
ORDER BY p.product_name, pv.sku;

-- ------------------------------------------------------------
-- Report 3: Category Hierarchy (Monthly, Important)
-- Tree view with product counts
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_category_hierarchy AS
SELECT
    c.category_id,
    c.category_code,
    c.category_name,
    c.slug,
    pc.category_name AS parent_category_name,
    c.is_featured,
    c.is_visible,
    c.is_active,
    c.sort_order,
    COUNT(DISTINCT pc2.product_id) AS product_count,
    COUNT(DISTINCT child.category_id) AS child_category_count
FROM catalog.categories c
LEFT JOIN catalog.categories pc ON pc.category_id = c.parent_category_id
LEFT JOIN catalog.product_categories pc2 ON pc2.category_id = c.category_id
LEFT JOIN catalog.categories child ON child.parent_category_id = c.category_id AND child.is_active = TRUE
WHERE c.company_id = (SELECT company_id FROM organization.companies LIMIT 1)
GROUP BY c.category_id, c.category_code, c.category_name, c.slug, pc.category_name,
         c.is_featured, c.is_visible, c.is_active, c.sort_order
ORDER BY c.sort_order, c.category_name;

-- ------------------------------------------------------------
-- Report 4: Brand Performance (Monthly, Important)
-- Sales and inventory by brand
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_brand_performance AS
SELECT
    b.brand_id,
    b.brand_code,
    b.brand_name,
    b.is_active,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT pv.variant_id) AS variant_count,
    SUM(i.quantity_on_hand) AS total_stock,
    SUM(i.quantity_on_hand * pv.list_price) AS total_inventory_value
FROM catalog.brands b
LEFT JOIN catalog.products p ON p.brand_id = b.brand_id AND p.is_active = TRUE
LEFT JOIN catalog.product_variants pv ON pv.product_id = p.product_id AND pv.is_active = TRUE
LEFT JOIN inventory.inventories i ON i.product_variant_id = pv.variant_id
WHERE b.company_id = (SELECT company_id FROM organization.companies LIMIT 1)
GROUP BY b.brand_id, b.brand_code, b.brand_name, b.is_active
ORDER BY total_inventory_value DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 5: Product Lifecycle (Weekly, Important)
-- Products by lifecycle status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_lifecycle AS
SELECT
    psl.code AS product_status,
    psl.name AS status_name,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT pv.variant_id) AS variant_count,
    COUNT(DISTINCT CASE WHEN p.is_featured = TRUE THEN p.product_id END) AS featured_count,
    COUNT(DISTINCT CASE WHEN p.is_visible = TRUE THEN p.product_id END) AS visible_count
FROM catalog.product_status_lookup psl
LEFT JOIN catalog.products p ON p.product_status_id = psl.product_status_id
LEFT JOIN catalog.product_variants pv ON pv.product_id = p.product_id AND pv.is_active = TRUE
GROUP BY psl.product_status_id, psl.code, psl.name, psl.sort_order
ORDER BY psl.sort_order;

-- ------------------------------------------------------------
-- Report 6: Product Availability (Daily, Critical)
-- Stock availability across channels
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_availability AS
SELECT
    p.product_code,
    p.product_name,
    pv.sku,
    w.warehouse_name,
    i.quantity_on_hand,
    i.quantity_reserved,
    i.quantity_damaged,
    (i.quantity_on_hand - i.quantity_reserved) AS available_quantity,
    i.reorder_level,
    i.reorder_quantity,
    CASE
        WHEN i.quantity_on_hand <= 0 THEN 'OUT_OF_STOCK'
        WHEN i.quantity_on_hand <= i.reorder_level THEN 'LOW_STOCK'
        ELSE 'IN_STOCK'
    END AS stock_status
FROM catalog.products p
JOIN catalog.product_variants pv ON pv.product_id = p.product_id AND pv.is_active = TRUE
LEFT JOIN inventory.inventories i ON i.product_variant_id = pv.variant_id
LEFT JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
WHERE p.is_active = TRUE
ORDER BY p.product_name, pv.sku, w.warehouse_name;

-- ------------------------------------------------------------
-- Report 7: Product Media (Weekly, Important)
-- Products with/without images
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_media AS
SELECT
    p.product_code,
    p.product_name,
    COUNT(DISTINCT pm.product_media_id) AS media_count,
    COUNT(DISTINCT CASE WHEN pm.media_type = 'IMAGE' THEN pm.product_media_id END) AS image_count,
    COUNT(DISTINCT CASE WHEN pm.media_type = 'VIDEO' THEN pm.product_media_id END) AS video_count,
    COUNT(DISTINCT CASE WHEN pm.is_primary = TRUE THEN pm.product_media_id END) AS primary_media_count,
    CASE
        WHEN COUNT(DISTINCT pm.product_media_id) = 0 THEN 'NO_MEDIA'
        WHEN COUNT(DISTINCT CASE WHEN pm.is_primary = TRUE THEN pm.product_media_id END) = 0 THEN 'NO_PRIMARY'
        ELSE 'HAS_MEDIA'
    END AS media_status
FROM catalog.products p
LEFT JOIN catalog.product_media pm ON pm.product_id = p.product_id AND pm.is_active = TRUE
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY media_count ASC;

-- ------------------------------------------------------------
-- Report 8: Product Relationships (Monthly, Important)
-- Related/cross-sell/up-sell products
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_relationships AS
SELECT
    p.product_code,
    p.product_name,
    prt.code AS relationship_type,
    prt.name AS relationship_type_name,
    COUNT(DISTINCT pr.related_product_id) AS related_product_count,
    COUNT(DISTINCT CASE WHEN pr.is_active = TRUE THEN pr.product_relationship_id END) AS active_relationships
FROM catalog.products p
LEFT JOIN catalog.product_relationships pr ON pr.product_id = p.product_id
LEFT JOIN catalog.product_relationship_type_lookup prt ON prt.product_relationship_type_id = pr.product_relationship_type_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_code, p.product_name, prt.code, prt.name
ORDER BY related_product_count DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 9: Bundle Analysis (Monthly, Important)
-- Bundle/kit product analysis
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_bundle_analysis AS
SELECT
    p.product_code AS bundle_code,
    p.product_name AS bundle_name,
    COUNT(DISTINCT pb.component_product_id) AS component_count,
    SUM(pb.quantity) AS total_component_quantity,
    COUNT(DISTINCT CASE WHEN pb.is_optional = TRUE THEN pb.product_bundle_id END) AS optional_components,
    STRING_AGG(cp.product_name, ', ') AS component_names
FROM catalog.products p
JOIN catalog.product_types pt ON pt.product_type_id = p.product_type_id AND pt.is_bundle = TRUE
LEFT JOIN catalog.product_bundles pb ON pb.bundle_product_id = p.product_id
LEFT JOIN catalog.products cp ON cp.product_id = pb.component_product_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY component_count DESC;

-- ------------------------------------------------------------
-- Report 10: Product Specifications (Monthly, Important)
-- Products with specifications
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_specifications AS
SELECT
    p.product_code,
    p.product_name,
    ps.spec_group,
    COUNT(DISTINCT ps.product_specification_id) AS spec_count,
    COUNT(DISTINCT CASE WHEN ps.is_visible = TRUE THEN ps.product_specification_id END) AS visible_specs
FROM catalog.products p
LEFT JOIN catalog.product_specifications ps ON ps.product_id = p.product_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_code, p.product_name, ps.spec_group
ORDER BY spec_count DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 11: Product Documents (Monthly, Important)
-- Product documents and certificates
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_documents AS
SELECT
    p.product_code,
    p.product_name,
    pd.title AS document_title,
    pd.file_name,
    pd.mime_type,
    pd.file_size_bytes,
    pd.document_version,
    pd.is_active,
    pd.created_at
FROM catalog.products p
LEFT JOIN catalog.product_documents pd ON pd.product_id = p.product_id AND pd.is_active = TRUE
WHERE p.is_active = TRUE
ORDER BY p.product_name, pd.created_at DESC;

-- ------------------------------------------------------------
-- Report 12: Product Versioning (Monthly, Important)
-- Product version history
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_versioning AS
SELECT
    p.product_code,
    p.product_name,
    pv.version_number,
    pv.change_description,
    u.username AS changed_by,
    pv.changed_at,
    pv.is_current
FROM catalog.product_versions pv
JOIN catalog.products p ON p.product_id = pv.product_id
LEFT JOIN identity.users u ON u.user_id = pv.changed_by_user_id
ORDER BY p.product_name, pv.version_number DESC;

-- ------------------------------------------------------------
-- Report 13: Catalog Audit (Weekly, Important)
-- Catalog change tracking
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_catalog_audit AS
SELECT
    cal.catalog_audit_id,
    cal.action,
    cal.entity_type,
    cal.field_name,
    cal.old_value,
    cal.new_value,
    p.product_code,
    p.product_name,
    u.username AS changed_by,
    cal.changed_at
FROM catalog.catalog_audit_log cal
LEFT JOIN catalog.products p ON p.product_id = cal.product_id
LEFT JOIN identity.users u ON u.user_id = cal.changed_by_user_id
WHERE cal.changed_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY cal.changed_at DESC;

-- ------------------------------------------------------------
-- Report 14: Product Search Performance (Daily, Important)
-- Product search performance
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_product_search AS
SELECT
    p.product_code,
    p.product_name,
    p.slug,
    p.is_visible,
    p.is_active,
    COUNT(DISTINCT pv.variant_id) AS variant_count,
    COUNT(DISTINCT pc.category_id) AS category_count,
    COUNT(DISTINCT ptag.product_tag_id) AS tag_count
FROM catalog.products p
LEFT JOIN catalog.product_variants pv ON pv.product_id = p.product_id AND pv.is_active = TRUE
LEFT JOIN catalog.product_categories pc ON pc.product_id = p.product_id
LEFT JOIN catalog.product_tag_assignments ptag ON ptag.product_id = p.product_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_code, p.product_name, p.slug, p.is_visible, p.is_active
ORDER BY p.product_name;

-- ------------------------------------------------------------
-- Report 15: Catalog Health Dashboard (Daily, Critical)
-- Catalog health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_catalog_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT product_id) FROM catalog.products WHERE is_active = TRUE) AS active_products,
    (SELECT COUNT(DISTINCT variant_id) FROM catalog.product_variants WHERE is_active = TRUE) AS active_variants,
    (SELECT COUNT(DISTINCT category_id) FROM catalog.categories WHERE is_active = TRUE) AS active_categories,
    (SELECT COUNT(DISTINCT brand_id) FROM catalog.brands WHERE is_active = TRUE) AS active_brands,
    (SELECT COUNT(DISTINCT product_id) FROM catalog.products WHERE product_status_id = (SELECT product_status_id FROM catalog.product_status_lookup WHERE code = 'DRAFT')) AS draft_products,
    (SELECT COUNT(DISTINCT product_id) FROM catalog.products WHERE product_status_id = (SELECT product_status_id FROM catalog.product_status_lookup WHERE code = 'DISCONTINUED')) AS discontinued_products,
    (SELECT COUNT(DISTINCT product_id) FROM catalog.products WHERE is_featured = TRUE) AS featured_products,
    (SELECT COUNT(DISTINCT product_id) FROM catalog.products WHERE is_visible = TRUE) AS visible_products,
    (SELECT COUNT(DISTINCT product_id) FROM catalog.products WHERE product_id NOT IN (SELECT DISTINCT product_id FROM catalog.product_media WHERE is_active = TRUE)) AS products_without_media,
    (SELECT COUNT(DISTINCT collection_id) FROM catalog.collections WHERE is_active = TRUE) AS active_collections,
    (SELECT COUNT(DISTINCT product_tag_id) FROM catalog.product_tags WHERE is_active = TRUE) AS active_tags,
    (SELECT COUNT(DISTINCT product_id) FROM catalog.products WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS new_products_7d;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Product by ID
CREATE OR REPLACE FUNCTION reports.fn_get_product(
    p_product_id UUID
)
RETURNS TABLE (
    product_code VARCHAR,
    product_name VARCHAR,
    product_status VARCHAR,
    product_type VARCHAR,
    brand_name VARCHAR,
    variant_count BIGINT,
    category_count BIGINT,
    media_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.product_code::VARCHAR,
        p.product_name::VARCHAR,
        psl.code::VARCHAR,
        pt.type_name::VARCHAR,
        b.brand_name::VARCHAR,
        COUNT(DISTINCT pv.variant_id),
        COUNT(DISTINCT pc.category_id),
        COUNT(DISTINCT pm.product_media_id)
    FROM catalog.products p
    JOIN catalog.product_status_lookup psl ON psl.product_status_id = p.product_status_id
    JOIN catalog.product_types pt ON pt.product_type_id = p.product_type_id
    LEFT JOIN catalog.brands b ON b.brand_id = p.brand_id
    LEFT JOIN catalog.product_variants pv ON pv.product_id = p.product_id AND pv.is_active = TRUE
    LEFT JOIN catalog.product_categories pc ON pc.product_id = p.product_id
    LEFT JOIN catalog.product_media pm ON pm.product_id = p.product_id AND pm.is_active = TRUE
    WHERE p.product_id = p_product_id
    GROUP BY p.product_id, p.product_code, p.product_name, psl.code, pt.type_name, b.brand_name;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Products by Category
CREATE OR REPLACE FUNCTION reports.fn_get_products_by_category(
    p_category_id UUID,
    p_include_children BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    product_id UUID,
    product_code VARCHAR,
    product_name VARCHAR,
    product_status VARCHAR,
    brand_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        p.product_id,
        p.product_code::VARCHAR,
        p.product_name::VARCHAR,
        psl.code::VARCHAR,
        b.brand_name::VARCHAR
    FROM catalog.products p
    JOIN catalog.product_status_lookup psl ON psl.product_status_id = p.product_status_id
    LEFT JOIN catalog.brands b ON b.brand_id = p.brand_id
    JOIN catalog.product_categories pc ON pc.product_id = p.product_id
    WHERE pc.category_id = p_category_id
       OR (p_include_children AND pc.category_id IN (
           SELECT category_id FROM catalog.categories WHERE parent_category_id = p_category_id
       ))
    ORDER BY p.product_name;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Category Tree
CREATE OR REPLACE FUNCTION reports.fn_get_category_tree(
    p_company_id UUID,
    p_parent_category_id UUID DEFAULT NULL
)
RETURNS TABLE (
    category_id UUID,
    category_code VARCHAR,
    category_name VARCHAR,
    parent_category_id UUID,
    product_count BIGINT,
    child_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.category_id,
        c.category_code::VARCHAR,
        c.category_name::VARCHAR,
        c.parent_category_id,
        COUNT(DISTINCT pc.product_id),
        COUNT(DISTINCT child.category_id)
    FROM catalog.categories c
    LEFT JOIN catalog.product_categories pc ON pc.category_id = c.category_id
    LEFT JOIN catalog.categories child ON child.parent_category_id = c.category_id AND child.is_active = TRUE
    WHERE c.company_id = p_company_id
      AND (p_parent_category_id IS NULL OR c.parent_category_id = p_parent_category_id)
      AND c.is_active = TRUE
    GROUP BY c.category_id, c.category_code, c.category_name, c.parent_category_id
    ORDER BY c.sort_order, c.category_name;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Products Without Media
CREATE OR REPLACE FUNCTION reports.fn_get_products_without_media(
    p_company_id UUID
)
RETURNS TABLE (
    product_id UUID,
    product_code VARCHAR,
    product_name VARCHAR,
    product_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.product_id,
        p.product_code::VARCHAR,
        p.product_name::VARCHAR,
        psl.code::VARCHAR
    FROM catalog.products p
    JOIN catalog.product_status_lookup psl ON psl.product_status_id = p.product_status_id
    WHERE p.company_id = p_company_id
      AND p.is_active = TRUE
      AND p.product_id NOT IN (
          SELECT DISTINCT product_id FROM catalog.product_media WHERE is_active = TRUE
      )
    ORDER BY p.product_name;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Product Inventory Summary
CREATE OR REPLACE FUNCTION reports.fn_get_product_inventory(
    p_product_id UUID
)
RETURNS TABLE (
    variant_id UUID,
    sku VARCHAR,
    warehouse_name VARCHAR,
    quantity_on_hand NUMERIC,
    quantity_reserved NUMERIC,
    available_quantity NUMERIC,
    reorder_level NUMERIC,
    stock_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        pv.variant_id,
        pv.sku::VARCHAR,
        w.warehouse_name::VARCHAR,
        i.quantity_on_hand,
        i.quantity_reserved,
        (i.quantity_on_hand - i.quantity_reserved),
        i.reorder_level,
        CASE
            WHEN i.quantity_on_hand <= 0 THEN 'OUT_OF_STOCK'
            WHEN i.quantity_on_hand <= i.reorder_level THEN 'LOW_STOCK'
            ELSE 'IN_STOCK'
        END::VARCHAR
    FROM catalog.product_variants pv
    LEFT JOIN inventory.inventories i ON i.product_variant_id = pv.variant_id
    LEFT JOIN inventory.warehouses w ON w.warehouse_id = i.warehouse_id
    WHERE pv.product_id = p_product_id
      AND pv.is_active = TRUE
    ORDER BY pv.sku, w.warehouse_name;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 04 Product Catalog
-- 15 Views + 5 Functions = 20 Report Objects
-- 15 Reports as per reports02.html catalog
-- ============================================================