BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 28 — WISHLIST / FAVORITES / SAVED ITEMS
-- DATABASE TABLES
-- ============================================================
-- Design Decisions:
--   1. Wishlist is not a cart — Wishlist is for future intent,
--      Cart is for current purchase intent
--   2. Wishlists should support multiple lists per customer
--   3. Guest wishlists should be supported — merge on login
--   4. Gift Registry extends Wishlist — don't create independent system
--   5. Price and stock alerts should be event-driven
--   6. Wishlist is an important personalization signal — feed into Module 27
--   7. Wishlists are customer-owned and persistent, carts are session-based
-- ============================================================
-- Components:
--   28.1  Wishlists
--   28.2  Wishlist Items
--   28.3  Guest Wishlists
--   28.4  Shared Wishlists
--   28.5  Gift Registries
--   28.6  Wishlist Alerts (Price/Stock)
--   28.7  Recently Viewed Products
--   28.8  Wishlist Analytics
--   28.9  Save for Later (from Cart)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS wishlist;

-- ============================================================
-- 28.0 WISHLIST LOOKUPS
-- ============================================================

-- Wishlist Type
CREATE TABLE IF NOT EXISTS wishlist.wishlist_type_lookup (
    wishlist_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO wishlist.wishlist_type_lookup (code, name, description, sort_order) VALUES
    ('STANDARD', 'Standard Wishlist', 'Default customer wishlist.', 10),
    ('FAVORITES', 'Favorites', 'Quick favorites for easy access.', 20),
    ('SAVE_FOR_LATER', 'Save for Later', 'Items saved from cart for later.', 30),
    ('GIFT_REGISTRY', 'Gift Registry', 'Gift registry for events.', 40),
    ('SHARED', 'Shared Wishlist', 'Wishlist shared with others.', 50),
    ('SEASONAL', 'Seasonal', 'Seasonal wishlist.', 60),
    ('BIRTHDAY', 'Birthday', 'Birthday wishlist.', 70),
    ('WEDDING', 'Wedding', 'Wedding registry.', 80),
    ('BABY', 'Baby', 'Baby registry.', 90),
    ('CUSTOM', 'Custom', 'Custom named wishlist.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Wishlist Visibility
CREATE TABLE IF NOT EXISTS wishlist.wishlist_visibility_lookup (
    wishlist_visibility_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO wishlist.wishlist_visibility_lookup (code, name, description, sort_order) VALUES
    ('PRIVATE', 'Private', 'Only the owner can view.', 10),
    ('UNLISTED', 'Unlisted', 'Viewable only via direct link.', 20),
    ('PUBLIC', 'Public', 'Anyone can view.', 30),
    ('SHARED', 'Shared', 'Shared with specific people.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Wishlist Item Status
CREATE TABLE IF NOT EXISTS wishlist.wishlist_item_status_lookup (
    wishlist_item_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO wishlist.wishlist_item_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Item is active in wishlist.', 10),
    ('PURCHASED', 'Purchased', 'Item has been purchased.', 20),
    ('MOVED_TO_CART', 'Moved to Cart', 'Item moved to cart.', 30),
    ('OUT_OF_STOCK', 'Out of Stock', 'Item is out of stock.', 40),
    ('PRICE_DROPPED', 'Price Dropped', 'Item price has dropped.', 50),
    ('DISCONTINUED', 'Discontinued', 'Item is discontinued.', 60),
    ('REMOVED', 'Removed', 'Item removed from wishlist.', 70),
    ('GIFTED', 'Gifted', 'Item was gifted.', 80),
    ('RESERVED', 'Reserved', 'Item reserved (gift registry).', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Alert Type
CREATE TABLE IF NOT EXISTS wishlist.alert_type_lookup (
    alert_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO wishlist.alert_type_lookup (code, name, description, sort_order) VALUES
    ('PRICE_DROP', 'Price Drop', 'Alert when price drops.', 10),
    ('BACK_IN_STOCK', 'Back in Stock', 'Alert when item is back in stock.', 20),
    ('LOW_STOCK', 'Low Stock', 'Alert when stock is low.', 30),
    ('NEW_ARRIVAL', 'New Arrival', 'Alert for new arrivals in category.', 40),
    ('PRICE_TARGET', 'Price Target', 'Alert when price reaches target.', 50),
    ('RESTOCK', 'Restock', 'Alert for restock notification.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Alert Status
CREATE TABLE IF NOT EXISTS wishlist.alert_status_lookup (
    alert_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO wishlist.alert_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Alert is pending.', 10),
    ('TRIGGERED', 'Triggered', 'Alert condition met.', 20),
    ('SENT', 'Sent', 'Notification sent.', 30),
    ('DELIVERED', 'Delivered', 'Notification delivered.', 40),
    ('EXPIRED', 'Expired', 'Alert expired.', 50),
    ('CANCELLED', 'Cancelled', 'Alert cancelled.', 60),
    ('PURCHASED', 'Purchased', 'Item purchased before alert.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Recently Viewed Source
CREATE TABLE IF NOT EXISTS wishlist.recently_viewed_source_lookup (
    recently_viewed_source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO wishlist.recently_viewed_source_lookup (code, name, description, sort_order) VALUES
    ('PRODUCT_PAGE', 'Product Page', 'Viewed on product page.', 10),
    ('SEARCH_RESULTS', 'Search Results', 'Viewed from search.', 20),
    ('CATEGORY_PAGE', 'Category Page', 'Viewed from category.', 30),
    ('RECOMMENDATION', 'Recommendation', 'Viewed from recommendation.', 40),
    ('WISHLIST', 'Wishlist', 'Viewed from wishlist.', 50),
    ('EMAIL', 'Email', 'Viewed from email.', 60),
    ('SOCIAL', 'Social Media', 'Viewed from social media.', 70),
    ('DIRECT', 'Direct', 'Direct URL access.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 28.1 WISHLISTS
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.wishlists (
    wishlist_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    wishlist_type_id UUID NOT NULL DEFAULT (SELECT wishlist_type_id FROM wishlist.wishlist_type_lookup WHERE code = 'STANDARD'),
    wishlist_visibility_id UUID NOT NULL DEFAULT (SELECT wishlist_visibility_id FROM wishlist.wishlist_visibility_lookup WHERE code = 'PRIVATE'),

    wishlist_code VARCHAR(50) NOT NULL,
    wishlist_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    share_token VARCHAR(100) NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    total_items INTEGER NOT NULL DEFAULT 0,
    total_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    -- Gift Registry Fields
    event_name VARCHAR(200) NULL,
    event_date DATE NULL,
    event_type VARCHAR(50) NULL,

    last_viewed_at TIMESTAMPTZ NULL,
    last_modified_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_wl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_wl_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_wl_type FOREIGN KEY (wishlist_type_id) REFERENCES wishlist.wishlist_type_lookup(wishlist_type_id),
    CONSTRAINT fk_wl_visibility FOREIGN KEY (wishlist_visibility_id) REFERENCES wishlist.wishlist_visibility_lookup(wishlist_visibility_id),
    CONSTRAINT uq_wishlist_code UNIQUE (company_id, customer_id, wishlist_code),
    CONSTRAINT ck_wl_event CHECK (event_type IS NULL OR event_type IN ('BIRTHDAY', 'WEDDING', 'BABY', 'ANNIVERSARY', 'GRADUATION', 'HOUSEWARMING', 'HOLIDAY', 'OTHER'))
);

CREATE INDEX ix_wl_company ON wishlist.wishlists(company_id);
CREATE INDEX ix_wl_customer ON wishlist.wishlists(customer_id);
CREATE INDEX ix_wl_type ON wishlist.wishlists(wishlist_type_id);
CREATE INDEX ix_wl_active ON wishlist.wishlists(is_active);
CREATE INDEX ix_wl_share_token ON wishlist.wishlists(share_token);

-- ============================================================
-- 28.2 WISHLIST ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.wishlist_items (
    wishlist_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wishlist_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    item_status_id UUID NOT NULL DEFAULT (SELECT wishlist_item_status_id FROM wishlist.wishlist_item_status_lookup WHERE code = 'ACTIVE'),

    quantity INTEGER NOT NULL DEFAULT 1,
    note TEXT NULL,
    priority INTEGER NOT NULL DEFAULT 0,

    -- Price tracking
    price_at_add NUMERIC(19,4) NULL,
    current_price NUMERIC(19,4) NULL,
    currency_id UUID NULL,
    price_change_percent NUMERIC(7,4) NULL,
    price_target NUMERIC(19,4) NULL,

    -- Stock tracking
    stock_status_at_add VARCHAR(30) NULL,
    is_out_of_stock BOOLEAN NOT NULL DEFAULT FALSE,
    was_out_of_stock BOOLEAN NOT NULL DEFAULT FALSE,

    -- Gift Registry fields
    is_gift BOOLEAN NOT NULL DEFAULT FALSE,
    gifted_by_customer_id UUID NULL,
    gifted_at TIMESTAMPTZ NULL,
    reserved_by_customer_id UUID NULL,
    reserved_at TIMESTAMPTZ NULL,

    -- Source tracking
    added_from_source_id UUID NULL,
    added_from_url VARCHAR(1000) NULL,
    added_from_campaign_id UUID NULL,

    -- Status tracking
    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    moved_to_cart_at TIMESTAMPTZ NULL,
    purchased_at TIMESTAMPTZ NULL,
    removed_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wi_wishlist FOREIGN KEY (wishlist_id) REFERENCES wishlist.wishlists(wishlist_id) ON DELETE CASCADE,
    CONSTRAINT fk_wi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_wi_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_wi_status FOREIGN KEY (item_status_id) REFERENCES wishlist.wishlist_item_status_lookup(wishlist_item_status_id),
    CONSTRAINT fk_wi_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT fk_wi_gifted_by FOREIGN KEY (gifted_by_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_wi_reserved_by FOREIGN KEY (reserved_by_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_wi_source FOREIGN KEY (added_from_source_id) REFERENCES wishlist.recently_viewed_source_lookup(recently_viewed_source_id),
    CONSTRAINT fk_wi_campaign FOREIGN KEY (added_from_campaign_id) REFERENCES marketing.campaigns(campaign_id),
    CONSTRAINT uq_wishlist_item UNIQUE (wishlist_id, product_id, COALESCE(product_variant_id, '00000000-0000-0000-0000-000000000000')),
    CONSTRAINT ck_wi_quantity CHECK (quantity >= 1),
    CONSTRAINT ck_wi_priority CHECK (priority >= 0 AND priority <= 100)
);

CREATE INDEX ix_wi_wishlist ON wishlist.wishlist_items(wishlist_id);
CREATE INDEX ix_wi_product ON wishlist.wishlist_items(product_id);
CREATE INDEX ix_wi_status ON wishlist.wishlist_items(item_status_id);
CREATE INDEX ix_wi_active ON wishlist.wishlist_items(is_active);
CREATE INDEX ix_wi_price_change ON wishlist.wishlist_items(price_change_percent);

-- ============================================================
-- 28.3 GUEST WISHLISTS
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.guest_wishlists (
    guest_wishlist_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    session_id VARCHAR(200) NOT NULL,
    session_token VARCHAR(200) NULL,

    total_items INTEGER NOT NULL DEFAULT 0,
    total_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    ip_address INET NULL,
    user_agent TEXT NULL,

    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,

    -- Merge tracking
    is_merged BOOLEAN NOT NULL DEFAULT FALSE,
    merged_customer_id UUID NULL,
    merged_wishlist_id UUID NULL,
    merged_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_gwl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_gwl_merged_customer FOREIGN KEY (merged_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_gwl_merged_wishlist FOREIGN KEY (merged_wishlist_id) REFERENCES wishlist.wishlists(wishlist_id),
    CONSTRAINT uq_guest_session UNIQUE (company_id, session_id),
    CONSTRAINT ck_gwl_expiry CHECK (expires_at > created_at)
);

CREATE INDEX ix_gwl_company ON wishlist.guest_wishlists(company_id);
CREATE INDEX ix_gwl_session ON wishlist.guest_wishlists(session_id);
CREATE INDEX ix_gwl_active ON wishlist.guest_wishlists(is_active);
CREATE INDEX ix_gwl_merged ON wishlist.guest_wishlists(is_merged);

-- Guest Wishlist Items
CREATE TABLE IF NOT EXISTS wishlist.guest_wishlist_items (
    guest_wishlist_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guest_wishlist_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity INTEGER NOT NULL DEFAULT 1,
    note TEXT NULL,

    price_at_add NUMERIC(19,4) NULL,
    currency_id UUID NULL,

    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_gwi_wishlist FOREIGN KEY (guest_wishlist_id) REFERENCES wishlist.guest_wishlists(guest_wishlist_id) ON DELETE CASCADE,
    CONSTRAINT fk_gwi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_gwi_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_gwi_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_guest_wishlist_item UNIQUE (guest_wishlist_id, product_id, COALESCE(product_variant_id, '00000000-0000-0000-0000-000000000000')),
    CONSTRAINT ck_gwi_quantity CHECK (quantity >= 1)
);

CREATE INDEX ix_gwi_wishlist ON wishlist.guest_wishlist_items(guest_wishlist_id);
CREATE INDEX ix_gwi_product ON wishlist.guest_wishlist_items(product_id);

-- ============================================================
-- 28.4 SHARED WISHLISTS
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.wishlist_shares (
    wishlist_share_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wishlist_id UUID NOT NULL,

    shared_with_customer_id UUID NULL,
    shared_with_email VARCHAR(300) NULL,
    shared_with_name VARCHAR(200) NULL,

    share_token VARCHAR(100) NOT NULL,
    share_url VARCHAR(1000) NULL,

    can_edit BOOLEAN NOT NULL DEFAULT FALSE,
    can_purchase BOOLEAN NOT NULL DEFAULT TRUE,
    can_reserve BOOLEAN NOT NULL DEFAULT TRUE,

    -- Gift Registry fields
    can_see_purchasers BOOLEAN NOT NULL DEFAULT FALSE,
    hide_purchased_items BOOLEAN NOT NULL DEFAULT FALSE,

    shared_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NULL,

    last_accessed_at TIMESTAMPTZ NULL,
    access_count INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ws_wishlist FOREIGN KEY (wishlist_id) REFERENCES wishlist.wishlists(wishlist_id) ON DELETE CASCADE,
    CONSTRAINT fk_ws_customer FOREIGN KEY (shared_with_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT uq_share_token UNIQUE (share_token)
);

CREATE INDEX ix_ws_wishlist ON wishlist.wishlist_shares(wishlist_id);
CREATE INDEX ix_ws_customer ON wishlist.wishlist_shares(shared_with_customer_id);
CREATE INDEX ix_ws_token ON wishlist.wishlist_shares(share_token);

-- ============================================================
-- 28.6 WISHLIST ALERTS
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.wishlist_alerts (
    wishlist_alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    wishlist_item_id UUID NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    alert_type_id UUID NOT NULL,
    alert_status_id UUID NOT NULL DEFAULT (SELECT alert_status_id FROM wishlist.alert_status_lookup WHERE code = 'PENDING'),

    -- Alert conditions
    target_price NUMERIC(19,4) NULL,
    price_drop_percent NUMERIC(5,2) NULL,
    stock_threshold INTEGER NULL,

    -- Notification settings
    notification_channel VARCHAR(30) NOT NULL DEFAULT 'EMAIL',
    notification_sent_at TIMESTAMPTZ NULL,
    notification_id UUID NULL,

    -- Tracking
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    triggered_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wa_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_wa_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_wa_wishlist_item FOREIGN KEY (wishlist_item_id) REFERENCES wishlist.wishlist_items(wishlist_item_id),
    CONSTRAINT fk_wa_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_wa_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_wa_type FOREIGN KEY (alert_type_id) REFERENCES wishlist.alert_type_lookup(alert_type_id),
    CONSTRAINT fk_wa_status FOREIGN KEY (alert_status_id) REFERENCES wishlist.alert_status_lookup(alert_status_id),
    CONSTRAINT ck_wa_channel CHECK (notification_channel IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP', 'WHATSAPP')),
    CONSTRAINT ck_wa_conditions CHECK (
        (target_price IS NOT NULL) OR
        (price_drop_percent IS NOT NULL) OR
        (stock_threshold IS NOT NULL) OR
        alert_type_id IN (
            (SELECT alert_type_id FROM wishlist.alert_type_lookup WHERE code = 'BACK_IN_STOCK'),
            (SELECT alert_type_id FROM wishlist.alert_type_lookup WHERE code = 'NEW_ARRIVAL')
        )
    )
);

CREATE INDEX ix_wa_company ON wishlist.wishlist_alerts(company_id);
CREATE INDEX ix_wa_customer ON wishlist.wishlist_alerts(customer_id);
CREATE INDEX ix_wa_product ON wishlist.wishlist_alerts(product_id);
CREATE INDEX ix_wa_status ON wishlist.wishlist_alerts(alert_status_id);
CREATE INDEX ix_wa_active ON wishlist.wishlist_alerts(is_active);

-- ============================================================
-- 28.7 RECENTLY VIEWED PRODUCTS
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.recently_viewed_products (
    recently_viewed_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NULL,
    session_id VARCHAR(200) NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    recently_viewed_source_id UUID NULL,

    page_url VARCHAR(1000) NULL,
    referrer_url VARCHAR(1000) NULL,
    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    view_duration_seconds INTEGER NULL,

    viewed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ip_address INET NULL,
    user_agent TEXT NULL,
    device_type VARCHAR(30) NULL,

    CONSTRAINT fk_rvp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rvp_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rvp_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rvp_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_rvp_source FOREIGN KEY (recently_viewed_source_id) REFERENCES wishlist.recently_viewed_source_lookup(recently_viewed_source_id)
);

CREATE INDEX ix_rvp_company ON wishlist.recently_viewed_products(company_id);
CREATE INDEX ix_rvp_customer ON wishlist.recently_viewed_products(customer_id);
CREATE INDEX ix_rvp_session ON wishlist.recently_viewed_products(session_id);
CREATE INDEX ix_rvp_product ON wishlist.recently_viewed_products(product_id);
CREATE INDEX ix_rvp_viewed ON wishlist.recently_viewed_products(viewed_at DESC);

-- ============================================================
-- 28.8 WISHLIST ANALYTICS (Read Model)
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.wishlist_analytics (
    wishlist_analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    wishlist_id UUID NULL,
    wishlist_type_id UUID NULL,

    stat_date DATE NOT NULL,

    total_wishlists INTEGER NOT NULL DEFAULT 0,
    total_items INTEGER NOT NULL DEFAULT 0,
    total_value NUMERIC(19,4) NOT NULL DEFAULT 0,

    items_added INTEGER NOT NULL DEFAULT 0,
    items_removed INTEGER NOT NULL DEFAULT 0,
    items_moved_to_cart INTEGER NOT NULL DEFAULT 0,
    items_purchased INTEGER NOT NULL DEFAULT 0,

    price_drops_detected INTEGER NOT NULL DEFAULT 0,
    stock_alerts_triggered INTEGER NOT NULL DEFAULT 0,

    conversion_rate NUMERIC(7,4) NULL,
    avg_items_per_wishlist NUMERIC(7,2) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wana_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_wana_wishlist FOREIGN KEY (wishlist_id) REFERENCES wishlist.wishlists(wishlist_id),
    CONSTRAINT fk_wana_type FOREIGN KEY (wishlist_type_id) REFERENCES wishlist.wishlist_type_lookup(wishlist_type_id),
    CONSTRAINT uq_wishlist_analytics UNIQUE (company_id, wishlist_id, wishlist_type_id, stat_date)
);

CREATE INDEX ix_wana_company ON wishlist.wishlist_analytics(company_id);
CREATE INDEX ix_wana_date ON wishlist.wishlist_analytics(stat_date DESC);

-- ============================================================
-- 28.9 SAVE FOR LATER (from Cart)
-- ============================================================

CREATE TABLE IF NOT EXISTS wishlist.save_for_later_items (
    save_for_later_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    session_id VARCHAR(200) NULL,

    product_id UUID NOT NULL,
    product_variant_id UUID NULL,

    quantity INTEGER NOT NULL DEFAULT 1,
    price_at_save NUMERIC(19,4) NULL,
    currency_id UUID NULL,

    saved_from_order_id UUID NULL,
    saved_from_cart_session_id VARCHAR(200) NULL,

    saved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    moved_back_to_cart_at TIMESTAMPTZ NULL,
    removed_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sfl_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sfl_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_sfl_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_sfl_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_sfl_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_sfl_quantity CHECK (quantity >= 1)
);

CREATE INDEX ix_sfl_company ON wishlist.save_for_later_items(company_id);
CREATE INDEX ix_sfl_customer ON wishlist.save_for_later_items(customer_id);
CREATE INDEX ix_sfl_product ON wishlist.save_for_later_items(product_id);
CREATE INDEX ix_sfl_active ON wishlist.save_for_later_items(is_active);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Function: Get Customer Wishlists
CREATE OR REPLACE FUNCTION wishlist.get_customer_wishlists(
    p_customer_id UUID
)
RETURNS TABLE (
    wishlist_id UUID,
    wishlist_name VARCHAR,
    wishlist_type VARCHAR,
    visibility VARCHAR,
    total_items INTEGER,
    total_value NUMERIC,
    is_default BOOLEAN,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        wl.wishlist_id,
        wl.wishlist_name::VARCHAR,
        wlt.name::VARCHAR,
        wlv.name::VARCHAR,
        wl.total_items,
        wl.total_value,
        wl.is_default,
        wl.created_at
    FROM wishlist.wishlists wl
    JOIN wishlist.wishlist_type_lookup wlt ON wlt.wishlist_type_id = wl.wishlist_type_id
    JOIN wishlist.wishlist_visibility_lookup wlv ON wlv.wishlist_visibility_id = wl.wishlist_visibility_id
    WHERE wl.customer_id = p_customer_id
      AND wl.is_active = TRUE
    ORDER BY wl.is_default DESC, wl.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function: Merge Guest Wishlist into Customer Wishlist
CREATE OR REPLACE FUNCTION wishlist.merge_guest_wishlist(
    p_session_id VARCHAR,
    p_customer_id UUID,
    p_company_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_guest_wishlist_id UUID;
    v_customer_wishlist_id UUID;
    v_item RECORD;
BEGIN
    -- Find guest wishlist
    SELECT guest_wishlist_id INTO v_guest_wishlist_id
    FROM wishlist.guest_wishlists
    WHERE session_id = p_session_id
      AND company_id = p_company_id
      AND is_active = TRUE
      AND is_merged = FALSE;

    IF v_guest_wishlist_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Find or create customer default wishlist
    SELECT wishlist_id INTO v_customer_wishlist_id
    FROM wishlist.wishlists
    WHERE customer_id = p_customer_id
      AND company_id = p_company_id
      AND is_default = TRUE
      AND is_active = TRUE;

    IF v_customer_wishlist_id IS NULL THEN
        INSERT INTO wishlist.wishlists (company_id, customer_id, wishlist_code, wishlist_name, is_default)
        VALUES (p_company_id, p_customer_id, 'WISHLIST-' || p_customer_id::TEXT, 'My Wishlist', TRUE)
        RETURNING wishlist_id INTO v_customer_wishlist_id;
    END IF;

    -- Merge items
    FOR v_item IN
        SELECT * FROM wishlist.guest_wishlist_items
        WHERE guest_wishlist_id = v_guest_wishlist_id AND is_active = TRUE
    LOOP
        INSERT INTO wishlist.wishlist_items (wishlist_id, product_id, product_variant_id, quantity, price_at_add, currency_id)
        VALUES (v_customer_wishlist_id, v_item.product_id, v_item.product_variant_id, v_item.quantity, v_item.price_at_add, v_item.currency_id)
        ON CONFLICT (wishlist_id, product_id, COALESCE(product_variant_id, '00000000-0000-0000-0000-000000000000'))
        DO UPDATE SET
            quantity = wishlist.wishlist_items.quantity + EXCLUDED.quantity,
            updated_at = CURRENT_TIMESTAMP;
    END LOOP;

    -- Mark guest wishlist as merged
    UPDATE wishlist.guest_wishlists
    SET is_merged = TRUE,
        merged_customer_id = p_customer_id,
        merged_wishlist_id = v_customer_wishlist_id,
        merged_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE guest_wishlist_id = v_guest_wishlist_id;

    RETURN v_customer_wishlist_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate Wishlist Value
CREATE OR REPLACE FUNCTION wishlist.calculate_wishlist_value(
    p_wishlist_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_total_value NUMERIC;
BEGIN
    SELECT COALESCE(SUM(wi.current_price * wi.quantity), 0) INTO v_total_value
    FROM wishlist.wishlist_items wi
    WHERE wi.wishlist_id = p_wishlist_id
      AND wi.is_active = TRUE;

    UPDATE wishlist.wishlists
    SET total_value = v_total_value,
        updated_at = CURRENT_TIMESTAMP
    WHERE wishlist_id = p_wishlist_id;

    RETURN v_total_value;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_customer_id UUID;
    v_wishlist_id UUID;
    v_standard_type UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT wishlist_type_id INTO v_standard_type FROM wishlist.wishlist_type_lookup WHERE code = 'STANDARD';

    -- Get first customer
    SELECT customer_id INTO v_customer_id FROM crm.customers WHERE is_active = TRUE LIMIT 1;

    IF v_customer_id IS NOT NULL THEN
        -- Create default wishlist
        INSERT INTO wishlist.wishlists (company_id, customer_id, wishlist_code, wishlist_name, wishlist_type_id, is_default)
        SELECT v_company_id, v_customer_id, 'WISHLIST-' || v_customer_id::TEXT, 'My Wishlist', v_standard_type, TRUE
        WHERE NOT EXISTS (
            SELECT 1 FROM wishlist.wishlists
            WHERE customer_id = v_customer_id AND company_id = v_company_id AND is_default = TRUE
        )
        RETURNING wishlist_id INTO v_wishlist_id;

        -- Create favorites wishlist
        INSERT INTO wishlist.wishlists (company_id, customer_id, wishlist_code, wishlist_name, wishlist_type_id, is_default)
        SELECT v_company_id, v_customer_id, 'FAVORITES-' || v_customer_id::TEXT, 'Favorites',
               (SELECT wishlist_type_id FROM wishlist.wishlist_type_lookup WHERE code = 'FAVORITES'), FALSE
        WHERE NOT EXISTS (
            SELECT 1 FROM wishlist.wishlists
            WHERE customer_id = v_customer_id AND company_id = v_company_id AND wishlist_type_id = (SELECT wishlist_type_id FROM wishlist.wishlist_type_lookup WHERE code = 'FAVORITES')
        );
    END IF;

END $$;

COMMIT;