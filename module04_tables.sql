BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 04: PRODUCT CATALOG
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   Catalog owns WHAT is the product, WHAT variants exist,
--   WHAT attributes it has, WHERE is it available, HOW is it presented.
--   Catalog does NOT own pricing, inventory, orders, shipping, reviews, or SEO.
--   Products are company-scoped (multi-tenant).
-- ============================================================
-- Components:
--   04A  Catalog Foundation
--   04B  Product Types
--   04C  Brands
--   04D  Categories (Hierarchical)
--   04E  Products (Master Records)
--   04F  Product Variants
--   04G  SKUs & Identifiers
--   04H  Attributes
--   04I  Variant Attributes
--   04J  UOM & Physical Information
--   04K  Product Descriptions
--   04L  Product Localization
--   04M  Product Media
--   04N  Product Lifecycle
--   04O  Catalog Availability
--   04P  Collections
--   04Q  Tags
--   04R  Product Relationships
--   04S  Bundles / Kits / Packages
--   04T  Compatibility
--   04U  Specifications
--   04V  Product Documents
--   04W  SEO Integration
--   04X  Import / Export
--   04Y  Product Versioning
--   04Z  Catalog Audit
--   04AA Catalog 360 / Read Models
-- ============================================================

CREATE SCHEMA IF NOT EXISTS catalog;

-- ============================================================
-- 04A: PRODUCT STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_status_lookup (
    product_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO catalog.product_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Product is being created.', 10),
    ('ACTIVE', 'Active', 'Product is active and sellable.', 20),
    ('INACTIVE', 'Inactive', 'Product is temporarily inactive.', 30),
    ('DISCONTINUED', 'Discontinued', 'Product is discontinued.', 40),
    ('ARCHIVED', 'Archived', 'Product is archived.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 04B: PRODUCT TYPES
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_types (
    product_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    type_code VARCHAR(50) NOT NULL,
    type_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_physical BOOLEAN NOT NULL DEFAULT TRUE,
    is_digital BOOLEAN NOT NULL DEFAULT FALSE,
    is_service BOOLEAN NOT NULL DEFAULT FALSE,
    is_bundle BOOLEAN NOT NULL DEFAULT FALSE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_product_type UNIQUE (company_id, type_code)
);

CREATE INDEX ix_pt_company ON catalog.product_types(company_id);
CREATE INDEX ix_pt_active ON catalog.product_types(is_active);

-- ============================================================
-- 04C: BRANDS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.brands (
    brand_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    brand_code VARCHAR(50) NOT NULL,
    brand_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    logo_url VARCHAR(500) NULL,
    website_url VARCHAR(500) NULL,
    country_of_origin_id UUID NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_brand_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_brand_country FOREIGN KEY (country_of_origin_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT uq_brand_code UNIQUE (company_id, brand_code)
);

CREATE INDEX ix_brand_company ON catalog.brands(company_id);
CREATE INDEX ix_brand_active ON catalog.brands(is_active);

-- ============================================================
-- 04D: CATEGORIES (Hierarchical)
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    parent_category_id UUID NULL,

    category_code VARCHAR(50) NOT NULL,
    category_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    slug VARCHAR(200) NULL,

    image_storage_provider VARCHAR(50) NULL,
    image_storage_bucket VARCHAR(200) NULL,
    image_storage_key VARCHAR(500) NULL,
    image_storage_url VARCHAR(1500) NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cat_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cat_parent FOREIGN KEY (parent_category_id) REFERENCES catalog.categories(category_id),
    CONSTRAINT uq_category_code UNIQUE (company_id, category_code)
);

CREATE INDEX ix_cat_company ON catalog.categories(company_id);
CREATE INDEX ix_cat_parent ON catalog.categories(parent_category_id);
CREATE INDEX ix_cat_active ON catalog.categories(is_active);

-- ============================================================
-- 04E: PRODUCTS (Master Records)
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    catalog_id UUID NULL,
    product_type_id UUID NOT NULL,
    brand_id UUID NULL,
    product_status_id UUID NOT NULL DEFAULT (SELECT product_status_id FROM catalog.product_status_lookup WHERE code = 'DRAFT'),
    default_uom_id UUID NULL,
    country_of_origin_id UUID NULL,

    product_code VARCHAR(50) NOT NULL,
    product_name VARCHAR(300) NOT NULL,
    slug VARCHAR(300) NULL,

    short_description TEXT NULL,
    description TEXT NULL,

    manufacturer_name VARCHAR(200) NULL,
    manufacturer_part_number VARCHAR(100) NULL,

    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    sort_order INTEGER NOT NULL DEFAULT 0,
    published_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_prod_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_prod_type FOREIGN KEY (product_type_id) REFERENCES catalog.product_types(product_type_id),
    CONSTRAINT fk_prod_brand FOREIGN KEY (brand_id) REFERENCES catalog.brands(brand_id),
    CONSTRAINT fk_prod_status FOREIGN KEY (product_status_id) REFERENCES catalog.product_status_lookup(product_status_id),
    CONSTRAINT fk_prod_uom FOREIGN KEY (default_uom_id) REFERENCES reference.uom_lookup(uom_id),
    CONSTRAINT fk_prod_country FOREIGN KEY (country_of_origin_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT uq_product_code UNIQUE (company_id, product_code)
);

CREATE INDEX ix_prod_company ON catalog.products(company_id);
CREATE INDEX ix_prod_type ON catalog.products(product_type_id);
CREATE INDEX ix_prod_brand ON catalog.products(brand_id);
CREATE INDEX ix_prod_status ON catalog.products(product_status_id);
CREATE INDEX ix_prod_active ON catalog.products(is_active);
CREATE INDEX ix_prod_slug ON catalog.products(slug);

-- ============================================================
-- 04F: PRODUCT VARIANTS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_variants (
    variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    sku VARCHAR(100) NOT NULL,
    barcode VARCHAR(100) NULL,
    gtin VARCHAR(20) NULL,
    upc VARCHAR(20) NULL,
    ean VARCHAR(20) NULL,
    isbn VARCHAR(20) NULL,

    weight NUMERIC(19,4) NULL,
    weight_uom_id UUID NULL,
    length NUMERIC(19,4) NULL,
    width NUMERIC(19,4) NULL,
    height NUMERIC(19,4) NULL,
    dimension_uom_id UUID NULL,
    volume NUMERIC(19,4) NULL,
    volume_uom_id UUID NULL,

    cost_price NUMERIC(19,4) NULL,
    list_price NUMERIC(19,4) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pv_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pv_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pv_weight_uom FOREIGN KEY (weight_uom_id) REFERENCES reference.uom_lookup(uom_id),
    CONSTRAINT fk_pv_dim_uom FOREIGN KEY (dimension_uom_id) REFERENCES reference.uom_lookup(uom_id),
    CONSTRAINT fk_pv_vol_uom FOREIGN KEY (volume_uom_id) REFERENCES reference.uom_lookup(uom_id),
    CONSTRAINT uq_variant_sku UNIQUE (company_id, sku)
);

CREATE INDEX ix_pv_product ON catalog.product_variants(product_id);
CREATE INDEX ix_pv_sku ON catalog.product_variants(sku);
CREATE INDEX ix_pv_barcode ON catalog.product_variants(barcode);
CREATE INDEX ix_pv_active ON catalog.product_variants(is_active);

-- ============================================================
-- 04G: PRODUCT IDENTIFIERS (Additional SKUs/Barcodes)
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_identifiers (
    product_identifier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_variant_id UUID NOT NULL,
    company_id UUID NOT NULL,

    identifier_type VARCHAR(30) NOT NULL,
    identifier_value VARCHAR(200) NOT NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pi_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_pi_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_pi_type CHECK (identifier_type IN ('SKU', 'BARCODE', 'GTIN', 'UPC', 'EAN', 'ISBN', 'MPN', 'CUSTOM')),
    CONSTRAINT uq_identifier UNIQUE (company_id, identifier_type, identifier_value)
);

CREATE INDEX ix_pi_variant ON catalog.product_identifiers(product_variant_id);
CREATE INDEX ix_pi_value ON catalog.product_identifiers(identifier_value);

-- ============================================================
-- 04H: PRODUCT ATTRIBUTES
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_attributes (
    product_attribute_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    product_type_id UUID NULL,

    attribute_code VARCHAR(100) NOT NULL,
    attribute_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    data_type VARCHAR(30) NOT NULL DEFAULT 'TEXT',
    is_variant_attribute BOOLEAN NOT NULL DEFAULT FALSE,
    is_filterable BOOLEAN NOT NULL DEFAULT FALSE,
    is_searchable BOOLEAN NOT NULL DEFAULT FALSE,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pa_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pa_type FOREIGN KEY (product_type_id) REFERENCES catalog.product_types(product_type_id),
    CONSTRAINT uq_attribute UNIQUE (company_id, attribute_code),
    CONSTRAINT ck_pa_data_type CHECK (data_type IN ('TEXT', 'NUMBER', 'BOOLEAN', 'DATE', 'SELECT', 'MULTI_SELECT', 'COLOR', 'IMAGE'))
);

CREATE INDEX ix_pa_company ON catalog.product_attributes(company_id);
CREATE INDEX ix_pa_type ON catalog.product_attributes(product_type_id);
CREATE INDEX ix_pa_active ON catalog.product_attributes(is_active);

-- ============================================================
-- 04I: PRODUCT ATTRIBUTE VALUES
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_attribute_values (
    product_attribute_value_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    product_attribute_id UUID NOT NULL,
    company_id UUID NOT NULL,

    value_text TEXT NULL,
    value_number NUMERIC(19,4) NULL,
    value_boolean BOOLEAN NULL,
    value_date DATE NULL,
    value_json JSONB NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pav_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pav_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_pav_attribute FOREIGN KEY (product_attribute_id) REFERENCES catalog.product_attributes(product_attribute_id),
    CONSTRAINT fk_pav_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_attribute_value UNIQUE (product_id, COALESCE(product_variant_id, '00000000-0000-0000-0000-000000000000'::uuid), product_attribute_id)
);

CREATE INDEX ix_pav_product ON catalog.product_attribute_values(product_id);
CREATE INDEX ix_pav_variant ON catalog.product_attribute_values(product_variant_id);
CREATE INDEX ix_pav_attribute ON catalog.product_attribute_values(product_attribute_id);

-- ============================================================
-- 04J: PRODUCT CATEGORY ASSIGNMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_categories (
    product_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    category_id UUID NOT NULL,
    company_id UUID NOT NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pc_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_category FOREIGN KEY (category_id) REFERENCES catalog.categories(category_id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_product_category UNIQUE (product_id, category_id)
);

CREATE INDEX ix_pc_product ON catalog.product_categories(product_id);
CREATE INDEX ix_pc_category ON catalog.product_categories(category_id);

-- ============================================================
-- 04K: PRODUCT DESCRIPTIONS (Multi-language)
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_descriptions (
    product_description_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    language_code VARCHAR(10) NOT NULL DEFAULT 'en',

    product_name VARCHAR(300) NULL,
    short_description TEXT NULL,
    description TEXT NULL,
    meta_title VARCHAR(300) NULL,
    meta_description TEXT NULL,

    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pd_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pd_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_product_language UNIQUE (product_id, language_code)
);

CREATE INDEX ix_pd_product ON catalog.product_descriptions(product_id);
CREATE INDEX ix_pd_language ON catalog.product_descriptions(language_code);

-- ============================================================
-- 04M: PRODUCT MEDIA
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_media (
    product_media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    company_id UUID NOT NULL,

    media_type VARCHAR(30) NOT NULL DEFAULT 'IMAGE',

    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,

    file_name VARCHAR(500) NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,
    file_hash VARCHAR(128) NULL,

    title VARCHAR(300) NULL,
    alt_text VARCHAR(300) NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pm_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pm_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_pm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_pm_type CHECK (media_type IN ('IMAGE', 'VIDEO', '360_IMAGE', 'PDF', 'DOCUMENT', 'OTHER'))
);

CREATE INDEX ix_pm_product ON catalog.product_media(product_id);
CREATE INDEX ix_pm_variant ON catalog.product_media(product_variant_id);
CREATE INDEX ix_pm_active ON catalog.product_media(is_active);

-- ============================================================
-- 04O: CATALOG AVAILABILITY
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_availability (
    product_availability_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    availability_scope VARCHAR(30) NOT NULL DEFAULT 'ALL',
    channel_id UUID NULL,
    store_id UUID NULL,
    warehouse_id UUID NULL,

    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    available_from TIMESTAMPTZ NULL,
    available_to TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pav_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pav_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pav_store FOREIGN KEY (store_id) REFERENCES organization.stores(store_id),
    CONSTRAINT fk_pav_warehouse FOREIGN KEY (warehouse_id) REFERENCES inventory.warehouses(warehouse_id),
    CONSTRAINT ck_pav_scope CHECK (availability_scope IN ('ALL', 'CHANNEL', 'STORE', 'WAREHOUSE'))
);

CREATE INDEX ix_pav_product ON catalog.product_availability(product_id);
CREATE INDEX ix_pav_available ON catalog.product_availability(is_available);

-- ============================================================
-- 04P: COLLECTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.collections (
    collection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    collection_code VARCHAR(50) NOT NULL,
    collection_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    slug VARCHAR(200) NULL,

    collection_type VARCHAR(30) NOT NULL DEFAULT 'MANUAL',
    filter_criteria JSONB NULL,

    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_coll_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_collection UNIQUE (company_id, collection_code),
    CONSTRAINT ck_coll_type CHECK (collection_type IN ('MANUAL', 'DYNAMIC', 'SEASONAL', 'FEATURED'))
);

CREATE INDEX ix_coll_company ON catalog.collections(company_id);
CREATE INDEX ix_coll_active ON catalog.collections(is_active);

CREATE TABLE IF NOT EXISTS catalog.collection_products (
    collection_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID NOT NULL,
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cp_collection FOREIGN KEY (collection_id) REFERENCES catalog.collections(collection_id) ON DELETE CASCADE,
    CONSTRAINT fk_cp_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_cp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_collection_product UNIQUE (collection_id, product_id)
);

CREATE INDEX ix_cp_collection ON catalog.collection_products(collection_id);
CREATE INDEX ix_cp_product ON catalog.collection_products(product_id);

-- ============================================================
-- 04Q: PRODUCT TAGS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_tags (
    product_tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    tag_name VARCHAR(100) NOT NULL,
    tag_color VARCHAR(20) NULL,
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ptag_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_tag UNIQUE (company_id, tag_name)
);

CREATE INDEX ix_ptag_company ON catalog.product_tags(company_id);

CREATE TABLE IF NOT EXISTS catalog.product_tag_assignments (
    product_tag_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    product_tag_id UUID NOT NULL,
    company_id UUID NOT NULL,

    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by_user_id UUID NULL,

    CONSTRAINT fk_pta_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pta_tag FOREIGN KEY (product_tag_id) REFERENCES catalog.product_tags(product_tag_id) ON DELETE CASCADE,
    CONSTRAINT fk_pta_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_product_tag UNIQUE (product_id, product_tag_id)
);

CREATE INDEX ix_pta_product ON catalog.product_tag_assignments(product_id);
CREATE INDEX ix_pta_tag ON catalog.product_tag_assignments(product_tag_id);

-- ============================================================
-- 04R: PRODUCT RELATIONSHIPS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_relationship_type_lookup (
    product_relationship_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO catalog.product_relationship_type_lookup (code, name, description, sort_order) VALUES
    ('RELATED', 'Related Products', 'Related products.', 10),
    ('CROSS_SELL', 'Cross-Sell', 'Cross-sell products.', 20),
    ('UP_SELL', 'Up-Sell', 'Up-sell products.', 30),
    ('ACCESSORY', 'Accessory', 'Accessory products.', 40),
    ('REPLACEMENT', 'Replacement', 'Replacement products.', 50),
    ('COMPATIBLE', 'Compatible', 'Compatible products.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

CREATE TABLE IF NOT EXISTS catalog.product_relationships (
    product_relationship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    related_product_id UUID NOT NULL,
    product_relationship_type_id UUID NOT NULL,
    company_id UUID NOT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pr_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pr_related FOREIGN KEY (related_product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pr_type FOREIGN KEY (product_relationship_type_id) REFERENCES catalog.product_relationship_type_lookup(product_relationship_type_id),
    CONSTRAINT fk_pr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_relationship UNIQUE (product_id, related_product_id, product_relationship_type_id),
    CONSTRAINT ck_pr_not_self CHECK (product_id <> related_product_id)
);

CREATE INDEX ix_pr_product ON catalog.product_relationships(product_id);
CREATE INDEX ix_pr_related ON catalog.product_relationships(related_product_id);
CREATE INDEX ix_pr_type ON catalog.product_relationships(product_relationship_type_id);

-- ============================================================
-- 04S: BUNDLES / KITS / PACKAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_bundles (
    product_bundle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bundle_product_id UUID NOT NULL,
    component_product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    is_optional BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pb_bundle FOREIGN KEY (bundle_product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pb_component FOREIGN KEY (component_product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pb_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_bundle_component UNIQUE (bundle_product_id, component_product_id),
    CONSTRAINT ck_pb_not_self CHECK (bundle_product_id <> component_product_id),
    CONSTRAINT ck_pb_quantity CHECK (quantity > 0)
);

CREATE INDEX ix_pb_bundle ON catalog.product_bundles(bundle_product_id);
CREATE INDEX ix_pb_component ON catalog.product_bundles(component_product_id);

-- ============================================================
-- 04U: PRODUCT SPECIFICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_specifications (
    product_specification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    spec_group VARCHAR(100) NULL,
    spec_name VARCHAR(200) NOT NULL,
    spec_value TEXT NULL,
    spec_unit VARCHAR(50) NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_ps_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id)
);

CREATE INDEX ix_ps_product ON catalog.product_specifications(product_id);

-- ============================================================
-- 04V: PRODUCT DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_documents (
    product_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,
    document_type_id UUID NULL,

    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,

    file_name VARCHAR(500) NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,
    file_hash VARCHAR(128) NULL,

    title VARCHAR(300) NULL,
    document_version VARCHAR(20) NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pdoc_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pdoc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pdoc_type FOREIGN KEY (document_type_id) REFERENCES reference.document_type_lookup(document_type_id)
);

CREATE INDEX ix_pdoc_product ON catalog.product_documents(product_id);

-- ============================================================
-- 04Y: PRODUCT VERSIONING
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.product_versions (
    product_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    company_id UUID NOT NULL,

    version_number INTEGER NOT NULL DEFAULT 1,
    version_data JSONB NULL,

    change_description TEXT NULL,
    changed_by_user_id UUID NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    is_current BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_pver_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id) ON DELETE CASCADE,
    CONSTRAINT fk_pver_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_product_version UNIQUE (product_id, version_number)
);

CREATE INDEX ix_pver_product ON catalog.product_versions(product_id);

-- ============================================================
-- 04Z: CATALOG AUDIT
-- ============================================================

CREATE TABLE IF NOT EXISTS catalog.catalog_audit_log (
    catalog_audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    product_id UUID NULL,
    product_variant_id UUID NULL,

    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    field_name VARCHAR(100) NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,

    changed_by_user_id UUID NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cal_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cal_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_cal_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT ck_cal_action CHECK (action IN ('CREATE', 'UPDATE', 'DELETE', 'ACTIVATE', 'DEACTIVATE', 'DISCONTINUE', 'ARCHIVE')),
    CONSTRAINT ck_cal_entity CHECK (entity_type IN ('PRODUCT', 'VARIANT', 'CATEGORY', 'BRAND', 'ATTRIBUTE', 'MEDIA', 'DOCUMENT'))
);

CREATE INDEX ix_cal_product ON catalog.catalog_audit_log(product_id);
CREATE INDEX ix_cal_action ON catalog.catalog_audit_log(action);
CREATE INDEX ix_cal_changed ON catalog.catalog_audit_log(changed_at);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_simple_type UUID;
    v_variable_type UUID;
    v_bundle_type UUID;
    v_service_type UUID;
    v_digital_type UUID;
    v_draft_status UUID;
    v_active_status UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Seed Product Types
    INSERT INTO catalog.product_types (company_id, type_code, type_name, description, is_physical, is_digital, is_service, is_bundle) VALUES
        (v_company_id, 'SIMPLE', 'Simple Product', 'A simple physical product.', TRUE, FALSE, FALSE, FALSE),
        (v_company_id, 'VARIABLE', 'Variable Product', 'A product with multiple variants.', TRUE, FALSE, FALSE, FALSE),
        (v_company_id, 'BUNDLE', 'Bundle/Kit', 'A bundle of multiple products.', TRUE, FALSE, FALSE, TRUE),
        (v_company_id, 'SERVICE', 'Service', 'A service product.', FALSE, FALSE, TRUE, FALSE),
        (v_company_id, 'DIGITAL', 'Digital Product', 'A digital/downloadable product.', FALSE, TRUE, FALSE, FALSE)
    ON CONFLICT (company_id, type_code) DO NOTHING;

    -- Seed Brands
    INSERT INTO catalog.brands (company_id, brand_code, brand_name, description, is_active) VALUES
        (v_company_id, 'BRAND-001', 'eStore Premium', 'Premium eStore brand.', TRUE),
        (v_company_id, 'BRAND-002', 'ValueLine', 'Budget-friendly brand.', TRUE),
        (v_company_id, 'BRAND-003', 'TechPro', 'Technology products brand.', TRUE)
    ON CONFLICT (company_id, brand_code) DO NOTHING;

    -- Seed Categories
    INSERT INTO catalog.categories (company_id, category_code, category_name, description, slug, is_active) VALUES
        (v_company_id, 'CAT-ELECTRONICS', 'Electronics', 'Electronic products.', 'electronics', TRUE),
        (v_company_id, 'CAT-CLOTHING', 'Clothing', 'Clothing and apparel.', 'clothing', TRUE),
        (v_company_id, 'CAT-GROCERY', 'Grocery', 'Grocery items.', 'grocery', TRUE),
        (v_company_id, 'CAT-FURNITURE', 'Furniture', 'Furniture and home decor.', 'furniture', TRUE),
        (v_company_id, 'CAT-PERFUMES', 'Perfumes', 'Perfumes and fragrances.', 'perfumes', TRUE),
        (v_company_id, 'CAT-SHOES', 'Shoes', 'Shoes and footwear.', 'shoes', TRUE),
        (v_company_id, 'CAT-WALLETS', 'Wallets', 'Wallets and accessories.', 'wallets', TRUE),
        (v_company_id, 'CAT-BAGS', 'Bags', 'Bags and luggage.', 'bags', TRUE)
    ON CONFLICT (company_id, category_code) DO NOTHING;

    -- Seed Product Tags
    INSERT INTO catalog.product_tags (company_id, tag_name, tag_color, is_active) VALUES
        (v_company_id, 'NEW', '#27ae60', TRUE),
        (v_company_id, 'SALE', '#e74c3c', TRUE),
        (v_company_id, 'FEATURED', '#f39c12', TRUE),
        (v_company_id, 'BEST_SELLER', '#3498db', TRUE),
        (v_company_id, 'LIMITED_STOCK', '#e67e22', TRUE),
        (v_company_id, 'CLEARANCE', '#95a5a6', TRUE)
    ON CONFLICT (company_id, tag_name) DO NOTHING;

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 04 Product Catalog
-- 26 Tables + 2 Lookup Tables + Seed Data
-- ============================================================