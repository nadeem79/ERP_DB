BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 25 — LOCALIZATION, MULTI-LANGUAGE, MULTI-CURRENCY
-- & REGIONALIZATION
-- DATABASE TABLES
-- ============================================================
-- Architecture Principles:
--   Rule 1 — Store language IDs, not language names
--   Rule 2 — Store currency IDs, not currency codes
--   Rule 3 — UTC in database
--   Rule 4 — Historical transactions are immutable
--   Rule 5 — Don't duplicate regional databases
--   Rule 6 — Translation is separate from business logic
-- ============================================================
-- Components:
--   25.1  Languages & Language Groups
--   25.2  Translations
--   25.3  Countries & States
--   25.4  Timezones
--   25.5  Currencies & Exchange Rates
--   25.6  Measurement Units & Unit Types
--   25.7  Regional Profiles
--   25.8  Localized URLs
--   25.9  Fallback Languages
--   25.10 Number/Date Formatting
-- ============================================================

CREATE SCHEMA IF NOT EXISTS localization;

-- ============================================================
-- 25.0 LOCALIZATION LOOKUPS
-- ============================================================

-- Language Groups
CREATE TABLE IF NOT EXISTS localization.language_group_lookup (
    language_group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO localization.language_group_lookup (code, name, description, sort_order) VALUES
    ('INDO_EUROPEAN', 'Indo-European', 'Indo-European language family.', 10),
    ('SEMITIC', 'Semitic', 'Semitic language family (Arabic, Hebrew).', 20),
    ('SINO_TIBETAN', 'Sino-Tibetan', 'Sino-Tibetan language family (Chinese).', 30),
    ('TURKIC', 'Turkic', 'Turkic language family.', 40),
    ('OTHER', 'Other', 'Other language families.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Entity Type for Translations
CREATE TABLE IF NOT EXISTS localization.translatable_entity_type_lookup (
    translatable_entity_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO localization.translatable_entity_type_lookup (code, name, description, sort_order) VALUES
    ('PRODUCT', 'Product', 'Product translations.', 10),
    ('PRODUCT_VARIANT', 'Product Variant', 'Product variant translations.', 20),
    ('CATEGORY', 'Category', 'Category translations.', 30),
    ('BRAND', 'Brand', 'Brand translations.', 40),
    ('CMS_PAGE', 'CMS Page', 'CMS page translations.', 50),
    ('CMS_BLOCK', 'CMS Block', 'CMS content block translations.', 60),
    ('BLOG_POST', 'Blog Post', 'Blog post translations.', 70),
    ('MENU_ITEM', 'Menu Item', 'Menu item translations.', 80),
    ('ATTRIBUTE', 'Attribute', 'Product attribute translations.', 90),
    ('ATTRIBUTE_VALUE', 'Attribute Value', 'Attribute value translations.', 100),
    ('SHIPPING_METHOD', 'Shipping Method', 'Shipping method translations.', 110),
    ('PAYMENT_METHOD', 'Payment Method', 'Payment method translations.', 120),
    ('EMAIL_TEMPLATE', 'Email Template', 'Email template translations.', 130),
    ('SMS_TEMPLATE', 'SMS Template', 'SMS template translations.', 140),
    ('NOTIFICATION', 'Notification', 'Notification translations.', 150),
    ('UI_LABEL', 'UI Label', 'User interface label translations.', 160),
    ('ERROR_MESSAGE', 'Error Message', 'Error message translations.', 170),
    ('COLLECTION', 'Collection', 'Collection translations.', 180)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Unit Types
CREATE TABLE IF NOT EXISTS localization.unit_type_lookup (
    unit_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO localization.unit_type_lookup (code, name, description, sort_order) VALUES
    ('WEIGHT', 'Weight', 'Weight measurement units.', 10),
    ('LENGTH', 'Length', 'Length measurement units.', 20),
    ('WIDTH', 'Width', 'Width measurement units.', 30),
    ('HEIGHT', 'Height', 'Height measurement units.', 40),
    ('VOLUME', 'Volume', 'Volume measurement units.', 50),
    ('TEMPERATURE', 'Temperature', 'Temperature measurement units.', 60),
    ('QUANTITY', 'Quantity', 'Quantity/count units.', 70),
    ('AREA', 'Area', 'Area measurement units.', 80),
    ('TIME', 'Time', 'Time measurement units.', 90),
    ('DATA', 'Data', 'Data storage units.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 25.1 LANGUAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.languages (
    language_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    language_group_id UUID NULL,

    code VARCHAR(10) NOT NULL UNIQUE,
    iso_639_1_code VARCHAR(5) NULL,
    iso_639_2_code VARCHAR(10) NULL,
    name VARCHAR(150) NOT NULL,
    native_name VARCHAR(200) NULL,

    is_rtl BOOLEAN NOT NULL DEFAULT FALSE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    date_format VARCHAR(50) NULL,
    time_format VARCHAR(50) NULL,
    number_format VARCHAR(50) NULL,
    currency_symbol_position VARCHAR(10) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_lang_group FOREIGN KEY (language_group_id) REFERENCES localization.language_group_lookup(language_group_id),
    CONSTRAINT ck_lang_rtl CHECK (is_rtl IN (TRUE, FALSE)),
    CONSTRAINT ck_lang_currency_pos CHECK (currency_symbol_position IS NULL OR currency_symbol_position IN ('PREFIX', 'SUFFIX', 'PREFIX_SPACE', 'SUFFIX_SPACE'))
);

CREATE INDEX ix_lang_code ON localization.languages(code);
CREATE INDEX ix_lang_active ON localization.languages(is_active);

-- ============================================================
-- 25.2 TRANSLATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.translations (
    translation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    language_id UUID NOT NULL,
    translatable_entity_type_id UUID NOT NULL,

    entity_id UUID NOT NULL,
    field_name VARCHAR(100) NOT NULL,
    translated_text TEXT NOT NULL,

    is_auto_translated BOOLEAN NOT NULL DEFAULT FALSE,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_trans_lang FOREIGN KEY (language_id) REFERENCES localization.languages(language_id),
    CONSTRAINT fk_trans_entity_type FOREIGN KEY (translatable_entity_type_id) REFERENCES localization.translatable_entity_type_lookup(translatable_entity_type_id),
    CONSTRAINT uq_translation UNIQUE (language_id, translatable_entity_type_id, entity_id, field_name)
);

CREATE INDEX ix_trans_entity ON localization.translations(entity_id);
CREATE INDEX ix_trans_lang ON localization.translations(language_id);
CREATE INDEX ix_trans_entity_type ON localization.translations(translatable_entity_type_id);
CREATE INDEX ix_trans_field ON localization.translations(field_name);

-- ============================================================
-- 25.3 COUNTRIES & STATES
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.countries (
    country_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(10) NOT NULL UNIQUE,
    iso_3166_1_alpha2 VARCHAR(5) NULL,
    iso_3166_1_alpha3 VARCHAR(10) NULL,
    iso_3166_1_numeric VARCHAR(10) NULL,

    name VARCHAR(200) NOT NULL,
    native_name VARCHAR(200) NULL,

    phone_code VARCHAR(20) NULL,
    currency_id UUID NULL,
    timezone_id UUID NULL,

    date_format VARCHAR(50) NULL,
    address_format TEXT NULL,

    continent VARCHAR(50) NULL,
    region VARCHAR(100) NULL,

    is_eu_member BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_country_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_country_phone CHECK (phone_code IS NULL OR phone_code ~ '^\+[0-9]{1,4}$')
);

CREATE INDEX ix_country_code ON localization.countries(code);
CREATE INDEX ix_country_active ON localization.countries(is_active);

-- States/Provinces
CREATE TABLE IF NOT EXISTS localization.states (
    state_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL,

    code VARCHAR(20) NOT NULL,
    name VARCHAR(200) NOT NULL,
    native_name VARCHAR(200) NULL,

    state_type VARCHAR(50) NULL,
    tax_rate NUMERIC(7,4) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_state_country FOREIGN KEY (country_id) REFERENCES localization.countries(country_id) ON DELETE CASCADE,
    CONSTRAINT uq_state UNIQUE (country_id, code),
    CONSTRAINT ck_state_tax CHECK (tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 100)),
    CONSTRAINT ck_state_type CHECK (state_type IS NULL OR state_type IN ('STATE', 'PROVINCE', 'TERRITORY', 'REGION', 'DISTRICT', 'EMIRATE', 'GOVERNORATE'))
);

CREATE INDEX ix_state_country ON localization.states(country_id);
CREATE INDEX ix_state_active ON localization.states(is_active);

-- Cities (Optional)
CREATE TABLE IF NOT EXISTS localization.cities (
    city_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id UUID NOT NULL,
    country_id UUID NOT NULL,

    code VARCHAR(50) NULL,
    name VARCHAR(200) NOT NULL,
    native_name VARCHAR(200) NULL,

    latitude NUMERIC(10,7) NULL,
    longitude NUMERIC(10,7) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_city_state FOREIGN KEY (state_id) REFERENCES localization.states(state_id) ON DELETE CASCADE,
    CONSTRAINT fk_city_country FOREIGN KEY (country_id) REFERENCES localization.countries(country_id) ON DELETE CASCADE,
    CONSTRAINT ck_city_coords CHECK (
        (latitude IS NULL AND longitude IS NULL) OR
        (latitude IS NOT NULL AND longitude IS NOT NULL)
    )
);

CREATE INDEX ix_city_state ON localization.cities(state_id);
CREATE INDEX ix_city_country ON localization.cities(country_id);

-- ============================================================
-- 25.4 TIMEZONES
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.timezones (
    timezone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,

    utc_offset_minutes INTEGER NOT NULL DEFAULT 0,
    utc_offset_display VARCHAR(10) NULL,

    observes_dst BOOLEAN NOT NULL DEFAULT FALSE,
    dst_offset_minutes INTEGER NULL,

    region VARCHAR(100) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT ck_tz_offset CHECK (utc_offset_minutes >= -720 AND utc_offset_minutes <= 840)
);

CREATE INDEX ix_tz_code ON localization.timezones(code);
CREATE INDEX ix_tz_active ON localization.timezones(is_active);

-- ============================================================
-- 25.5 CURRENCIES & EXCHANGE RATES
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.currencies (
    currency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(10) NOT NULL UNIQUE,
    iso_4217_code VARCHAR(10) NULL,
    iso_4217_numeric VARCHAR(10) NULL,

    name VARCHAR(150) NOT NULL,
    native_name VARCHAR(200) NULL,
    symbol VARCHAR(20) NULL,
    symbol_position VARCHAR(10) NOT NULL DEFAULT 'PREFIX',

    decimal_places INTEGER NOT NULL DEFAULT 2,
    decimal_separator VARCHAR(5) NOT NULL DEFAULT '.',
    thousands_separator VARCHAR(5) NOT NULL DEFAULT ',',

    is_crypto BOOLEAN NOT NULL DEFAULT FALSE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT ck_curr_symbol_pos CHECK (symbol_position IN ('PREFIX', 'SUFFIX', 'PREFIX_SPACE', 'SUFFIX_SPACE')),
    CONSTRAINT ck_curr_decimals CHECK (decimal_places >= 0 AND decimal_places <= 8)
);

CREATE INDEX ix_curr_code ON localization.currencies(code);
CREATE INDEX ix_curr_active ON localization.currencies(is_active);

-- Exchange Rates
CREATE TABLE IF NOT EXISTS localization.exchange_rates (
    exchange_rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    from_currency_id UUID NOT NULL,
    to_currency_id UUID NOT NULL,

    rate NUMERIC(19,8) NOT NULL,
    inverse_rate NUMERIC(19,8) NULL,

    effective_from TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_to TIMESTAMPTZ NULL,

    source VARCHAR(50) NULL,
    is_manual BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_er_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_er_from_curr FOREIGN KEY (from_currency_id) REFERENCES localization.currencies(currency_id),
    CONSTRAINT fk_er_to_curr FOREIGN KEY (to_currency_id) REFERENCES localization.currencies(currency_id),
    CONSTRAINT ck_er_rate CHECK (rate > 0),
    CONSTRAINT ck_er_currencies CHECK (from_currency_id <> to_currency_id),
    CONSTRAINT ck_er_dates CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE INDEX ix_er_company ON localization.exchange_rates(company_id);
CREATE INDEX ix_er_from_to ON localization.exchange_rates(from_currency_id, to_currency_id);
CREATE INDEX ix_er_effective ON localization.exchange_rates(effective_from DESC);

-- ============================================================
-- 25.6 MEASUREMENT UNITS
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.measurement_units (
    measurement_unit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_type_id UUID NOT NULL,

    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    symbol VARCHAR(20) NULL,

    conversion_factor NUMERIC(19,8) NOT NULL DEFAULT 1.0,
    base_unit_id UUID NULL,

    decimal_places INTEGER NOT NULL DEFAULT 2,

    is_base_unit BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_mu_type FOREIGN KEY (unit_type_id) REFERENCES localization.unit_type_lookup(unit_type_id),
    CONSTRAINT fk_mu_base FOREIGN KEY (base_unit_id) REFERENCES localization.measurement_units(measurement_unit_id),
    CONSTRAINT ck_mu_factor CHECK (conversion_factor > 0),
    CONSTRAINT ck_mu_decimals CHECK (decimal_places >= 0 AND decimal_places <= 8)
);

CREATE INDEX ix_mu_type ON localization.measurement_units(unit_type_id);
CREATE INDEX ix_mu_active ON localization.measurement_units(is_active);

-- ============================================================
-- 25.7 REGIONAL PROFILES
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.regional_profiles (
    regional_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    site_id UUID NULL,

    profile_code VARCHAR(50) NOT NULL,
    profile_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    country_id UUID NULL,
    language_id UUID NULL,
    currency_id UUID NULL,
    timezone_id UUID NULL,

    date_format VARCHAR(50) NULL,
    time_format VARCHAR(50) NULL,
    number_format VARCHAR(50) NULL,

    tax_rate NUMERIC(7,4) NULL,
    tax_inclusive BOOLEAN NOT NULL DEFAULT FALSE,

    week_start_day INTEGER NOT NULL DEFAULT 1,
    first_day_of_week VARCHAR(20) NOT NULL DEFAULT 'MONDAY',

    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rp_site FOREIGN KEY (site_id) REFERENCES cms.sites(site_id),
    CONSTRAINT fk_rp_country FOREIGN KEY (country_id) REFERENCES localization.countries(country_id),
    CONSTRAINT fk_rp_language FOREIGN KEY (language_id) REFERENCES localization.languages(language_id),
    CONSTRAINT fk_rp_currency FOREIGN KEY (currency_id) REFERENCES localization.currencies(currency_id),
    CONSTRAINT fk_rp_timezone FOREIGN KEY (timezone_id) REFERENCES localization.timezones(timezone_id),
    CONSTRAINT uq_regional_profile UNIQUE (company_id, profile_code),
    CONSTRAINT ck_rp_week_start CHECK (week_start_day >= 1 AND week_start_day <= 7),
    CONSTRAINT ck_rp_first_day CHECK (first_day_of_week IN ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY')),
    CONSTRAINT ck_rp_tax CHECK (tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 100))
);

CREATE INDEX ix_rp_company ON localization.regional_profiles(company_id);
CREATE INDEX ix_rp_site ON localization.regional_profiles(site_id);

-- ============================================================
-- 25.8 LOCALIZED URLs
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.localized_urls (
    localized_url_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    language_id UUID NOT NULL,
    translatable_entity_type_id UUID NOT NULL,

    entity_id UUID NOT NULL,
    slug VARCHAR(500) NOT NULL,
    full_url VARCHAR(1000) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_lu_lang FOREIGN KEY (language_id) REFERENCES localization.languages(language_id),
    CONSTRAINT fk_lu_entity_type FOREIGN KEY (translatable_entity_type_id) REFERENCES localization.translatable_entity_type_lookup(translatable_entity_type_id),
    CONSTRAINT uq_localized_url UNIQUE (language_id, translatable_entity_type_id, entity_id)
);

CREATE INDEX ix_lu_entity ON localization.localized_urls(entity_id);
CREATE INDEX ix_lu_lang ON localization.localized_urls(language_id);
CREATE INDEX ix_lu_slug ON localization.localized_urls(slug);

-- ============================================================
-- 25.9 FALLBACK LANGUAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS localization.language_fallbacks (
    language_fallback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    language_id UUID NOT NULL,
    fallback_language_id UUID NOT NULL,

    priority INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_lf_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_lf_lang FOREIGN KEY (language_id) REFERENCES localization.languages(language_id),
    CONSTRAINT fk_lf_fallback_lang FOREIGN KEY (fallback_language_id) REFERENCES localization.languages(language_id),
    CONSTRAINT uq_language_fallback UNIQUE (company_id, language_id, fallback_language_id),
    CONSTRAINT ck_lf_not_self CHECK (language_id <> fallback_language_id)
);

CREATE INDEX ix_lf_lang ON localization.language_fallbacks(language_id);
CREATE INDEX ix_lf_fallback ON localization.language_fallbacks(fallback_language_id);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Function: Get Translation with Fallback
CREATE OR REPLACE FUNCTION localization.get_translation(
    p_entity_type_code VARCHAR,
    p_entity_id UUID,
    p_field_name VARCHAR,
    p_language_code VARCHAR,
    p_company_id UUID DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_result TEXT;
    v_fallback_language_code VARCHAR;
BEGIN
    -- Try primary language
    SELECT t.translated_text INTO v_result
    FROM localization.translations t
    JOIN localization.languages l ON l.language_id = t.language_id
    JOIN localization.translatable_entity_type_lookup et ON et.translatable_entity_type_id = t.translatable_entity_type_id
    WHERE et.code = p_entity_type_code
      AND t.entity_id = p_entity_id
      AND t.field_name = p_field_name
      AND l.code = p_language_code;

    -- If not found, try fallback language
    IF v_result IS NULL AND p_company_id IS NOT NULL THEN
        SELECT fl.code INTO v_fallback_language_code
        FROM localization.language_fallbacks lf
        JOIN localization.languages l ON l.language_id = lf.language_id
        JOIN localization.languages fl ON fl.language_id = lf.fallback_language_id
        WHERE lf.company_id = p_company_id
          AND l.code = p_language_code
          AND lf.is_active = TRUE
        ORDER BY lf.priority ASC
        LIMIT 1;

        IF v_fallback_language_code IS NOT NULL THEN
            SELECT t.translated_text INTO v_result
            FROM localization.translations t
            JOIN localization.languages l ON l.language_id = t.language_id
            JOIN localization.translatable_entity_type_lookup et ON et.translatable_entity_type_id = t.translatable_entity_type_id
            WHERE et.code = p_entity_type_code
              AND t.entity_id = p_entity_id
              AND t.field_name = p_field_name
              AND l.code = v_fallback_language_code;
        END IF;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Function: Convert Currency
CREATE OR REPLACE FUNCTION localization.convert_currency(
    p_amount NUMERIC,
    p_from_currency_id UUID,
    p_to_currency_id UUID,
    p_company_id UUID,
    p_at_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
RETURNS NUMERIC AS $$
DECLARE
    v_rate NUMERIC;
    v_from_decimals INTEGER;
    v_to_decimals INTEGER;
BEGIN
    IF p_from_currency_id = p_to_currency_id THEN
        RETURN p_amount;
    END IF;

    SELECT er.rate INTO v_rate
    FROM localization.exchange_rates er
    WHERE er.company_id = p_company_id
      AND er.from_currency_id = p_from_currency_id
      AND er.to_currency_id = p_to_currency_id
      AND er.effective_from <= p_at_date
      AND (er.effective_to IS NULL OR er.effective_to > p_at_date)
    ORDER BY er.effective_from DESC
    LIMIT 1;

    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'Exchange rate not found for currencies % to %', p_from_currency_id, p_to_currency_id;
    END IF;

    SELECT decimal_places INTO v_to_decimals FROM localization.currencies WHERE currency_id = p_to_currency_id;

    RETURN ROUND(p_amount * v_rate, COALESCE(v_to_decimals, 2));
END;
$$ LANGUAGE plpgsql;

-- Function: Convert Measurement Unit
CREATE OR REPLACE FUNCTION localization.convert_unit(
    p_value NUMERIC,
    p_from_unit_id UUID,
    p_to_unit_id UUID
)
RETURNS NUMERIC AS $$
DECLARE
    v_from_unit RECORD;
    v_to_unit RECORD;
    v_base_value NUMERIC;
BEGIN
    IF p_from_unit_id = p_to_unit_id THEN
        RETURN p_value;
    END IF;

    SELECT * INTO v_from_unit FROM localization.measurement_units WHERE measurement_unit_id = p_from_unit_id;
    SELECT * INTO v_to_unit FROM localization.measurement_units WHERE measurement_unit_id = p_to_unit_id;

    IF v_from_unit.unit_type_id <> v_to_unit.unit_type_id THEN
        RAISE EXCEPTION 'Cannot convert between different unit types';
    END IF;

    -- Convert to base unit first
    v_base_value := p_value * v_from_unit.conversion_factor;

    -- Convert from base unit to target unit
    RETURN ROUND(v_base_value / v_to_unit.conversion_factor, v_to_unit.decimal_places);
END;
$$ LANGUAGE plpgsql;

-- Function: Get Regional Profile Settings
CREATE OR REPLACE FUNCTION localization.get_regional_settings(
    p_company_id UUID,
    p_site_id UUID DEFAULT NULL
)
RETURNS TABLE (
    profile_code VARCHAR,
    profile_name VARCHAR,
    country_code VARCHAR,
    country_name VARCHAR,
    language_code VARCHAR,
    language_name VARCHAR,
    currency_code VARCHAR,
    currency_symbol VARCHAR,
    timezone_code VARCHAR,
    timezone_name VARCHAR,
    date_format VARCHAR,
    time_format VARCHAR,
    number_format VARCHAR,
    tax_rate NUMERIC,
    tax_inclusive BOOLEAN,
    week_start_day INTEGER,
    first_day_of_week VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rp.profile_code::VARCHAR,
        rp.profile_name::VARCHAR,
        c.code::VARCHAR,
        c.name::VARCHAR,
        l.code::VARCHAR,
        l.name::VARCHAR,
        cur.code::VARCHAR,
        cur.symbol::VARCHAR,
        tz.code::VARCHAR,
        tz.name::VARCHAR,
        rp.date_format::VARCHAR,
        rp.time_format::VARCHAR,
        rp.number_format::VARCHAR,
        rp.tax_rate,
        rp.tax_inclusive,
        rp.week_start_day,
        rp.first_day_of_week::VARCHAR
    FROM localization.regional_profiles rp
    LEFT JOIN localization.countries c ON c.country_id = rp.country_id
    LEFT JOIN localization.languages l ON l.language_id = rp.language_id
    LEFT JOIN localization.currencies cur ON cur.currency_id = rp.currency_id
    LEFT JOIN localization.timezones tz ON tz.timezone_id = rp.timezone_id
    WHERE rp.company_id = p_company_id
      AND (p_site_id IS NULL OR rp.site_id = p_site_id)
      AND rp.is_active = TRUE
    ORDER BY rp.is_default DESC, rp.profile_code;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_en_lang UUID;
    v_ur_lang UUID;
    v_ar_lang UUID;
    v_pkr_curr UUID;
    v_usd_curr UUID;
    v_aed_curr UUID;
    v_gbp_curr UUID;
    v_kg_unit UUID;
    v_g_unit UUID;
    v_m_unit UUID;
    v_cm_unit UUID;
    v_l_unit UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Create Languages
    INSERT INTO localization.languages (code, iso_639_1_code, name, native_name, is_rtl, is_default)
    SELECT 'en', 'en', 'English', 'English', FALSE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM localization.languages WHERE code = 'en')
    RETURNING language_id INTO v_en_lang;

    INSERT INTO localization.languages (code, iso_639_1_code, name, native_name, is_rtl)
    SELECT 'ur', 'ur', 'Urdu', 'اردو', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM localization.languages WHERE code = 'ur')
    RETURNING language_id INTO v_ur_lang;

    INSERT INTO localization.languages (code, iso_639_1_code, name, native_name, is_rtl)
    SELECT 'ar', 'ar', 'Arabic', 'العربية', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM localization.languages WHERE code = 'ar')
    RETURNING language_id INTO v_ar_lang;

    IF v_en_lang IS NULL THEN SELECT language_id INTO v_en_lang FROM localization.languages WHERE code = 'en'; END IF;
    IF v_ur_lang IS NULL THEN SELECT language_id INTO v_ur_lang FROM localization.languages WHERE code = 'ur'; END IF;
    IF v_ar_lang IS NULL THEN SELECT language_id INTO v_ar_lang FROM localization.languages WHERE code = 'ar'; END IF;

    -- Create Currencies
    INSERT INTO localization.currencies (code, iso_4217_code, name, symbol, symbol_position, decimal_places, is_default)
    SELECT 'PKR', '586', 'Pakistani Rupee', 'Rs.', 'PREFIX', 2, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM localization.currencies WHERE code = 'PKR')
    RETURNING currency_id INTO v_pkr_curr;

    INSERT INTO localization.currencies (code, iso_4217_code, name, symbol, symbol_position, decimal_places)
    SELECT 'USD', '840', 'US Dollar', '$', 'PREFIX', 2
    WHERE NOT EXISTS (SELECT 1 FROM localization.currencies WHERE code = 'USD')
    RETURNING currency_id INTO v_usd_curr;

    INSERT INTO localization.currencies (code, iso_4217_code, name, symbol, symbol_position, decimal_places)
    SELECT 'AED', '784', 'UAE Dirham', 'د.إ', 'SUFFIX', 2
    WHERE NOT EXISTS (SELECT 1 FROM localization.currencies WHERE code = 'AED')
    RETURNING currency_id INTO v_aed_curr;

    INSERT INTO localization.currencies (code, iso_4217_code, name, symbol, symbol_position, decimal_places)
    SELECT 'GBP', '826', 'British Pound', '£', 'PREFIX', 2
    WHERE NOT EXISTS (SELECT 1 FROM localization.currencies WHERE code = 'GBP')
    RETURNING currency_id INTO v_gbp_curr;

    IF v_pkr_curr IS NULL THEN SELECT currency_id INTO v_pkr_curr FROM localization.currencies WHERE code = 'PKR'; END IF;
    IF v_usd_curr IS NULL THEN SELECT currency_id INTO v_usd_curr FROM localization.currencies WHERE code = 'USD'; END IF;
    IF v_aed_curr IS NULL THEN SELECT currency_id INTO v_aed_curr FROM localization.currencies WHERE code = 'AED'; END IF;
    IF v_gbp_curr IS NULL THEN SELECT currency_id INTO v_gbp_curr FROM localization.currencies WHERE code = 'GBP'; END IF;

    -- Create Timezones
    INSERT INTO localization.timezones (code, name, utc_offset_minutes, utc_offset_display, region)
    SELECT 'Asia/Karachi', 'Pakistan Standard Time', 300, 'UTC+05:00', 'Asia'
    WHERE NOT EXISTS (SELECT 1 FROM localization.timezones WHERE code = 'Asia/Karachi');

    INSERT INTO localization.timezones (code, name, utc_offset_minutes, utc_offset_display, region)
    SELECT 'Asia/Dubai', 'Gulf Standard Time', 240, 'UTC+04:00', 'Asia'
    WHERE NOT EXISTS (SELECT 1 FROM localization.timezones WHERE code = 'Asia/Dubai');

    INSERT INTO localization.timezones (code, name, utc_offset_minutes, utc_offset_display, observes_dst, dst_offset_minutes, region)
    SELECT 'Europe/London', 'Greenwich Mean Time', 0, 'UTC+00:00', TRUE, 60, 'Europe'
    WHERE NOT EXISTS (SELECT 1 FROM localization.timezones WHERE code = 'Europe/London');

    INSERT INTO localization.timezones (code, name, utc_offset_minutes, utc_offset_display, region)
    SELECT 'America/New_York', 'Eastern Standard Time', -300, 'UTC-05:00', 'America'
    WHERE NOT EXISTS (SELECT 1 FROM localization.timezones WHERE code = 'America/New_York');

    -- Create Countries
    INSERT INTO localization.countries (code, iso_3166_1_alpha2, name, phone_code, currency_id, timezone_id, continent, date_format)
    SELECT 'PK', 'PAK', 'Pakistan', '+92', v_pkr_curr,
           (SELECT timezone_id FROM localization.timezones WHERE code = 'Asia/Karachi'),
           'Asia', 'dd/MM/yyyy'
    WHERE NOT EXISTS (SELECT 1 FROM localization.countries WHERE code = 'PK');

    INSERT INTO localization.countries (code, iso_3166_1_alpha2, name, phone_code, currency_id, timezone_id, continent, date_format)
    SELECT 'AE', 'ARE', 'United Arab Emirates', '+971', v_aed_curr,
           (SELECT timezone_id FROM localization.timezones WHERE code = 'Asia/Dubai'),
           'Asia', 'dd/MM/yyyy'
    WHERE NOT EXISTS (SELECT 1 FROM localization.countries WHERE code = 'AE');

    INSERT INTO localization.countries (code, iso_3166_1_alpha2, name, phone_code, currency_id, timezone_id, continent, date_format)
    SELECT 'GB', 'GBR', 'United Kingdom', '+44', v_gbp_curr,
           (SELECT timezone_id FROM localization.timezones WHERE code = 'Europe/London'),
           'Europe', 'dd/MM/yyyy'
    WHERE NOT EXISTS (SELECT 1 FROM localization.countries WHERE code = 'GB');

    INSERT INTO localization.countries (code, iso_3166_1_alpha2, name, phone_code, currency_id, timezone_id, continent, date_format)
    SELECT 'US', 'USA', 'United States', '+1', v_usd_curr,
           (SELECT timezone_id FROM localization.timezones WHERE code = 'America/New_York'),
           'America', 'MM/dd/yyyy'
    WHERE NOT EXISTS (SELECT 1 FROM localization.countries WHERE code = 'US');

    -- Create States for Pakistan
    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'PB', 'Punjab', 'PROVINCE'
    FROM localization.countries c WHERE c.code = 'PK'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'PB');

    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'SD', 'Sindh', 'PROVINCE'
    FROM localization.countries c WHERE c.code = 'PK'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'SD');

    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'KP', 'Khyber Pakhtunkhwa', 'PROVINCE'
    FROM localization.countries c WHERE c.code = 'PK'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'KP');

    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'BL', 'Balochistan', 'PROVINCE'
    FROM localization.countries c WHERE c.code = 'PK'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'BL');

    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'IS', 'Islamabad Capital Territory', 'TERRITORY'
    FROM localization.countries c WHERE c.code = 'PK'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'IS');

    -- Create States for UAE
    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'AZ', 'Abu Dhabi', 'EMIRATE'
    FROM localization.countries c WHERE c.code = 'AE'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'AZ');

    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'DU', 'Dubai', 'EMIRATE'
    FROM localization.countries c WHERE c.code = 'AE'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'DU');

    INSERT INTO localization.states (country_id, code, name, state_type)
    SELECT c.country_id, 'SH', 'Sharjah', 'EMIRATE'
    FROM localization.countries c WHERE c.code = 'AE'
    AND NOT EXISTS (SELECT 1 FROM localization.states s WHERE s.country_id = c.country_id AND s.code = 'SH');

    -- Create Measurement Units
    INSERT INTO localization.measurement_units (unit_type_id, code, name, symbol, conversion_factor, is_base_unit, decimal_places)
    SELECT (SELECT unit_type_id FROM localization.unit_type_lookup WHERE code = 'WEIGHT'),
           'KG', 'Kilogram', 'kg', 1.0, TRUE, 3
    WHERE NOT EXISTS (SELECT 1 FROM localization.measurement_units WHERE code = 'KG')
    RETURNING measurement_unit_id INTO v_kg_unit;

    INSERT INTO localization.measurement_units (unit_type_id, code, name, symbol, conversion_factor, base_unit_id, decimal_places)
    SELECT (SELECT unit_type_id FROM localization.unit_type_lookup WHERE code = 'WEIGHT'),
           'G', 'Gram', 'g', 0.001, v_kg_unit, 0
    WHERE NOT EXISTS (SELECT 1 FROM localization.measurement_units WHERE code = 'G')
    RETURNING measurement_unit_id INTO v_g_unit;

    INSERT INTO localization.measurement_units (unit_type_id, code, name, symbol, conversion_factor, is_base_unit, decimal_places)
    SELECT (SELECT unit_type_id FROM localization.unit_type_lookup WHERE code = 'LENGTH'),
           'M', 'Meter', 'm', 1.0, TRUE, 2
    WHERE NOT EXISTS (SELECT 1 FROM localization.measurement_units WHERE code = 'M')
    RETURNING measurement_unit_id INTO v_m_unit;

    INSERT INTO localization.measurement_units (unit_type_id, code, name, symbol, conversion_factor, base_unit_id, decimal_places)
    SELECT (SELECT unit_type_id FROM localization.unit_type_lookup WHERE code = 'LENGTH'),
           'CM', 'Centimeter', 'cm', 0.01, v_m_unit, 1
    WHERE NOT EXISTS (SELECT 1 FROM localization.measurement_units WHERE code = 'CM')
    RETURNING measurement_unit_id INTO v_cm_unit;

    INSERT INTO localization.measurement_units (unit_type_id, code, name, symbol, conversion_factor, is_base_unit, decimal_places)
    SELECT (SELECT unit_type_id FROM localization.unit_type_lookup WHERE code = 'VOLUME'),
           'L', 'Litre', 'L', 1.0, TRUE, 2
    WHERE NOT EXISTS (SELECT 1 FROM localization.measurement_units WHERE code = 'L')
    RETURNING measurement_unit_id INTO v_l_unit;

    -- Create Regional Profiles
    INSERT INTO localization.regional_profiles (company_id, profile_code, profile_name, country_id, language_id, currency_id, timezone_id, tax_rate, tax_inclusive, is_default)
    SELECT v_company_id, 'PK-DEFAULT', 'Pakistan Default',
           (SELECT country_id FROM localization.countries WHERE code = 'PK'),
           v_en_lang, v_pkr_curr,
           (SELECT timezone_id FROM localization.timezones WHERE code = 'Asia/Karachi'),
           18.0, FALSE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM localization.regional_profiles WHERE company_id = v_company_id AND profile_code = 'PK-DEFAULT');

    INSERT INTO localization.regional_profiles (company_id, profile_code, profile_name, country_id, language_id, currency_id, timezone_id, tax_rate, tax_inclusive)
    SELECT v_company_id, 'AE-DEFAULT', 'UAE Default',
           (SELECT country_id FROM localization.countries WHERE code = 'AE'),
           v_ar_lang, v_aed_curr,
           (SELECT timezone_id FROM localization.timezones WHERE code = 'Asia/Dubai'),
           5.0, FALSE
    WHERE NOT EXISTS (SELECT 1 FROM localization.regional_profiles WHERE company_id = v_company_id AND profile_code = 'AE-DEFAULT');

    INSERT INTO localization.regional_profiles (company_id, profile_code, profile_name, country_id, language_id, currency_id, timezone_id, tax_rate, tax_inclusive)
    SELECT v_company_id, 'GB-DEFAULT', 'UK Default',
           (SELECT country_id FROM localization.countries WHERE code = 'GB'),
           v_en_lang, v_gbp_curr,
           (SELECT timezone_id FROM localization.timezones WHERE code = 'Europe/London'),
           20.0, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM localization.regional_profiles WHERE company_id = v_company_id AND profile_code = 'GB-DEFAULT');

    -- Create Language Fallbacks
    INSERT INTO localization.language_fallbacks (company_id, language_id, fallback_language_id, priority)
    SELECT v_company_id, v_ur_lang, v_en_lang, 0
    WHERE NOT EXISTS (SELECT 1 FROM localization.language_fallbacks WHERE company_id = v_company_id AND language_id = v_ur_lang AND fallback_language_id = v_en_lang);

    INSERT INTO localization.language_fallbacks (company_id, language_id, fallback_language_id, priority)
    SELECT v_company_id, v_ar_lang, v_en_lang, 0
    WHERE NOT EXISTS (SELECT 1 FROM localization.language_fallbacks WHERE company_id = v_company_id AND language_id = v_ar_lang AND fallback_language_id = v_en_lang);

    -- Create Exchange Rates (PKR base)
    INSERT INTO localization.exchange_rates (company_id, from_currency_id, to_currency_id, rate, effective_from)
    SELECT v_company_id, v_pkr_curr, v_usd_curr, 0.0036, CURRENT_TIMESTAMP
    WHERE NOT EXISTS (
        SELECT 1 FROM localization.exchange_rates er
        WHERE er.company_id = v_company_id AND er.from_currency_id = v_pkr_curr AND er.to_currency_id = v_usd_curr
    );

    INSERT INTO localization.exchange_rates (company_id, from_currency_id, to_currency_id, rate, effective_from)
    SELECT v_company_id, v_pkr_curr, v_aed_curr, 0.0132, CURRENT_TIMESTAMP
    WHERE NOT EXISTS (
        SELECT 1 FROM localization.exchange_rates er
        WHERE er.company_id = v_company_id AND er.from_currency_id = v_pkr_curr AND er.to_currency_id = v_aed_curr
    );

    INSERT INTO localization.exchange_rates (company_id, from_currency_id, to_currency_id, rate, effective_from)
    SELECT v_company_id, v_pkr_curr, v_gbp_curr, 0.0028, CURRENT_TIMESTAMP
    WHERE NOT EXISTS (
        SELECT 1 FROM localization.exchange_rates er
        WHERE er.company_id = v_company_id AND er.from_currency_id = v_pkr_curr AND er.to_currency_id = v_gbp_curr
    );

END $$;

COMMIT;