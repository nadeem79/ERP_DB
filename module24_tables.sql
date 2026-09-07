BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 24 — SEARCH & DISCOVERY
-- DATABASE TABLES
-- ============================================================
-- Architecture Principles:
--   1. PostgreSQL remains source of truth — search index is disposable
--   2. Never trust search for checkout — checkout validates against
--      Module 6 (Inventory)
--   3. Don't couple transactions to search — Event → Queue → Indexer
--   4. Dynamic attributes remain dynamic — use Product Attribute model
--   5. Public and admin search are different security domains
--   6. Start simple: PostgreSQL + FTS + pg_trgm + ISearchService
--      abstraction; introduce OpenSearch when scale justifies
-- ============================================================
-- Components:
--   24.1  Search Entities & Entity Types
--   24.2  Search Index (PostgreSQL FTS)
--   24.3  Search Query Logs
--   24.4  Search Synonyms
--   24.5  Search Query Rules (Merchandising)
--   24.6  Search Merchandising (Boost, Pin, Hide, Redirect)
--   24.7  Zero-Result Searches
--   24.8  Search Analytics
--   24.9  Popular Searches
--   24.10 Search Index Jobs
--   24.11 Search Performance
--   24.12 Search Facet Configuration
-- ============================================================

CREATE SCHEMA IF NOT EXISTS search;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- 24.0 SEARCH LOOKUPS
-- ============================================================

-- Search Entity Type
CREATE TABLE IF NOT EXISTS search.search_entity_type_lookup (
    search_entity_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_searchable_public BOOLEAN NOT NULL DEFAULT TRUE,
    is_searchable_admin BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO search.search_entity_type_lookup (code, name, description, is_searchable_public, is_searchable_admin, sort_order) VALUES
    ('PRODUCT', 'Product', 'Product search.', TRUE, TRUE, 10),
    ('CATEGORY', 'Category', 'Product category search.', TRUE, TRUE, 20),
    ('BRAND', 'Brand', 'Brand search.', TRUE, TRUE, 30),
    ('BLOG_POST', 'Blog Post', 'Blog post search.', TRUE, TRUE, 40),
    ('CMS_PAGE', 'CMS Page', 'CMS page search.', TRUE, FALSE, 50),
    ('COLLECTION', 'Collection', 'Product collection search.', TRUE, TRUE, 60),
    ('CUSTOMER', 'Customer', 'Customer search (admin only).', FALSE, TRUE, 70),
    ('ORDER', 'Order', 'Order search (admin only).', FALSE, TRUE, 80),
    ('SUPPLIER', 'Supplier', 'Supplier search (admin only).', FALSE, TRUE, 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Search Query Rule Type
CREATE TABLE IF NOT EXISTS search.search_query_rule_type_lookup (
    search_query_rule_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO search.search_query_rule_type_lookup (code, name, description, sort_order) VALUES
    ('REDIRECT', 'Redirect', 'Redirect search query to specific URL.', 10),
    ('BOOST', 'Boost', 'Boost specific results in search.', 20),
    ('PIN', 'Pin', 'Pin specific results at top of search.', 30),
    ('HIDE', 'Hide', 'Hide specific results from search.', 40),
    ('SYNONYM', 'Synonym', 'Add synonym for search query.', 50),
    ('CUSTOM_RESULT', 'Custom Result', 'Show custom result for query.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Search Query Status
CREATE TABLE IF NOT EXISTS search.search_query_status_lookup (
    search_query_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO search.search_query_status_lookup (code, name, description, sort_order) VALUES
    ('SUCCESS', 'Success', 'Search returned results.', 10),
    ('ZERO_RESULTS', 'Zero Results', 'Search returned no results.', 20),
    ('ERROR', 'Error', 'Search encountered an error.', 30),
    ('REDIRECTED', 'Redirected', 'Search was redirected by rule.', 40),
    ('TIMEOUT', 'Timeout', 'Search timed out.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Search Index Job Status
CREATE TABLE IF NOT EXISTS search.search_index_job_status_lookup (
    search_index_job_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO search.search_index_job_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Job is pending.', 10),
    ('IN_PROGRESS', 'In Progress', 'Job is running.', 20),
    ('COMPLETED', 'Completed', 'Job completed successfully.', 30),
    ('COMPLETED_WITH_ERRORS', 'Completed With Errors', 'Job completed but had errors.', 40),
    ('FAILED', 'Failed', 'Job failed.', 50),
    ('CANCELLED', 'Cancelled', 'Job was cancelled.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Search Index Job Type
CREATE TABLE IF NOT EXISTS search.search_index_job_type_lookup (
    search_index_job_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO search.search_index_job_type_lookup (code, name, description, sort_order) VALUES
    ('FULL_REBUILD', 'Full Rebuild', 'Complete search index rebuild.', 10),
    ('INCREMENTAL', 'Incremental Update', 'Incremental index update.', 20),
    ('ENTITY_REINDEX', 'Entity Reindex', 'Reindex specific entity.', 30),
    ('ENTITY_REMOVE', 'Entity Remove', 'Remove entity from index.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Search Facet Type
CREATE TABLE IF NOT EXISTS search.search_facet_type_lookup (
    search_facet_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO search.search_facet_type_lookup (code, name, description, sort_order) VALUES
    ('CATEGORY', 'Category', 'Filter by product category.', 10),
    ('BRAND', 'Brand', 'Filter by brand.', 20),
    ('PRICE_RANGE', 'Price Range', 'Filter by price range.', 30),
    ('COLOR', 'Color', 'Filter by color attribute.', 40),
    ('SIZE', 'Size', 'Filter by size attribute.', 50),
    ('MATERIAL', 'Material', 'Filter by material attribute.', 60),
    ('RATING', 'Rating', 'Filter by product rating.', 70),
    ('AVAILABILITY', 'Availability', 'Filter by stock availability.', 80),
    ('CUSTOM_ATTRIBUTE', 'Custom Attribute', 'Filter by custom product attribute.', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 24.2 SEARCH INDEX (PostgreSQL FTS)
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_index (
    search_index_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    search_entity_type_id UUID NOT NULL,

    entity_reference_id UUID NOT NULL,
    entity_url VARCHAR(1000) NULL,
    entity_slug VARCHAR(500) NULL,

    title VARCHAR(500) NOT NULL,
    summary TEXT NULL,
    content TEXT NULL,

    search_vector tsvector NULL,
    search_vector_title tsvector NULL,

    metadata JSONB NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    is_searchable BOOLEAN NOT NULL DEFAULT TRUE,

    indexed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_si_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_si_entity_type FOREIGN KEY (search_entity_type_id) REFERENCES search.search_entity_type_lookup(search_entity_type_id),
    CONSTRAINT uq_search_index UNIQUE (company_id, search_entity_type_id, entity_reference_id)
);

CREATE INDEX ix_si_company ON search.search_index(company_id);
CREATE INDEX ix_si_entity_type ON search.search_index(search_entity_type_id);
CREATE INDEX ix_si_entity_ref ON search.search_index(entity_reference_id);
CREATE INDEX ix_si_search_vector ON search.search_index USING GIN(search_vector);
CREATE INDEX ix_si_search_vector_title ON search.search_index USING GIN(search_vector_title);
CREATE INDEX ix_si_title_trgm ON search.search_index USING GIN(title gin_trgm_ops);
CREATE INDEX ix_si_active ON search.search_index(is_active, is_published, is_searchable);

-- ============================================================
-- 24.3 SEARCH QUERY LOGS
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_query_logs (
    search_query_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    search_query_status_id UUID NOT NULL,

    query_text VARCHAR(500) NOT NULL,
    normalized_query VARCHAR(500) NULL,
    query_hash VARCHAR(64) NULL,

    session_id VARCHAR(200) NULL,
    customer_id UUID NULL,
    user_id UUID NULL,

    results_count INTEGER NOT NULL DEFAULT 0,
    response_time_ms INTEGER NULL,

    clicked_entity_type_id UUID NULL,
    clicked_entity_id UUID NULL,
    clicked_position INTEGER NULL,

    applied_filters JSONB NULL,
    applied_sort VARCHAR(100) NULL,
    page_number INTEGER NOT NULL DEFAULT 1,
    page_size INTEGER NOT NULL DEFAULT 20,

    ip_address INET NULL,
    user_agent TEXT NULL,
    referrer_url VARCHAR(1000) NULL,

    utm_source VARCHAR(200) NULL,
    utm_medium VARCHAR(200) NULL,
    utm_campaign VARCHAR(200) NULL,

    is_autocomplete BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin_search BOOLEAN NOT NULL DEFAULT FALSE,

    searched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sql_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sql_status FOREIGN KEY (search_query_status_id) REFERENCES search.search_query_status_lookup(search_query_status_id),
    CONSTRAINT fk_sql_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_sql_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id)
);

CREATE INDEX ix_sql_company ON search.search_query_logs(company_id);
CREATE INDEX ix_sql_query ON search.search_query_logs(query_text);
CREATE INDEX ix_sql_query_hash ON search.search_query_logs(query_hash);
CREATE INDEX ix_sql_searched ON search.search_query_logs(searched_at DESC);
CREATE INDEX ix_sql_customer ON search.search_query_logs(customer_id);
CREATE INDEX ix_sql_status ON search.search_query_logs(search_query_status_id);
CREATE INDEX ix_sql_session ON search.search_query_logs(session_id);

-- ============================================================
-- 24.4 SEARCH SYNONYMS
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_synonyms (
    search_synonym_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    term VARCHAR(200) NOT NULL,
    synonym VARCHAR(200) NOT NULL,
    is_bidirectional BOOLEAN NOT NULL DEFAULT TRUE,

    usage_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ss_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_synonym UNIQUE (company_id, term, synonym)
);

CREATE INDEX ix_ss_company ON search.search_synonyms(company_id);
CREATE INDEX ix_ss_term ON search.search_synonyms(term);
CREATE INDEX ix_ss_synonym ON search.search_synonyms(synonym);

-- ============================================================
-- 24.5 SEARCH QUERY RULES (Merchandising)
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_query_rules (
    search_query_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    search_query_rule_type_id UUID NOT NULL,

    query_pattern VARCHAR(500) NOT NULL,
    is_exact_match BOOLEAN NOT NULL DEFAULT FALSE,
    is_case_sensitive BOOLEAN NOT NULL DEFAULT FALSE,

    target_entity_type_id UUID NULL,
    target_entity_id UUID NULL,
    redirect_url VARCHAR(1000) NULL,

    boost_weight NUMERIC(5,2) NULL,
    pin_position INTEGER NULL,

    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    start_date DATE NULL,
    end_date NULL NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_sqr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sqr_type FOREIGN KEY (search_query_rule_type_id) REFERENCES search.search_query_rule_type_lookup(search_query_rule_type_id),
    CONSTRAINT fk_sqr_entity_type FOREIGN KEY (target_entity_type_id) REFERENCES search.search_entity_type_lookup(search_entity_type_id),
    CONSTRAINT ck_sqr_boost CHECK (boost_weight IS NULL OR boost_weight > 0),
    CONSTRAINT ck_sqr_pin CHECK (pin_position IS NULL OR pin_position > 0)
);

CREATE INDEX ix_sqr_company ON search.search_query_rules(company_id);
CREATE INDEX ix_sqr_type ON search.search_query_rules(search_query_rule_type_id);
CREATE INDEX ix_sqr_pattern ON search.search_query_rules(query_pattern);
CREATE INDEX ix_sqr_active ON search.search_query_rules(is_active, priority DESC);

-- ============================================================
-- 24.7 ZERO-RESULT SEARCHES
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_zero_results (
    search_zero_result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    query_text VARCHAR(500) NOT NULL,
    normalized_query VARCHAR(500) NULL,

    search_count INTEGER NOT NULL DEFAULT 1,
    first_searched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_searched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    resolution_status VARCHAR(30) NOT NULL DEFAULT 'UNRESOLVED',
    resolution_action VARCHAR(30) NULL,
    resolution_notes TEXT NULL,
    resolved_by_user_id UUID NULL,
    resolved_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_szr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_szr_status CHECK (resolution_status IN ('UNRESOLVED', 'IN_PROGRESS', 'RESOLVED', 'IGNORED')),
    CONSTRAINT ck_szr_action CHECK (resolution_action IS NULL OR resolution_action IN (
        'CREATE_PRODUCT', 'CREATE_SYNONYM', 'CREATE_REDIRECT', 'CREATE_LANDING_PAGE',
        'IMPROVE_CATALOG', 'ADD_TO_EXISTING', 'OTHER'
    ))
);

CREATE INDEX ix_szr_company ON search.search_zero_results(company_id);
CREATE INDEX ix_szr_query ON search.search_zero_results(query_text);
CREATE INDEX ix_szr_status ON search.search_zero_results(resolution_status);
CREATE INDEX ix_szr_count ON search.search_zero_results(search_count DESC);

-- ============================================================
-- 24.8 SEARCH ANALYTICS
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_analytics (
    search_analytics_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    search_entity_type_id UUID NULL,

    stat_date DATE NOT NULL,

    total_searches INTEGER NOT NULL DEFAULT 0,
    unique_searches INTEGER NOT NULL DEFAULT 0,
    zero_result_searches INTEGER NOT NULL DEFAULT 0,
    error_searches INTEGER NOT NULL DEFAULT 0,

    total_clicks INTEGER NOT NULL DEFAULT 0,
    total_conversions INTEGER NOT NULL DEFAULT 0,
    conversion_revenue NUMERIC(19,4) NOT NULL DEFAULT 0,

    avg_response_time_ms INTEGER NULL,
    avg_results_count NUMERIC(7,2) NULL,

    autocomplete_searches INTEGER NOT NULL DEFAULT 0,
    admin_searches INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sa_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sa_entity_type FOREIGN KEY (search_entity_type_id) REFERENCES search.search_entity_type_lookup(search_entity_type_id),
    CONSTRAINT uq_search_analytics UNIQUE (company_id, search_entity_type_id, stat_date)
);

CREATE INDEX ix_sa_company ON search.search_analytics(company_id);
CREATE INDEX ix_sa_date ON search.search_analytics(stat_date DESC);

-- ============================================================
-- 24.9 POPULAR SEARCHES
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_popular_queries (
    search_popular_query_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    query_text VARCHAR(500) NOT NULL,
    normalized_query VARCHAR(500) NULL,

    search_count INTEGER NOT NULL DEFAULT 0,
    click_count INTEGER NOT NULL DEFAULT 0,
    conversion_count INTEGER NOT NULL DEFAULT 0,
    zero_result_count INTEGER NOT NULL DEFAULT 0,

    avg_response_time_ms INTEGER NULL,
    avg_results_count NUMERIC(7,2) NULL,

    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_spq_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_popular_query UNIQUE (company_id, normalized_query, period_start, period_end)
);

CREATE INDEX ix_spq_company ON search.search_popular_queries(company_id);
CREATE INDEX ix_spq_count ON search.search_popular_queries(search_count DESC);
CREATE INDEX ix_spq_period ON search.search_popular_queries(period_start, period_end);

-- ============================================================
-- 24.10 SEARCH INDEX JOBS
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_index_jobs (
    search_index_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    search_index_job_type_id UUID NOT NULL,
    search_index_job_status_id UUID NOT NULL DEFAULT (SELECT search_index_job_status_id FROM search.search_index_job_status_lookup WHERE code = 'PENDING'),

    job_name VARCHAR(300) NOT NULL,
    entity_type_id UUID NULL,
    entity_reference_id UUID NULL,

    total_entities INTEGER NOT NULL DEFAULT 0,
    processed_entities INTEGER NOT NULL DEFAULT 0,
    successful_entities INTEGER NOT NULL DEFAULT 0,
    failed_entities INTEGER NOT NULL DEFAULT 0,

    error_message TEXT NULL,
    error_details JSONB NULL,

    started_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,

    triggered_by_user_id UUID NULL,
    is_scheduled BOOLEAN NOT NULL DEFAULT FALSE,
    scheduled_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sij_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sij_type FOREIGN KEY (search_index_job_type_id) REFERENCES search.search_index_job_type_lookup(search_index_job_type_id),
    CONSTRAINT fk_sij_status FOREIGN KEY (search_index_job_status_id) REFERENCES search.search_index_job_status_lookup(search_index_job_status_id),
    CONSTRAINT fk_sij_entity_type FOREIGN KEY (entity_type_id) REFERENCES search.search_entity_type_lookup(search_entity_type_id)
);

CREATE INDEX ix_sij_company ON search.search_index_jobs(company_id);
CREATE INDEX ix_sij_status ON search.search_index_jobs(search_index_job_status_id);
CREATE INDEX ix_sij_type ON search.search_index_jobs(search_index_job_type_id);

-- ============================================================
-- 24.12 SEARCH FACET CONFIGURATION
-- ============================================================

CREATE TABLE IF NOT EXISTS search.search_facet_configuration (
    search_facet_configuration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    search_entity_type_id UUID NOT NULL,
    search_facet_type_id UUID NOT NULL,

    facet_code VARCHAR(100) NOT NULL,
    facet_name VARCHAR(200) NOT NULL,
    facet_field VARCHAR(200) NOT NULL,

    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_multi_select BOOLEAN NOT NULL DEFAULT TRUE,
    max_values INTEGER NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,

    configuration_json JSONB NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_sfc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sfc_entity_type FOREIGN KEY (search_entity_type_id) REFERENCES search.search_entity_type_lookup(search_entity_type_id),
    CONSTRAINT fk_sfc_facet_type FOREIGN KEY (search_facet_type_id) REFERENCES search.search_facet_type_lookup(search_facet_type_id),
    CONSTRAINT uq_facet_config UNIQUE (company_id, search_entity_type_id, facet_code)
);

CREATE INDEX ix_sfc_company ON search.search_facet_configuration(company_id);
CREATE INDEX ix_sfc_entity_type ON search.search_facet_configuration(search_entity_type_id);

-- ============================================================
-- SEARCH HELPER FUNCTIONS
-- ============================================================

-- Function to update search vector on insert/update
CREATE OR REPLACE FUNCTION search.update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.summary, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.content, '')), 'C');

    NEW.search_vector_title :=
        to_tsvector('english', COALESCE(NEW.title, ''));

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for search index
DROP TRIGGER IF EXISTS trg_search_index_vector ON search.search_index;
CREATE TRIGGER trg_search_index_vector
    BEFORE INSERT OR UPDATE OF title, summary, content
    ON search.search_index
    FOR EACH ROW
    EXECUTE FUNCTION search.update_search_vector();

-- Function: Search Products
CREATE OR REPLACE FUNCTION search.search_products(
    p_company_id UUID,
    p_query TEXT,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    entity_reference_id UUID,
    title VARCHAR,
    summary TEXT,
    entity_url VARCHAR,
    relevance REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        si.entity_reference_id,
        si.title::VARCHAR,
        si.summary,
        si.entity_url::VARCHAR,
        ts_rank(si.search_vector, plainto_tsquery('english', p_query))::REAL as relevance
    FROM search.search_index si
    JOIN search.search_entity_type_lookup set ON set.search_entity_type_id = si.search_entity_type_id
    WHERE si.company_id = p_company_id
      AND set.code = 'PRODUCT'
      AND si.is_active = TRUE
      AND si.is_published = TRUE
      AND si.is_searchable = TRUE
      AND si.search_vector @@ plainto_tsquery('english', p_query)
    ORDER BY relevance DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function: Autocomplete Suggestions
CREATE OR REPLACE FUNCTION search.autocomplete_suggestions(
    p_company_id UUID,
    p_prefix TEXT,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    suggestion VARCHAR,
    entity_type VARCHAR,
    relevance REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        si.title::VARCHAR as suggestion,
        set.code::VARCHAR as entity_type,
        similarity(si.title, p_prefix)::REAL as relevance
    FROM search.search_index si
    JOIN search.search_entity_type_lookup set ON set.search_entity_type_id = si.search_entity_type_id
    WHERE si.company_id = p_company_id
      AND si.is_active = TRUE
      AND si.is_published = TRUE
      AND si.is_searchable = TRUE
      AND si.title % p_prefix
    ORDER BY relevance DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Log Search Query
CREATE OR REPLACE FUNCTION search.log_search_query(
    p_company_id UUID,
    p_query_text VARCHAR,
    p_results_count INTEGER,
    p_response_time_ms INTEGER,
    p_session_id VARCHAR DEFAULT NULL,
    p_customer_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_is_autocomplete BOOLEAN DEFAULT FALSE,
    p_is_admin_search BOOLEAN DEFAULT FALSE
)
RETURNS UUID AS $$
DECLARE
    v_query_log_id UUID;
    v_status_id UUID;
BEGIN
    -- Determine status
    IF p_results_count > 0 THEN
        SELECT search_query_status_id INTO v_status_id
        FROM search.search_query_status_lookup WHERE code = 'SUCCESS';
    ELSE
        SELECT search_query_status_id INTO v_status_id
        FROM search.search_query_status_lookup WHERE code = 'ZERO_RESULTS';

        -- Update zero results tracking
        INSERT INTO search.search_zero_results (company_id, query_text, normalized_query, search_count, first_searched_at, last_searched_at)
        VALUES (p_company_id, p_query_text, LOWER(TRIM(p_query_text)), 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (company_id, query_text)
        DO UPDATE SET
            search_count = search.search_zero_results.search_count + 1,
            last_searched_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP;
    END IF;

    INSERT INTO search.search_query_logs (
        company_id, search_query_status_id, query_text, normalized_query,
        query_hash, session_id, customer_id, user_id, results_count,
        response_time_ms, is_autocomplete, is_admin_search
    )
    VALUES (
        p_company_id, v_status_id, p_query_text, LOWER(TRIM(p_query_text)),
        MD5(LOWER(TRIM(p_query_text))), p_session_id, p_customer_id, p_user_id,
        p_results_count, p_response_time_ms, p_is_autocomplete, p_is_admin_search
    )
    RETURNING search_query_log_id INTO v_query_log_id;

    RETURN v_query_log_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_product_entity_type UUID;
    v_category_entity_type UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT search_entity_type_id INTO v_product_entity_type FROM search.search_entity_type_lookup WHERE code = 'PRODUCT';
    SELECT search_entity_type_id INTO v_category_entity_type FROM search.search_entity_type_lookup WHERE code = 'CATEGORY';

    -- Create default synonyms
    INSERT INTO search.search_synonyms (company_id, term, synonym, is_bidirectional)
    SELECT v_company_id, 'wallet', 'purse', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM search.search_synonyms WHERE company_id = v_company_id AND term = 'wallet' AND synonym = 'purse');

    INSERT INTO search.search_synonyms (company_id, term, synonym, is_bidirectional)
    SELECT v_company_id, 'laptop', 'notebook', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM search.search_synonyms WHERE company_id = v_company_id AND term = 'laptop' AND synonym = 'notebook');

    INSERT INTO search.search_synonyms (company_id, term, synonym, is_bidirectional)
    SELECT v_company_id, 'phone', 'mobile', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM search.search_synonyms WHERE company_id = v_company_id AND term = 'phone' AND synonym = 'mobile');

    INSERT INTO search.search_synonyms (company_id, term, synonym, is_bidirectional)
    SELECT v_company_id, 'shoes', 'footwear', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM search.search_synonyms WHERE company_id = v_company_id AND term = 'shoes' AND synonym = 'footwear');

    -- Create default facet configurations for products
    INSERT INTO search.search_facet_configuration (company_id, search_entity_type_id, search_facet_type_id, facet_code, facet_name, facet_field, sort_order)
    SELECT v_company_id, v_product_entity_type,
           (SELECT search_facet_type_id FROM search.search_facet_type_lookup WHERE code = 'CATEGORY'),
           'category', 'Category', 'category_id', 10
    WHERE NOT EXISTS (SELECT 1 FROM search.search_facet_configuration WHERE company_id = v_company_id AND facet_code = 'category' AND search_entity_type_id = v_product_entity_type);

    INSERT INTO search.search_facet_configuration (company_id, search_entity_type_id, search_facet_type_id, facet_code, facet_name, facet_field, sort_order)
    SELECT v_company_id, v_product_entity_type,
           (SELECT search_facet_type_id FROM search.search_facet_type_lookup WHERE code = 'BRAND'),
           'brand', 'Brand', 'brand_id', 20
    WHERE NOT EXISTS (SELECT 1 FROM search.search_facet_configuration WHERE company_id = v_company_id AND facet_code = 'brand' AND search_entity_type_id = v_product_entity_type);

    INSERT INTO search.search_facet_configuration (company_id, search_entity_type_id, search_facet_type_id, facet_code, facet_name, facet_field, sort_order)
    SELECT v_company_id, v_product_entity_type,
           (SELECT search_facet_type_id FROM search.search_facet_type_lookup WHERE code = 'PRICE_RANGE'),
           'price_range', 'Price Range', 'price', 30
    WHERE NOT EXISTS (SELECT 1 FROM search.search_facet_configuration WHERE company_id = v_company_id AND facet_code = 'price_range' AND search_entity_type_id = v_product_entity_type);

    INSERT INTO search.search_facet_configuration (company_id, search_entity_type_id, search_facet_type_id, facet_code, facet_name, facet_field, sort_order)
    SELECT v_company_id, v_product_entity_type,
           (SELECT search_facet_type_id FROM search.search_facet_type_lookup WHERE code = 'AVAILABILITY'),
           'availability', 'Availability', 'is_in_stock', 40
    WHERE NOT EXISTS (SELECT 1 FROM search.search_facet_configuration WHERE company_id = v_company_id AND facet_code = 'availability' AND search_entity_type_id = v_product_entity_type);

    -- Index existing products
    INSERT INTO search.search_index (company_id, search_entity_type_id, entity_reference_id, entity_url, entity_slug, title, summary, is_active, is_published, is_searchable)
    SELECT v_company_id, v_product_entity_type, p.product_id,
           '/products/' || p.slug, p.slug,
           p.product_name, p.short_description,
           p.is_active, TRUE, TRUE
    FROM catalog.products p
    WHERE NOT EXISTS (
        SELECT 1 FROM search.search_index si
        WHERE si.company_id = v_company_id
          AND si.search_entity_type_id = v_product_entity_type
          AND si.entity_reference_id = p.product_id
    );

    -- Index existing categories
    INSERT INTO search.search_index (company_id, search_entity_type_id, entity_reference_id, entity_url, entity_slug, title, summary, is_active, is_published, is_searchable)
    SELECT v_company_id, v_category_entity_type, c.category_id,
           '/categories/' || c.slug, c.slug,
           c.category_name, c.description,
           c.is_active, TRUE, TRUE
    FROM catalog.categories c
    WHERE NOT EXISTS (
        SELECT 1 FROM search.search_index si
        WHERE si.company_id = v_company_id
          AND si.search_entity_type_id = v_category_entity_type
          AND si.entity_reference_id = c.category_id
    );

END $$;

COMMIT;