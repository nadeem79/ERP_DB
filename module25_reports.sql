BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 25: LOCALIZATION REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Language Coverage Report
CREATE VIEW reports.vw_language_coverage AS
SELECT
    l.code as language_code,
    l.name as language_name,
    l.native_name,
    l.is_rtl,
    l.is_default,
    l.is_active,
    COUNT(DISTINCT t.translation_id) as total_translations,
    COUNT(DISTINCT t.translatable_entity_type_id) as entity_types_covered,
    COUNT(DISTINCT CASE WHEN t.is_approved = TRUE THEN t.translation_id END) as approved_translations,
    COUNT(DISTINCT CASE WHEN t.is_auto_translated = TRUE THEN t.translation_id END) as auto_translated
FROM localization.languages l
LEFT JOIN localization.translations t ON t.language_id = l.language_id
GROUP BY l.language_id, l.code, l.name, l.native_name, l.is_rtl, l.is_default, l.is_active
ORDER BY total_translations DESC NULLS LAST;

-- View 2: Translation Completeness Report
CREATE VIEW reports.vw_translation_completeness AS
SELECT
    et.code as entity_type,
    et.name as entity_type_name,
    l.code as language_code,
    l.name as language_name,
    COUNT(DISTINCT t.translation_id) as translated_count,
    COUNT(DISTINCT t.field_name) as fields_translated,
    COUNT(DISTINCT t.entity_id) as entities_translated
FROM localization.translatable_entity_type_lookup et
CROSS JOIN localization.languages l
LEFT JOIN localization.translations t ON t.translatable_entity_type_id = et.translatable_entity_type_id AND t.language_id = l.language_id
WHERE l.is_active = TRUE
GROUP BY et.translatable_entity_type_id, et.code, et.name, l.language_id, l.code, l.name
ORDER BY et.sort_order, l.code;

-- View 3: Country Coverage Report
CREATE VIEW reports.vw_country_coverage AS
SELECT
    c.code as country_code,
    c.name as country_name,
    c.native_name,
    c.phone_code,
    c.continent,
    c.region,
    c.is_eu_member,
    cur.code as currency_code,
    tz.code as timezone_code,
    COUNT(DISTINCT s.state_id) as state_count,
    COUNT(DISTINCT ci.city_id) as city_count,
    c.is_active
FROM localization.countries c
LEFT JOIN localization.currencies cur ON cur.currency_id = c.currency_id
LEFT JOIN localization.timezones tz ON tz.timezone_id = c.timezone_id
LEFT JOIN localization.states s ON s.country_id = c.country_id
LEFT JOIN localization.cities ci ON ci.country_id = c.country_id
GROUP BY c.country_id, c.code, c.name, c.native_name, c.phone_code, c.continent, c.region, c.is_eu_member, cur.code, tz.code, c.is_active
ORDER BY c.name;

-- View 4: Currency Exchange Rate Report
CREATE VIEW reports.vw_currency_exchange_rates AS
SELECT
    fc.code as from_currency,
    fc.name as from_currency_name,
    tc.code as to_currency,
    tc.name as to_currency_name,
    er.rate,
    er.inverse_rate,
    er.effective_from,
    er.effective_to,
    er.source,
    er.is_manual,
    CASE WHEN er.effective_to IS NULL OR er.effective_to > CURRENT_TIMESTAMP THEN TRUE ELSE FALSE END as is_current
FROM localization.exchange_rates er
JOIN localization.currencies fc ON fc.currency_id = er.from_currency_id
JOIN localization.currencies tc ON tc.currency_id = er.to_currency_id
ORDER BY er.effective_from DESC;

-- View 5: Regional Profile Report
CREATE VIEW reports.vw_regional_profiles AS
SELECT
    rp.profile_code,
    rp.profile_name,
    c.code as country_code,
    c.name as country_name,
    l.code as language_code,
    l.name as language_name,
    cur.code as currency_code,
    cur.symbol as currency_symbol,
    tz.code as timezone_code,
    tz.name as timezone_name,
    rp.date_format,
    rp.time_format,
    rp.tax_rate,
    rp.tax_inclusive,
    rp.week_start_day,
    rp.first_day_of_week,
    rp.is_default,
    rp.is_active
FROM localization.regional_profiles rp
LEFT JOIN localization.countries c ON c.country_id = rp.country_id
LEFT JOIN localization.languages l ON l.language_id = rp.language_id
LEFT JOIN localization.currencies cur ON cur.currency_id = rp.currency_id
LEFT JOIN localization.timezones tz ON tz.timezone_id = rp.timezone_id
ORDER BY rp.is_default DESC, rp.profile_code;

-- View 6: Measurement Unit Report
CREATE VIEW reports.vw_measurement_units AS
SELECT
    ut.code as unit_type_code,
    ut.name as unit_type_name,
    mu.code as unit_code,
    mu.name as unit_name,
    mu.symbol,
    mu.conversion_factor,
    mu.decimal_places,
    mu.is_base_unit,
    mu.is_active,
    bu.code as base_unit_code,
    bu.name as base_unit_name
FROM localization.measurement_units mu
JOIN localization.unit_type_lookup ut ON ut.unit_type_id = mu.unit_type_id
LEFT JOIN localization.measurement_units bu ON bu.measurement_unit_id = mu.base_unit_id
ORDER BY ut.sort_order, mu.is_base_unit DESC, mu.code;

-- View 7: Timezone Report
CREATE VIEW reports.vw_timezone_report AS
SELECT
    tz.code as timezone_code,
    tz.name as timezone_name,
    tz.utc_offset_minutes,
    tz.utc_offset_display,
    tz.observes_dst,
    tz.dst_offset_minutes,
    tz.region,
    tz.is_active,
    COUNT(DISTINCT c.country_id) as countries_using
FROM localization.timezones tz
LEFT JOIN localization.countries c ON c.timezone_id = tz.timezone_id
GROUP BY tz.timezone_id, tz.code, tz.name, tz.utc_offset_minutes, tz.utc_offset_display, tz.observes_dst, tz.dst_offset_minutes, tz.region, tz.is_active
ORDER BY tz.utc_offset_minutes;

-- View 8: Language Fallback Report
CREATE VIEW reports.vw_language_fallback_report AS
SELECT
    l.code as language_code,
    l.name as language_name,
    fl.code as fallback_language_code,
    fl.name as fallback_language_name,
    lf.priority,
    lf.is_active
FROM localization.language_fallbacks lf
JOIN localization.languages l ON l.language_id = lf.language_id
JOIN localization.languages fl ON fl.language_id = lf.fallback_language_id
ORDER BY l.code, lf.priority;

-- View 9: Localized URL Report
CREATE VIEW reports.vw_localized_urls AS
SELECT
    l.code as language_code,
    l.name as language_name,
    et.code as entity_type,
    lu.entity_id,
    lu.slug,
    lu.full_url,
    lu.is_active
FROM localization.localized_urls lu
JOIN localization.languages l ON l.language_id = lu.language_id
JOIN localization.translatable_entity_type_lookup et ON et.translatable_entity_type_id = lu.translatable_entity_type_id
ORDER BY l.code, et.code, lu.slug;

-- View 10: Missing Translations Report
CREATE VIEW reports.vw_missing_translations AS
SELECT
    et.code as entity_type,
    et.name as entity_type_name,
    l.code as language_code,
    l.name as language_name,
    COUNT(DISTINCT t.entity_id) as entities_with_translations,
    COUNT(DISTINCT t.field_name) as fields_translated
FROM localization.translatable_entity_type_lookup et
CROSS JOIN localization.languages l
LEFT JOIN localization.translations t ON t.translatable_entity_type_id = et.translatable_entity_type_id AND t.language_id = l.language_id
WHERE l.is_active = TRUE
  AND l.is_default = FALSE
GROUP BY et.translatable_entity_type_id, et.code, et.name, l.language_id, l.code, l.name
HAVING COUNT(DISTINCT t.entity_id) = 0
ORDER BY et.sort_order, l.code;

-- View 11: State/Province Coverage Report
CREATE VIEW reports.vw_state_coverage AS
SELECT
    c.code as country_code,
    c.name as country_name,
    s.code as state_code,
    s.name as state_name,
    s.state_type,
    s.tax_rate,
    COUNT(DISTINCT ci.city_id) as city_count,
    s.is_active
FROM localization.states s
JOIN localization.countries c ON c.country_id = s.country_id
LEFT JOIN localization.cities ci ON ci.state_id = s.state_id
ORDER BY c.name, s.name;

-- View 12: Currency Usage Report
CREATE VIEW reports.vw_currency_usage AS
SELECT
    cur.code as currency_code,
    cur.name as currency_name,
    cur.symbol,
    cur.decimal_places,
    cur.is_crypto,
    cur.is_default,
    cur.is_active,
    COUNT(DISTINCT c.country_id) as countries_using,
    COUNT(DISTINCT rp.regional_profile_id) as regional_profiles_using
FROM localization.currencies cur
LEFT JOIN localization.countries c ON c.currency_id = cur.currency_id
LEFT JOIN localization.regional_profiles rp ON rp.currency_id = cur.currency_id
GROUP BY cur.currency_id, cur.code, cur.name, cur.symbol, cur.decimal_places, cur.is_crypto, cur.is_default, cur.is_active
ORDER BY countries_using DESC NULLS LAST;

-- View 13: Exchange Rate History Report
CREATE VIEW reports.vw_exchange_rate_history AS
SELECT
    DATE(er.effective_from) as rate_date,
    fc.code as from_currency,
    tc.code as to_currency,
    er.rate,
    er.source,
    er.is_manual
FROM localization.exchange_rates er
JOIN localization.currencies fc ON fc.currency_id = er.from_currency_id
JOIN localization.currencies tc ON tc.currency_id = er.to_currency_id
ORDER BY er.effective_from DESC;

-- View 14: Multi-Language Site Coverage
CREATE VIEW reports.vw_multilingual_site_coverage AS
SELECT
    s.site_name,
    l.code as language_code,
    l.name as language_name,
    COUNT(DISTINCT lu.localized_url_id) as localized_pages,
    COUNT(DISTINCT t.translation_id) as translations_count
FROM cms.sites s
CROSS JOIN localization.languages l
LEFT JOIN localization.localized_urls lu ON lu.language_id = l.language_id
LEFT JOIN localization.translations t ON t.language_id = l.language_id
WHERE l.is_active = TRUE
GROUP BY s.site_id, s.site_name, l.language_id, l.code, l.name
ORDER BY s.site_name, l.code;

-- View 15: RTL Language Support Report
CREATE VIEW reports.vw_rtl_language_support AS
SELECT
    l.code as language_code,
    l.name as language_name,
    l.native_name,
    l.is_rtl,
    COUNT(DISTINCT t.translation_id) as translation_count,
    COUNT(DISTINCT lu.localized_url_id) as localized_url_count,
    l.is_active
FROM localization.languages l
LEFT JOIN localization.translations t ON t.language_id = l.language_id
LEFT JOIN localization.localized_urls lu ON lu.language_id = l.language_id
WHERE l.is_rtl = TRUE
GROUP BY l.language_id, l.code, l.name, l.native_name, l.is_rtl, l.is_active
ORDER BY translation_count DESC NULLS LAST;

-- View 16: Regional Tax Configuration Report
CREATE VIEW reports.vw_regional_tax_configuration AS
SELECT
    rp.profile_code,
    rp.profile_name,
    c.code as country_code,
    c.name as country_name,
    rp.tax_rate,
    rp.tax_inclusive,
    s.code as state_code,
    s.name as state_name,
    s.tax_rate as state_tax_rate
FROM localization.regional_profiles rp
LEFT JOIN localization.countries c ON c.country_id = rp.country_id
LEFT JOIN localization.states s ON s.country_id = rp.country_id
ORDER BY rp.profile_code, s.name;

-- View 17: Unit Conversion Matrix Report
CREATE VIEW reports.vw_unit_conversion_matrix AS
SELECT
    ut.code as unit_type,
    from_mu.code as from_unit,
    from_mu.name as from_unit_name,
    to_mu.code as to_unit,
    to_mu.name as to_unit_name,
    from_mu.conversion_factor / to_mu.conversion_factor as conversion_factor,
    1.0 / (from_mu.conversion_factor / to_mu.conversion_factor) as inverse_conversion_factor
FROM localization.measurement_units from_mu
JOIN localization.measurement_units to_mu ON to_mu.unit_type_id = from_mu.unit_type_id AND to_mu.measurement_unit_id <> from_mu.measurement_unit_id
JOIN localization.unit_type_lookup ut ON ut.unit_type_id = from_mu.unit_type_id
ORDER BY ut.sort_order, from_mu.code, to_mu.code;

-- View 18: Localization Health Report
CREATE VIEW reports.vw_localization_health AS
SELECT
    'Languages' as category,
    COUNT(DISTINCT l.language_id) as total_count,
    COUNT(DISTINCT CASE WHEN l.is_active = TRUE THEN l.language_id END) as active_count,
    COUNT(DISTINCT CASE WHEN l.is_rtl = TRUE THEN l.language_id END) as rtl_count
FROM localization.languages l
UNION ALL
SELECT
    'Countries' as category,
    COUNT(DISTINCT c.country_id),
    COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.country_id END),
    0
FROM localization.countries c
UNION ALL
SELECT
    'Currencies' as category,
    COUNT(DISTINCT cur.currency_id),
    COUNT(DISTINCT CASE WHEN cur.is_active = TRUE THEN cur.currency_id END),
    0
FROM localization.currencies cur
UNION ALL
SELECT
    'Timezones' as category,
    COUNT(DISTINCT tz.timezone_id),
    COUNT(DISTINCT CASE WHEN tz.is_active = TRUE THEN tz.timezone_id END),
    0
FROM localization.timezones tz
UNION ALL
SELECT
    'Translations' as category,
    COUNT(DISTINCT t.translation_id),
    COUNT(DISTINCT CASE WHEN t.is_approved = TRUE THEN t.translation_id END),
    0
FROM localization.translations t
UNION ALL
SELECT
    'Measurement Units' as category,
    COUNT(DISTINCT mu.measurement_unit_id),
    COUNT(DISTINCT CASE WHEN mu.is_active = TRUE THEN mu.measurement_unit_id END),
    0
FROM localization.measurement_units mu;

-- View 19: Exchange Rate Validity Report
CREATE VIEW reports.vw_exchange_rate_validity AS
SELECT
    fc.code as from_currency,
    tc.code as to_currency,
    er.rate,
    er.effective_from,
    er.effective_to,
    CASE
        WHEN er.effective_to IS NULL THEN 'OPEN_ENDED'
        WHEN er.effective_to > CURRENT_TIMESTAMP THEN 'CURRENT'
        ELSE 'EXPIRED'
    END as validity_status,
    er.effective_to - CURRENT_TIMESTAMP as days_until_expiry
FROM localization.exchange_rates er
JOIN localization.currencies fc ON fc.currency_id = er.from_currency_id
JOIN localization.currencies tc ON tc.currency_id = er.to_currency_id
ORDER BY er.effective_from DESC;

-- View 20: Localization Coverage Summary
CREATE VIEW reports.vw_localization_coverage_summary AS
SELECT
    et.code as entity_type,
    et.name as entity_type_name,
    COUNT(DISTINCT t.language_id) as languages_covered,
    COUNT(DISTINCT t.entity_id) as entities_translated,
    COUNT(DISTINCT t.field_name) as fields_translated,
    COUNT(DISTINCT CASE WHEN t.is_approved = TRUE THEN t.translation_id END) as approved_translations,
    ROUND((COUNT(DISTINCT CASE WHEN t.is_approved = TRUE THEN t.translation_id END)::numeric /
           NULLIF(COUNT(DISTINCT t.translation_id), 0) * 100), 2) as approval_rate_percent
FROM localization.translatable_entity_type_lookup et
LEFT JOIN localization.translations t ON t.translatable_entity_type_id = et.translatable_entity_type_id
GROUP BY et.translatable_entity_type_id, et.code, et.name, et.sort_order
ORDER BY et.sort_order;

-- Function 1: Get Translation Coverage by Language
CREATE OR REPLACE FUNCTION reports.get_translation_coverage(
    p_language_code VARCHAR
)
RETURNS TABLE (
    entity_type VARCHAR,
    entity_type_name VARCHAR,
    translated_entities BIGINT,
    translated_fields BIGINT,
    approved_translations BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        et.code::VARCHAR,
        et.name::VARCHAR,
        COUNT(DISTINCT t.entity_id)::BIGINT,
        COUNT(DISTINCT t.field_name)::BIGINT,
        COUNT(DISTINCT CASE WHEN t.is_approved = TRUE THEN t.translation_id END)::BIGINT
    FROM localization.translatable_entity_type_lookup et
    LEFT JOIN localization.translations t ON t.translatable_entity_type_id = et.translatable_entity_type_id
    LEFT JOIN localization.languages l ON l.language_id = t.language_id AND l.code = p_language_code
    GROUP BY et.translatable_entity_type_id, et.code, et.name, et.sort_order
    ORDER BY et.sort_order;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Regional Settings for Company
CREATE OR REPLACE FUNCTION reports.get_regional_settings_summary(
    p_company_id UUID
)
RETURNS TABLE (
    profile_code VARCHAR,
    profile_name VARCHAR,
    country_name VARCHAR,
    language_name VARCHAR,
    currency_code VARCHAR,
    timezone_name VARCHAR,
    tax_rate NUMERIC,
    is_default BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rp.profile_code::VARCHAR,
        rp.profile_name::VARCHAR,
        c.name::VARCHAR,
        l.name::VARCHAR,
        cur.code::VARCHAR,
        tz.name::VARCHAR,
        rp.tax_rate,
        rp.is_default
    FROM localization.regional_profiles rp
    LEFT JOIN localization.countries c ON c.country_id = rp.country_id
    LEFT JOIN localization.languages l ON l.language_id = rp.language_id
    LEFT JOIN localization.currencies cur ON cur.currency_id = rp.currency_id
    LEFT JOIN localization.timezones tz ON tz.timezone_id = rp.timezone_id
    WHERE rp.company_id = p_company_id
      AND rp.is_active = TRUE
    ORDER BY rp.is_default DESC, rp.profile_code;
END;
$$ LANGUAGE plpgsql;

COMMIT;