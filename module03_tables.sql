BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 03: CRM / CUSTOMER RELATIONSHIP MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   The CRM module manages the complete customer lifecycle:
--   Lead → Customer → Profile → Communication → Sales Relationship
--   → Service → Scoring → Retention / Loyalty → Customer 360
-- ============================================================
-- Components:
--   03A  Customer Foundation
--   03B  Customer Addresses
--   03C  Customer Contacts
--   03D  Customer Segments/Groups
--   03E  Customer Documents
--   03F  Customer Notes
--   03G  Customer Tags
--   03H  Customer Account Summary
--   03I  Customer Interactions
--   03J  Customer Service Cases
--   03K  Customer Tasks
--   03L  Customer Scoring
--   03M  Customer Preferences
--   03N  Customer Acquisition
--   03O  Customer Relationships
--   03P  Customer Commercial Profiles
--   03Q  Customer Credit
--   03R  Customer Referrals
--   03S  Customer Groups/Memberships
--   03T  Customer Account Summary (Aggregated)
--   03U  Customer Analytics
--   03V  Customer 360 / Read Models
-- ============================================================

CREATE SCHEMA IF NOT EXISTS crm;

-- ============================================================
-- 03A: CUSTOMER TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_type_lookup (
    customer_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_type_lookup (code, name, description, sort_order) VALUES
    ('INDIVIDUAL', 'Individual', 'Individual customer.', 10),
    ('BUSINESS', 'Business', 'Business/Corporate customer.', 20),
    ('GOVERNMENT', 'Government', 'Government entity.', 30),
    ('NON_PROFIT', 'Non-Profit', 'Non-profit organization.', 40),
    ('WHOLESALE', 'Wholesale', 'Wholesale buyer.', 50),
    ('RETAIL', 'Retail', 'Retail customer.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 03A: CUSTOMER STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_status_lookup (
    customer_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_status_lookup (code, name, description, sort_order) VALUES
    ('LEAD', 'Lead', 'Potential customer.', 10),
    ('PROSPECT', 'Prospect', 'Qualified prospect.', 20),
    ('ACTIVE', 'Active', 'Active customer.', 30),
    ('INACTIVE', 'Inactive', 'Inactive customer.', 40),
    ('SUSPENDED', 'Suspended', 'Suspended customer.', 50),
    ('BLACKLISTED', 'Blacklisted', 'Blacklisted customer.', 60),
    ('ARCHIVED', 'Archived', 'Archived customer.', 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 03A: CUSTOMERS (Master Records)
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_type_id UUID NOT NULL,
    customer_status_id UUID NOT NULL DEFAULT (SELECT customer_status_id FROM crm.customer_status_lookup WHERE code = 'LEAD'),
    person_id UUID NULL,

    customer_number VARCHAR(50) NOT NULL,
    display_name VARCHAR(200) NOT NULL,
    first_name VARCHAR(100) NULL,
    middle_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    business_name VARCHAR(300) NULL,
    legal_name VARCHAR(300) NULL,
    registration_number VARCHAR(100) NULL,
    tax_number VARCHAR(100) NULL,
    website_url VARCHAR(500) NULL,

    email VARCHAR(300) NULL,
    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,

    credit_limit NUMERIC(19,4) NULL,
    payment_terms_days INTEGER NULL,

    accepts_marketing BOOLEAN NOT NULL DEFAULT FALSE,
    accepts_sms BOOLEAN NOT NULL DEFAULT FALSE,
    accepts_email BOOLEAN NOT NULL DEFAULT FALSE,
    accepts_phone BOOLEAN NOT NULL DEFAULT FALSE,

    is_vip BOOLEAN NOT NULL DEFAULT FALSE,
    is_tax_exempt BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    notes TEXT NULL,

    first_acquisition_source_id UUID NULL,
    last_acquisition_source_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cust_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cust_type FOREIGN KEY (customer_type_id) REFERENCES crm.customer_type_lookup(customer_type_id),
    CONSTRAINT fk_cust_status FOREIGN KEY (customer_status_id) REFERENCES crm.customer_status_lookup(customer_status_id),
    CONSTRAINT fk_cust_person FOREIGN KEY (person_id) REFERENCES identity.persons(person_id),
    CONSTRAINT uq_customer_number UNIQUE (company_id, customer_number)
);

CREATE INDEX ix_cust_company ON crm.customers(company_id);
CREATE INDEX ix_cust_type ON crm.customers(customer_type_id);
CREATE INDEX ix_cust_status ON crm.customers(customer_status_id);
CREATE INDEX ix_cust_active ON crm.customers(is_active);
CREATE INDEX ix_cust_email ON crm.customers(email);
CREATE INDEX ix_cust_created ON crm.customers(created_at);

-- ============================================================
-- 03B: CUSTOMER ADDRESSES
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_addresses (
    customer_address_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,

    address_type VARCHAR(30) NOT NULL DEFAULT 'SHIPPING',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    contact_name VARCHAR(200) NULL,
    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state_id UUID NULL,
    country_id UUID NULL,
    postal_code VARCHAR(20) NULL,

    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,

    latitude NUMERIC(10,7) NULL,
    longitude NUMERIC(10,7) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ca_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_ca_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ca_state FOREIGN KEY (state_id) REFERENCES reference.state_lookup(state_id),
    CONSTRAINT fk_ca_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT ck_ca_type CHECK (address_type IN ('SHIPPING', 'BILLING', 'BOTH', 'OTHER'))
);

CREATE INDEX ix_ca_customer ON crm.customer_addresses(customer_id);
CREATE INDEX ix_ca_type ON crm.customer_addresses(address_type);

-- ============================================================
-- 03C: CUSTOMER CONTACTS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_contacts (
    customer_contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,

    contact_type VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,

    contact_name VARCHAR(200) NOT NULL,
    job_title VARCHAR(200) NULL,
    email VARCHAR(300) NULL,
    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cc_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_cc_type CHECK (contact_type IN ('GENERAL', 'OWNER', 'ACCOUNTS', 'PURCHASING', 'BILLING', 'TECHNICAL', 'OTHER'))
);

CREATE INDEX ix_cc_customer ON crm.customer_contacts(customer_id);

-- ============================================================
-- 03D: CUSTOMER SEGMENTS / GROUPS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_groups (
    customer_group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    group_code VARCHAR(50) NOT NULL,
    group_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    group_type VARCHAR(30) NOT NULL DEFAULT 'MANUAL',
    filter_criteria JSONB NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cg_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_group_code UNIQUE (company_id, group_code),
    CONSTRAINT ck_cg_type CHECK (group_type IN ('MANUAL', 'DYNAMIC', 'RFM', 'PURCHASE_BEHAVIOR'))
);

CREATE INDEX ix_cg_company ON crm.customer_groups(company_id);

CREATE TABLE IF NOT EXISTS crm.customer_group_members (
    customer_group_member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_group_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,

    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    added_by_user_id UUID NULL,
    removed_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_cgm_group FOREIGN KEY (customer_group_id) REFERENCES crm.customer_groups(customer_group_id) ON DELETE CASCADE,
    CONSTRAINT fk_cgm_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cgm_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_group_member UNIQUE (customer_group_id, customer_id)
);

CREATE INDEX ix_cgm_group ON crm.customer_group_members(customer_group_id);
CREATE INDEX ix_cgm_customer ON crm.customer_group_members(customer_id);

-- ============================================================
-- 03E: CUSTOMER DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_documents (
    customer_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    document_type_id UUID NULL,
    document_verification_status_id UUID NULL,

    document_number VARCHAR(100) NULL,
    document_title VARCHAR(300) NULL,
    issuing_authority VARCHAR(200) NULL,
    issue_date DATE NULL,
    expiry_date DATE NULL,

    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,
    original_file_name VARCHAR(500) NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,
    file_hash VARCHAR(128) NULL,

    verification_notes TEXT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cd_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cd_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cd_doc_type FOREIGN KEY (document_type_id) REFERENCES reference.document_type_lookup(document_type_id),
    CONSTRAINT fk_cd_ver_status FOREIGN KEY (document_verification_status_id) REFERENCES reference.document_verification_status_lookup(document_verification_status_id)
);

CREATE INDEX ix_cd_customer ON crm.customer_documents(customer_id);

-- ============================================================
-- 03F: CUSTOMER NOTES
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_notes (
    customer_note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,

    note_type VARCHAR(30) NOT NULL DEFAULT 'GENERAL',
    note_text TEXT NOT NULL,

    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    is_visible_to_customer BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_cn_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cn_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_cn_type CHECK (note_type IN ('GENERAL', 'INTERNAL', 'SERVICE', 'SALES', 'BILLING', 'OTHER'))
);

CREATE INDEX ix_cn_customer ON crm.customer_notes(customer_id);

-- ============================================================
-- 03G: CUSTOMER TAGS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_tags (
    customer_tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    tag_name VARCHAR(100) NOT NULL,
    tag_color VARCHAR(20) NULL,
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ct_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_customer_tag UNIQUE (company_id, tag_name)
);

CREATE INDEX ix_ct_company ON crm.customer_tags(company_id);

CREATE TABLE IF NOT EXISTS crm.customer_tag_assignments (
    customer_tag_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    customer_tag_id UUID NOT NULL,
    company_id UUID NOT NULL,

    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by_user_id UUID NULL,
    removed_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_cta_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cta_tag FOREIGN KEY (customer_tag_id) REFERENCES crm.customer_tags(customer_tag_id) ON DELETE CASCADE,
    CONSTRAINT fk_cta_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_customer_tag_assignment UNIQUE (customer_id, customer_tag_id)
);

CREATE INDEX ix_cta_customer ON crm.customer_tag_assignments(customer_id);
CREATE INDEX ix_cta_tag ON crm.customer_tag_assignments(customer_tag_id);

-- ============================================================
-- 03I: CUSTOMER INTERACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_interactions (
    customer_interaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    interaction_type_id UUID NULL,

    interaction_subject VARCHAR(300) NULL,
    interaction_details TEXT NULL,
    interaction_channel VARCHAR(50) NULL,

    interaction_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    direction VARCHAR(20) NULL,

    related_order_id UUID NULL,
    related_case_id UUID NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_ci_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_ci_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ci_order FOREIGN KEY (related_order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT ck_ci_channel CHECK (interaction_channel IS NULL OR interaction_channel IN ('EMAIL', 'PHONE', 'SMS', 'CHAT', 'WHATSAPP', 'IN_PERSON', 'OTHER')),
    CONSTRAINT ck_ci_direction CHECK (direction IS NULL OR direction IN ('INBOUND', 'OUTBOUND'))
);

CREATE INDEX ix_ci_customer ON crm.customer_interactions(customer_id);
CREATE INDEX ix_ci_date ON crm.customer_interactions(interaction_date);

-- ============================================================
-- 03J: CUSTOMER SERVICE CASES
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_service_cases (
    customer_service_case_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    case_type_id UUID NULL,
    case_status_id UUID NULL,
    case_priority_id UUID NULL,

    case_number VARCHAR(50) NOT NULL,
    case_subject VARCHAR(300) NOT NULL,
    case_description TEXT NULL,

    related_order_id UUID NULL,
    related_product_id UUID NULL,

    assigned_to_user_id UUID NULL,
    resolved_at TIMESTAMPTZ NULL,
    resolved_by_user_id UUID NULL,
    resolution_notes TEXT NULL,

    satisfaction_rating INTEGER NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_csc_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_csc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_csc_order FOREIGN KEY (related_order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_csc_product FOREIGN KEY (related_product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_csc_assigned_to FOREIGN KEY (assigned_to_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_case_number UNIQUE (company_id, case_number),
    CONSTRAINT ck_csc_satisfaction CHECK (satisfaction_rating IS NULL OR (satisfaction_rating >= 1 AND satisfaction_rating <= 5))
);

CREATE INDEX ix_csc_customer ON crm.customer_service_cases(customer_id);
CREATE INDEX ix_csc_status ON crm.customer_service_cases(case_status_id);

-- ============================================================
-- 03K: CUSTOMER TASKS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_tasks (
    customer_task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    task_type_id UUID NULL,
    task_status_id UUID NULL,
    task_priority_id UUID NULL,

    task_subject VARCHAR(300) NOT NULL,
    task_description TEXT NULL,

    due_date TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    completed_by_user_id UUID NULL,

    assigned_to_user_id UUID NULL,

    related_order_id UUID NULL,
    related_case_id UUID NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ct_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_ct_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ct_assigned_to FOREIGN KEY (assigned_to_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_ct_order FOREIGN KEY (related_order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_ct_case FOREIGN KEY (related_case_id) REFERENCES crm.customer_service_cases(customer_service_case_id)
);

CREATE INDEX ix_ct_customer ON crm.customer_tasks(customer_id);
CREATE INDEX ix_ct_status ON crm.customer_tasks(task_status_id);
CREATE INDEX ix_ct_due ON crm.customer_tasks(due_date);

-- ============================================================
-- 03L: CUSTOMER SCORING
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_scores (
    customer_score_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    score_type_id UUID NULL,

    score NUMERIC(10,2) NOT NULL DEFAULT 0,
    score_date DATE NOT NULL DEFAULT CURRENT_DATE,

    score_details JSONB NULL,

    calculated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    calculated_by_user_id UUID NULL,

    CONSTRAINT fk_cs_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cs_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_cs_score CHECK (score >= 0)
);

CREATE INDEX ix_cs_customer ON crm.customer_scores(customer_id);
CREATE INDEX ix_cs_date ON crm.customer_scores(score_date);

-- ============================================================
-- 03M: CUSTOMER PREFERENCES
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_preferences (
    customer_preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,

    preferred_language_id UUID NULL,
    preferred_currency_id UUID NULL,
    preferred_contact_method_id UUID NULL,

    accepts_email BOOLEAN NOT NULL DEFAULT FALSE,
    accepts_sms BOOLEAN NOT NULL DEFAULT FALSE,
    accepts_phone BOOLEAN NOT NULL DEFAULT FALSE,
    accepts_marketing BOOLEAN NOT NULL DEFAULT FALSE,

    preferred_contact_time_start TIME NULL,
    preferred_contact_time_end TIME NULL,

    timezone VARCHAR(100) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cp_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_cp_language FOREIGN KEY (preferred_language_id) REFERENCES reference.language_lookup(language_id),
    CONSTRAINT fk_cp_currency FOREIGN KEY (preferred_currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT uq_customer_preference UNIQUE (customer_id, company_id)
);

CREATE INDEX ix_cp_customer ON crm.customer_preferences(customer_id);

-- ============================================================
-- 03N: CUSTOMER ACQUISITION
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_acquisition (
    customer_acquisition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    acquisition_source_id UUID NULL,

    acquisition_date DATE NOT NULL DEFAULT CURRENT_DATE,
    acquisition_channel VARCHAR(50) NULL,
    acquisition_cost NUMERIC(19,4) NULL,

    campaign_id UUID NULL,
    referral_code VARCHAR(100) NULL,
    referred_by_customer_id UUID NULL,

    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ca_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_ca_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ca_referred_by FOREIGN KEY (referred_by_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT ck_ca_channel CHECK (acquisition_channel IS NULL OR acquisition_channel IN ('WEBSITE', 'POS', 'MOBILE', 'PHONE', 'EMAIL', 'REFERRAL', 'CAMPAIGN', 'OTHER'))
);

CREATE INDEX ix_ca_customer ON crm.customer_acquisition(customer_id);
CREATE INDEX ix_ca_date ON crm.customer_acquisition(acquisition_date);

-- ============================================================
-- 03O: CUSTOMER RELATIONSHIPS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_relationships (
    customer_relationship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    related_customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    relationship_type_id UUID NULL,

    relationship_direction VARCHAR(20) NOT NULL DEFAULT 'BIDIRECTIONAL',
    relationship_notes TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_cr_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cr_related FOREIGN KEY (related_customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cr_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_cr_not_self CHECK (customer_id <> related_customer_id),
    CONSTRAINT ck_cr_direction CHECK (relationship_direction IN ('BIDIRECTIONAL', 'PARENT_CHILD', 'CHILD_PARENT', 'ONE_WAY'))
);

CREATE INDEX ix_cr_customer ON crm.customer_relationships(customer_id);
CREATE INDEX ix_cr_related ON crm.customer_relationships(related_customer_id);

-- ============================================================
-- 03P: CUSTOMER COMMERCIAL PROFILES
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_commercial_profiles (
    customer_commercial_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    credit_status_id UUID NULL,
    credit_risk_level_id UUID NULL,

    credit_limit NUMERIC(19,4) NULL,
    available_credit NUMERIC(19,4) NULL,
    payment_terms_days INTEGER NULL,

    total_orders INTEGER NOT NULL DEFAULT 0,
    total_order_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_paid_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    outstanding_balance NUMERIC(19,4) NOT NULL DEFAULT 0,

    last_order_date DATE NULL,
    last_payment_date DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ccp_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_ccp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ccp_credit_status FOREIGN KEY (credit_status_id) REFERENCES crm.customer_credit_status_lookup(customer_credit_status_id),
    CONSTRAINT fk_ccp_risk_level FOREIGN KEY (credit_risk_level_id) REFERENCES crm.customer_credit_risk_level_lookup(customer_credit_risk_level_id),
    CONSTRAINT uq_customer_commercial UNIQUE (customer_id, company_id),
    CONSTRAINT ck_ccp_credit CHECK (credit_limit IS NULL OR credit_limit >= 0)
);

CREATE INDEX ix_ccp_customer ON crm.customer_commercial_profiles(customer_id);

-- ============================================================
-- 03Q: CUSTOMER CREDIT STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_credit_status_lookup (
    customer_credit_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_credit_status_lookup (code, name, description, sort_order) VALUES
    ('APPROVED', 'Approved', 'Credit approved.', 10),
    ('PENDING', 'Pending', 'Credit pending approval.', 20),
    ('REJECTED', 'Rejected', 'Credit rejected.', 30),
    ('SUSPENDED', 'Suspended', 'Credit suspended.', 40),
    ('EXPIRED', 'Expired', 'Credit expired.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 03Q: CUSTOMER CREDIT RISK LEVEL LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_credit_risk_level_lookup (
    customer_credit_risk_level_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_credit_risk_level_lookup (code, name, description, sort_order) VALUES
    ('LOW', 'Low Risk', 'Low credit risk.', 10),
    ('MEDIUM', 'Medium Risk', 'Medium credit risk.', 20),
    ('HIGH', 'High Risk', 'High credit risk.', 30),
    ('CRITICAL', 'Critical Risk', 'Critical credit risk.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 03R: CUSTOMER REFERRALS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_referrals (
    customer_referral_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_customer_id UUID NOT NULL,
    referred_customer_id UUID NOT NULL,
    company_id UUID NOT NULL,
    referral_status_id UUID NULL,

    referral_code VARCHAR(100) NULL,
    referral_date DATE NOT NULL DEFAULT CURRENT_DATE,

    referral_channel VARCHAR(50) NULL,
    referral_notes TEXT NULL,

    is_converted BOOLEAN NOT NULL DEFAULT FALSE,
    converted_at TIMESTAMPTZ NULL,

    reward_amount NUMERIC(19,4) NULL,
    reward_paid BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cref_referrer FOREIGN KEY (referrer_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_cref_referred FOREIGN KEY (referred_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_cref_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_cref_not_self CHECK (referrer_customer_id <> referred_customer_id),
    CONSTRAINT ck_cref_channel CHECK (referral_channel IS NULL OR referral_channel IN ('EMAIL', 'SMS', 'SOCIAL', 'LINK', 'OTHER'))
);

CREATE INDEX ix_cref_referrer ON crm.customer_referrals(referrer_customer_id);
CREATE INDEX ix_cref_referred ON crm.customer_referrals(referred_customer_id);

-- ============================================================
-- 03T: CUSTOMER ACCOUNT SUMMARY (Aggregated)
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_account_summary (
    customer_account_summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    company_id UUID NOT NULL,

    total_orders INTEGER NOT NULL DEFAULT 0,
    total_order_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_paid_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    outstanding_balance NUMERIC(19,4) NOT NULL DEFAULT 0,

    first_order_date DATE NULL,
    last_order_date DATE NULL,
    average_order_amount NUMERIC(19,4) NULL,

    total_interactions INTEGER NOT NULL DEFAULT 0,
    total_service_cases INTEGER NOT NULL DEFAULT 0,
    total_notes INTEGER NOT NULL DEFAULT 0,
    total_documents INTEGER NOT NULL DEFAULT 0,

    last_interaction_date DATE NULL,
    last_service_case_date DATE NULL,

    customer_lifetime_value NUMERIC(19,4) NULL,
    customer_segment VARCHAR(50) NULL,
    churn_risk_score NUMERIC(10,2) NULL,

    last_calculated_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cas_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cas_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_customer_summary UNIQUE (customer_id, company_id),
    CONSTRAINT ck_cas_amounts CHECK (total_order_amount >= 0 AND total_paid_amount >= 0 AND outstanding_balance >= 0)
);

CREATE INDEX ix_cas_customer ON crm.customer_account_summary(customer_id);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Seed Customer Tags
    INSERT INTO crm.customer_tags (company_id, tag_name, tag_color, is_active) VALUES
        (v_company_id, 'VIP', '#FFD700', TRUE),
        (v_company_id, 'WHOLESALE', '#3498db', TRUE),
        (v_company_id, 'NEW', '#27ae60', TRUE),
        (v_company_id, 'INACTIVE', '#95a5a6', TRUE),
        (v_company_id, 'HIGH_VALUE', '#e74c3c', TRUE),
        (v_company_id, 'AT_RISK', '#e67e22', TRUE)
    ON CONFLICT (company_id, tag_name) DO NOTHING;

    -- Seed Customer Groups
    INSERT INTO crm.customer_groups (company_id, group_code, group_name, description, group_type, is_active) VALUES
        (v_company_id, 'VIP', 'VIP Customers', 'VIP customer segment.', 'MANUAL', TRUE),
        (v_company_id, 'WHOLESALE', 'Wholesale Customers', 'Wholesale customer segment.', 'MANUAL', TRUE),
        (v_company_id, 'NEW', 'New Customers', 'New customer segment.', 'MANUAL', TRUE),
        (v_company_id, 'INACTIVE', 'Inactive Customers', 'Inactive customer segment.', 'MANUAL', TRUE)
    ON CONFLICT (company_id, group_code) DO NOTHING;

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 03 CRM
-- 22 Tables + 3 Lookup Tables + Seed Data
-- ============================================================