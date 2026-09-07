BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 02: ORGANIZATION / COMPANY / BUSINESS UNITS
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   The Organization module defines WHO the business is,
--   HOW it is structured, WHERE it operates, and
--   THROUGH WHICH CHANNELS it sells.
--   Multi-company / multi-tenant from the beginning.
-- ============================================================
-- Components:
--   02A  Company Foundation
--   02B  Business Units
--   02C  Departments
--   02D  Branches
--   02E  Stores
--   02F  Warehouses & Locations
--   02G  Sales Channels
--   02H  Employees
--   02I  Employee Assignments
--   02J  Employee Contacts
--   02K  Employee Documents
--   02L  Employee Documents Verification
--   02M  Employee Addresses
--   02N  Employee Bank Accounts
--   02O  Employee Emergency Contacts
--   02P  Employee Qualifications
--   02Q  Employee Skills
--   02R  Employee Experience
--   02S  Employee Education
--   02T  Employee Certifications
--   02U  Employee Dependents
--   02V  Employee Leaves
--   02W  Employee Attendance
--   02X  Employee Shifts
--   02Y  Employee Payroll
--   02Z  Employee Documents Verification
--   02AA Organization 360 / Read Models
-- ============================================================

-- ============================================================
-- 02A: COMPANY TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.company_type_lookup (
    company_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO organization.company_type_lookup (code, name, description, sort_order) VALUES
    ('SOLE_PROPRIETOR', 'Sole Proprietor', 'Sole proprietorship business.', 10),
    ('PARTNERSHIP', 'Partnership', 'Partnership business.', 20),
    ('PRIVATE_LIMITED', 'Private Limited', 'Private limited company.', 30),
    ('PUBLIC_LIMITED', 'Public Limited', 'Public limited company.', 40),
    ('LLC', 'LLC', 'Limited Liability Company.', 50),
    ('HOLDING', 'Holding Company', 'Holding company.', 60),
    ('SUBSIDIARY', 'Subsidiary', 'Subsidiary company.', 70),
    ('FRANCHISE', 'Franchise', 'Franchise business.', 80),
    ('NON_PROFIT', 'Non-Profit', 'Non-profit organization.', 90),
    ('GOVERNMENT', 'Government', 'Government entity.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 02A: COMPANIES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.companies (
    company_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_company_id UUID NULL,
    company_type_id UUID NULL,

    company_code VARCHAR(50) NOT NULL,
    company_name VARCHAR(300) NOT NULL,
    legal_name VARCHAR(300) NULL,
    tax_number VARCHAR(100) NULL,
    registration_number VARCHAR(100) NULL,

    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,
    email VARCHAR(300) NULL,
    website VARCHAR(500) NULL,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state_province VARCHAR(200) NULL,
    postal_code VARCHAR(20) NULL,
    country_code VARCHAR(10) NULL,

    logo_url VARCHAR(500) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_comp_parent FOREIGN KEY (parent_company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_comp_type FOREIGN KEY (company_type_id) REFERENCES organization.company_type_lookup(company_type_id),
    CONSTRAINT uq_company_code UNIQUE (company_code)
);

CREATE INDEX ix_comp_parent ON organization.companies(parent_company_id);
CREATE INDEX ix_comp_active ON organization.companies(is_active);

-- ============================================================
-- 02A: COMPANY SETTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.company_settings (
    company_setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT NULL,
    setting_type VARCHAR(30) NOT NULL DEFAULT 'STRING',
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cs_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id) ON DELETE CASCADE,
    CONSTRAINT uq_company_setting UNIQUE (company_id, setting_key),
    CONSTRAINT ck_cs_type CHECK (setting_type IN ('STRING', 'NUMBER', 'BOOLEAN', 'JSON', 'DATE'))
);

CREATE INDEX ix_cs_company ON organization.company_settings(company_id);

-- ============================================================
-- 02A: COMPANY DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.company_documents (
    company_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

    CONSTRAINT fk_cd_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id) ON DELETE CASCADE,
    CONSTRAINT fk_cd_doc_type FOREIGN KEY (document_type_id) REFERENCES reference.document_type_lookup(document_type_id),
    CONSTRAINT fk_cd_ver_status FOREIGN KEY (document_verification_status_id) REFERENCES reference.document_verification_status_lookup(document_verification_status_id)
);

CREATE INDEX ix_cd_company ON organization.company_documents(company_id);

-- ============================================================
-- 02A: COMPANY BANK ACCOUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.company_bank_accounts (
    company_bank_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    bank_name VARCHAR(200) NOT NULL,
    account_title VARCHAR(200) NULL,
    account_number VARCHAR(100) NOT NULL,
    iban VARCHAR(50) NULL,
    swift_code VARCHAR(20) NULL,
    branch_name VARCHAR(200) NULL,
    branch_code VARCHAR(20) NULL,

    currency_id UUID NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_cba_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id) ON DELETE CASCADE,
    CONSTRAINT fk_cba_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_cba_company ON organization.company_bank_accounts(company_id);

-- ============================================================
-- 02B: BUSINESS UNIT TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.business_unit_type_lookup (
    business_unit_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO organization.business_unit_type_lookup (code, name, description, sort_order) VALUES
    ('HEAD_OFFICE', 'Head Office', 'Main head office.', 10),
    ('REGIONAL_OFFICE', 'Regional Office', 'Regional office.', 20),
    ('DIVISION', 'Division', 'Business division.', 30),
    ('DEPARTMENT', 'Department', 'Department.', 40),
    ('COST_CENTER', 'Cost Center', 'Cost center.', 50),
    ('PROFIT_CENTER', 'Profit Center', 'Profit center.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 02B: BUSINESS UNITS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.business_units (
    business_unit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    business_unit_type_id UUID NULL,

    business_unit_code VARCHAR(50) NOT NULL,
    business_unit_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_bu_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_bu_type FOREIGN KEY (business_unit_type_id) REFERENCES organization.business_unit_type_lookup(business_unit_type_id),
    CONSTRAINT uq_bu_code UNIQUE (company_id, business_unit_code)
);

CREATE INDEX ix_bu_company ON organization.business_units(company_id);
CREATE INDEX ix_bu_active ON organization.business_units(is_active);

-- ============================================================
-- 02C: DEPARTMENTS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.departments (
    department_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    business_unit_id UUID NULL,

    department_code VARCHAR(50) NOT NULL,
    department_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_dept_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_dept_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT uq_dept_code UNIQUE (company_id, department_code)
);

CREATE INDEX ix_dept_company ON organization.departments(company_id);
CREATE INDEX ix_dept_bu ON organization.departments(business_unit_id);
CREATE INDEX ix_dept_active ON organization.departments(is_active);

-- ============================================================
-- 02D: BRANCH TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.branch_type_lookup (
    branch_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO organization.branch_type_lookup (code, name, description, sort_order) VALUES
    ('HEAD_OFFICE', 'Head Office', 'Main head office branch.', 10),
    ('REGIONAL', 'Regional Branch', 'Regional branch.', 20),
    ('LOCAL', 'Local Branch', 'Local branch.', 30),
    ('FRANCHISE', 'Franchise Branch', 'Franchise branch.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 02D: BRANCHES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.branches (
    branch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    branch_type_id UUID NULL,

    branch_code VARCHAR(50) NOT NULL,
    branch_name VARCHAR(200) NOT NULL,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state_id UUID NULL,
    country_id UUID NULL,
    postal_code VARCHAR(20) NULL,

    phone VARCHAR(50) NULL,
    email VARCHAR(300) NULL,

    latitude NUMERIC(10,7) NULL,
    longitude NUMERIC(10,7) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_br_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_br_type FOREIGN KEY (branch_type_id) REFERENCES organization.branch_type_lookup(branch_type_id),
    CONSTRAINT fk_br_state FOREIGN KEY (state_id) REFERENCES reference.state_lookup(state_id),
    CONSTRAINT fk_br_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT uq_branch_code UNIQUE (company_id, branch_code)
);

CREATE INDEX ix_br_company ON organization.branches(company_id);
CREATE INDEX ix_br_active ON organization.branches(is_active);

-- ============================================================
-- 02E: STORE TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.store_type_lookup (
    store_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO organization.store_type_lookup (code, name, description, sort_order) VALUES
    ('RETAIL', 'Retail Store', 'Retail store.', 10),
    ('WHOLESALE', 'Wholesale Store', 'Wholesale store.', 20),
    ('FLAGSHIP', 'Flagship Store', 'Flagship store.', 30),
    ('OUTLET', 'Outlet Store', 'Outlet store.', 40),
    ('POPUP', 'Pop-up Store', 'Pop-up store.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 02E: STORES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.stores (
    store_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    branch_id UUID NULL,
    store_type_id UUID NULL,

    store_code VARCHAR(50) NOT NULL,
    store_name VARCHAR(200) NOT NULL,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state_id UUID NULL,
    country_id UUID NULL,
    postal_code VARCHAR(20) NULL,

    phone VARCHAR(50) NULL,
    email VARCHAR(300) NULL,

    latitude NUMERIC(10,7) NULL,
    longitude NUMERIC(10,7) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_st_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_st_branch FOREIGN KEY (branch_id) REFERENCES organization.branches(branch_id),
    CONSTRAINT fk_st_type FOREIGN KEY (store_type_id) REFERENCES organization.store_type_lookup(store_type_id),
    CONSTRAINT fk_st_state FOREIGN KEY (state_id) REFERENCES reference.state_lookup(state_id),
    CONSTRAINT fk_st_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT uq_store_code UNIQUE (company_id, store_code)
);

CREATE INDEX ix_st_company ON organization.stores(company_id);
CREATE INDEX ix_st_branch ON organization.stores(branch_id);
CREATE INDEX ix_st_active ON organization.stores(is_active);

-- ============================================================
-- 02F: WAREHOUSE TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.warehouse_type_lookup (
    warehouse_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO organization.warehouse_type_lookup (code, name, description, sort_order) VALUES
    ('MAIN', 'Main Warehouse', 'Main warehouse.', 10),
    ('REGIONAL', 'Regional Warehouse', 'Regional warehouse.', 20),
    ('DISTRIBUTION', 'Distribution Center', 'Distribution center.', 30),
    ('RETURNS', 'Returns Warehouse', 'Returns processing warehouse.', 40),
    ('COLD_STORAGE', 'Cold Storage', 'Cold storage warehouse.', 50),
    ('BONDED', 'Bonded Warehouse', 'Bonded warehouse.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 02F: WAREHOUSES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.warehouses (
    warehouse_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    warehouse_type_id UUID NULL,

    warehouse_code VARCHAR(50) NOT NULL,
    warehouse_name VARCHAR(200) NOT NULL,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state_id UUID NULL,
    country_id UUID NULL,
    postal_code VARCHAR(20) NULL,

    phone VARCHAR(50) NULL,
    email VARCHAR(300) NULL,

    latitude NUMERIC(10,7) NULL,
    longitude NUMERIC(10,7) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_wh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_wh_type FOREIGN KEY (warehouse_type_id) REFERENCES organization.warehouse_type_lookup(warehouse_type_id),
    CONSTRAINT fk_wh_state FOREIGN KEY (state_id) REFERENCES reference.state_lookup(state_id),
    CONSTRAINT fk_wh_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT uq_warehouse_code UNIQUE (company_id, warehouse_code)
);

CREATE INDEX ix_wh_company ON organization.warehouses(company_id);
CREATE INDEX ix_wh_active ON organization.warehouses(is_active);

-- ============================================================
-- 02F: WAREHOUSE LOCATIONS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.warehouse_locations (
    warehouse_location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id UUID NOT NULL,

    location_code VARCHAR(50) NOT NULL,
    location_name VARCHAR(200) NULL,
    location_type VARCHAR(30) NOT NULL DEFAULT 'STORAGE',

    aisle VARCHAR(20) NULL,
    rack VARCHAR(20) NULL,
    shelf VARCHAR(20) NULL,
    bin VARCHAR(20) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_wl_warehouse FOREIGN KEY (warehouse_id) REFERENCES organization.warehouses(warehouse_id) ON DELETE CASCADE,
    CONSTRAINT uq_location_code UNIQUE (warehouse_id, location_code),
    CONSTRAINT ck_wl_type CHECK (location_type IN ('STORAGE', 'RECEIVING', 'SHIPPING', 'QUARANTINE', 'DAMAGED', 'STAGING', 'PICKING'))
);

CREATE INDEX ix_wl_warehouse ON organization.warehouse_locations(warehouse_id);
CREATE INDEX ix_wl_active ON organization.warehouse_locations(is_active);

-- ============================================================
-- 02G: SALES CHANNELS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.sales_channels (
    sales_channel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,

    channel_code VARCHAR(50) NOT NULL,
    channel_name VARCHAR(200) NOT NULL,
    channel_type VARCHAR(30) NOT NULL DEFAULT 'ONLINE',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_sc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_channel_code UNIQUE (company_id, channel_code),
    CONSTRAINT ck_sc_type CHECK (channel_type IN ('ONLINE', 'OFFLINE', 'POS', 'MOBILE', 'B2B', 'MARKETPLACE'))
);

CREATE INDEX ix_sc_company ON organization.sales_channels(company_id);
CREATE INDEX ix_sc_active ON organization.sales_channels(is_active);

-- ============================================================
-- 02H: EMPLOYMENT TYPE LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.employment_type_lookup (
    employment_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO identity.employment_type_lookup (code, name, description, sort_order) VALUES
    ('FULL_TIME', 'Full Time', 'Full-time employee.', 10),
    ('PART_TIME', 'Part Time', 'Part-time employee.', 20),
    ('CONTRACT', 'Contract', 'Contract employee.', 30),
    ('INTERN', 'Intern', 'Intern.', 40),
    ('TEMPORARY', 'Temporary', 'Temporary employee.', 50),
    ('CONSULTANT', 'Consultant', 'Consultant.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 02H: EMPLOYMENT STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.employment_status_lookup (
    employment_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO identity.employment_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Active employee.', 10),
    ('ON_LEAVE', 'On Leave', 'Employee on leave.', 20),
    ('SUSPENDED', 'Suspended', 'Employee suspended.', 30),
    ('TERMINATED', 'Terminated', 'Employee terminated.', 40),
    ('RETIRED', 'Retired', 'Employee retired.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 02H: EMPLOYEES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.employees (
    employee_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    person_id UUID NULL,
    employment_type_id UUID NULL,
    employment_status_id UUID NULL,

    employee_code VARCHAR(50) NOT NULL,
    employee_name VARCHAR(200) NOT NULL,

    hire_date DATE NULL,
    termination_date DATE NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_emp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_emp_person FOREIGN KEY (person_id) REFERENCES identity.persons(person_id),
    CONSTRAINT fk_emp_type FOREIGN KEY (employment_type_id) REFERENCES identity.employment_type_lookup(employment_type_id),
    CONSTRAINT fk_emp_status FOREIGN KEY (employment_status_id) REFERENCES identity.employment_status_lookup(employment_status_id),
    CONSTRAINT uq_employee_code UNIQUE (company_id, employee_code)
);

CREATE INDEX ix_emp_company ON identity.employees(company_id);
CREATE INDEX ix_emp_person ON identity.employees(person_id);
CREATE INDEX ix_emp_active ON identity.employees(is_active);

-- ============================================================
-- 02I: EMPLOYEE ASSIGNMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_assignments (
    employee_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,
    business_unit_id UUID NULL,
    department_id UUID NULL,
    branch_id UUID NULL,
    store_id UUID NULL,
    warehouse_id UUID NULL,

    assignment_type VARCHAR(30) NOT NULL DEFAULT 'PRIMARY',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    effective_from DATE NULL,
    effective_to DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ea_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_ea_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ea_bu FOREIGN KEY (business_unit_id) REFERENCES organization.business_units(business_unit_id),
    CONSTRAINT fk_ea_dept FOREIGN KEY (department_id) REFERENCES organization.departments(department_id),
    CONSTRAINT fk_ea_branch FOREIGN KEY (branch_id) REFERENCES organization.branches(branch_id),
    CONSTRAINT fk_ea_store FOREIGN KEY (store_id) REFERENCES organization.stores(store_id),
    CONSTRAINT fk_ea_warehouse FOREIGN KEY (warehouse_id) REFERENCES organization.warehouses(warehouse_id),
    CONSTRAINT ck_ea_type CHECK (assignment_type IN ('PRIMARY', 'SECONDARY', 'TEMPORARY'))
);

CREATE INDEX ix_ea_employee ON organization.employee_assignments(employee_id);
CREATE INDEX ix_ea_company ON organization.employee_assignments(company_id);
CREATE INDEX ix_ea_active ON organization.employee_assignments(is_active);

-- ============================================================
-- 02J: EMPLOYEE CONTACTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_contacts (
    employee_contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    contact_type VARCHAR(30) NOT NULL DEFAULT 'GENERAL',
    contact_name VARCHAR(200) NULL,
    relationship VARCHAR(100) NULL,
    phone VARCHAR(50) NULL,
    email VARCHAR(300) NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ec_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_ec_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_ec_type CHECK (contact_type IN ('GENERAL', 'EMERGENCY', 'FAMILY', 'OTHER'))
);

CREATE INDEX ix_ec_employee ON organization.employee_contacts(employee_id);

-- ============================================================
-- 02K: EMPLOYEE DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_documents (
    employee_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
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

    CONSTRAINT fk_ed_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_ed_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ed_doc_type FOREIGN KEY (document_type_id) REFERENCES reference.document_type_lookup(document_type_id),
    CONSTRAINT fk_ed_ver_status FOREIGN KEY (document_verification_status_id) REFERENCES reference.document_verification_status_lookup(document_verification_status_id)
);

CREATE INDEX ix_ed_employee ON organization.employee_documents(employee_id);

-- ============================================================
-- 02M: EMPLOYEE ADDRESSES
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_addresses (
    employee_address_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    address_type VARCHAR(30) NOT NULL DEFAULT 'PERMANENT',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state_id UUID NULL,
    country_id UUID NULL,
    postal_code VARCHAR(20) NULL,

    phone VARCHAR(50) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ea_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_ea_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ea_state FOREIGN KEY (state_id) REFERENCES reference.state_lookup(state_id),
    CONSTRAINT fk_ea_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT ck_ea_type CHECK (address_type IN ('PERMANENT', 'TEMPORARY', 'MAILING', 'OTHER'))
);

CREATE INDEX ix_ea_employee ON organization.employee_addresses(employee_id);

-- ============================================================
-- 02N: EMPLOYEE BANK ACCOUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_bank_accounts (
    employee_bank_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    bank_name VARCHAR(200) NOT NULL,
    account_title VARCHAR(200) NULL,
    account_number VARCHAR(100) NOT NULL,
    iban VARCHAR(50) NULL,
    swift_code VARCHAR(20) NULL,
    branch_name VARCHAR(200) NULL,
    branch_code VARCHAR(20) NULL,

    currency_id UUID NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_eba_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_eba_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_eba_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id)
);

CREATE INDEX ix_eba_employee ON organization.employee_bank_accounts(employee_id);

-- ============================================================
-- 02O: EMPLOYEE EMERGENCY CONTACTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_emergency_contacts (
    employee_emergency_contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    contact_name VARCHAR(200) NOT NULL,
    relationship VARCHAR(100) NULL,
    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,
    email VARCHAR(300) NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_eec_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_eec_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id)
);

CREATE INDEX ix_eec_employee ON organization.employee_emergency_contacts(employee_id);

-- ============================================================
-- 02P: EMPLOYEE QUALIFICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_qualifications (
    employee_qualification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    qualification_name VARCHAR(200) NOT NULL,
    institution VARCHAR(200) NULL,
    year_completed INTEGER NULL,
    grade VARCHAR(50) NULL,
    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_eq_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_eq_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id)
);

CREATE INDEX ix_eq_employee ON organization.employee_qualifications(employee_id);

-- ============================================================
-- 02Q: EMPLOYEE SKILLS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_skills (
    employee_skill_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    skill_name VARCHAR(200) NOT NULL,
    proficiency_level VARCHAR(30) NULL,
    years_experience INTEGER NULL,
    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_es_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_es_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_es_proficiency CHECK (proficiency_level IS NULL OR proficiency_level IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'EXPERT'))
);

CREATE INDEX ix_es_employee ON organization.employee_skills(employee_id);

-- ============================================================
-- 02R: EMPLOYEE EXPERIENCE
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_experience (
    employee_experience_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    company_name VARCHAR(200) NOT NULL,
    job_title VARCHAR(200) NULL,
    start_date DATE NULL,
    end_date DATE NULL,
    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_eexp_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_eexp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id)
);

CREATE INDEX ix_eexp_employee ON organization.employee_experience(employee_id);

-- ============================================================
-- 02S: EMPLOYEE EDUCATION
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_education (
    employee_education_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    degree VARCHAR(200) NOT NULL,
    institution VARCHAR(200) NULL,
    field_of_study VARCHAR(200) NULL,
    start_year INTEGER NULL,
    end_year INTEGER NULL,
    grade VARCHAR(50) NULL,
    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_eedu_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_eedu_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id)
);

CREATE INDEX ix_eedu_employee ON organization.employee_education(employee_id);

-- ============================================================
-- 02T: EMPLOYEE CERTIFICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_certifications (
    employee_certification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    certification_name VARCHAR(200) NOT NULL,
    issuing_authority VARCHAR(200) NULL,
    issue_date DATE NULL,
    expiry_date DATE NULL,
    certification_number VARCHAR(100) NULL,
    description TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ecert_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_ecert_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id)
);

CREATE INDEX ix_ecert_employee ON organization.employee_certifications(employee_id);

-- ============================================================
-- 02U: EMPLOYEE DEPENDENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_dependents (
    employee_dependent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    dependent_name VARCHAR(200) NOT NULL,
    relationship VARCHAR(100) NULL,
    date_of_birth DATE NULL,
    gender VARCHAR(10) NULL,
    phone VARCHAR(50) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_edep_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_edep_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_edep_gender CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER'))
);

CREATE INDEX ix_edep_employee ON organization.employee_dependents(employee_id);

-- ============================================================
-- 02V: EMPLOYEE LEAVES
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_leaves (
    employee_leave_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    leave_type VARCHAR(30) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    approved_by_user_id UUID NULL,
    approved_at TIMESTAMPTZ NULL,
    rejection_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NULL,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_el_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_el_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_el_type CHECK (leave_type IN ('ANNUAL', 'SICK', 'CASUAL', 'MATERNITY', 'PATERNITY', 'UNPAID', 'OTHER')),
    CONSTRAINT ck_el_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
    CONSTRAINT ck_el_dates CHECK (end_date >= start_date)
);

CREATE INDEX ix_el_employee ON organization.employee_leaves(employee_id);
CREATE INDEX ix_el_status ON organization.employee_leaves(status);

-- ============================================================
-- 02W: EMPLOYEE ATTENDANCE
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_attendance (
    employee_attendance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    attendance_date DATE NOT NULL,
    check_in_time TIME NULL,
    check_out_time TIME NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PRESENT',
    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_eatt_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_eatt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_attendance UNIQUE (employee_id, attendance_date),
    CONSTRAINT ck_eatt_status CHECK (status IN ('PRESENT', 'ABSENT', 'HALF_DAY', 'ON_LEAVE', 'HOLIDAY'))
);

CREATE INDEX ix_eatt_employee ON organization.employee_attendance(employee_id);
CREATE INDEX ix_eatt_date ON organization.employee_attendance(attendance_date);

-- ============================================================
-- 02X: EMPLOYEE SHIFTS
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_shifts (
    employee_shift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    shift_date DATE NOT NULL,
    shift_start_time TIME NULL,
    shift_end_time TIME NULL,

    shift_type VARCHAR(30) NOT NULL DEFAULT 'REGULAR',
    notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_esh_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_esh_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_esh_type CHECK (shift_type IN ('REGULAR', 'OVERTIME', 'NIGHT', 'WEEKEND', 'HOLIDAY'))
);

CREATE INDEX ix_esh_employee ON organization.employee_shifts(employee_id);
CREATE INDEX ix_esh_date ON organization.employee_shifts(shift_date);

-- ============================================================
-- 02Y: EMPLOYEE PAYROLL
-- ============================================================

CREATE TABLE IF NOT EXISTS organization.employee_payroll (
    employee_payroll_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,
    company_id UUID NOT NULL,

    payroll_period VARCHAR(20) NOT NULL,
    payroll_month INTEGER NOT NULL,
    payroll_year INTEGER NOT NULL,

    basic_salary NUMERIC(19,4) NOT NULL DEFAULT 0,
    allowances NUMERIC(19,4) NOT NULL DEFAULT 0,
    deductions NUMERIC(19,4) NOT NULL DEFAULT 0,
    net_salary NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    paid_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ep_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT fk_ep_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ep_currency FOREIGN KEY (currency_id) REFERENCES reference.currency_lookup(currency_id),
    CONSTRAINT ck_ep_period CHECK (payroll_period IN ('MONTHLY', 'BIWEEKLY', 'WEEKLY')),
    CONSTRAINT ck_ep_status CHECK (status IN ('PENDING', 'APPROVED', 'PAID', 'CANCELLED')),
    CONSTRAINT ck_ep_amounts CHECK (basic_salary >= 0 AND allowances >= 0 AND deductions >= 0 AND net_salary >= 0)
);

CREATE INDEX ix_ep_employee ON organization.employee_payroll(employee_id);
CREATE INDEX ix_ep_period ON organization.employee_payroll(payroll_month, payroll_year);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Seed company settings
    INSERT INTO organization.company_settings (company_id, setting_key, setting_value, setting_type, description)
    SELECT v_company_id, 'BASE_CURRENCY', 'PKR', 'STRING', 'Base currency for the company.'
    WHERE NOT EXISTS (SELECT 1 FROM organization.company_settings WHERE company_id = v_company_id AND setting_key = 'BASE_CURRENCY');

    INSERT INTO organization.company_settings (company_id, setting_key, setting_value, setting_type, description)
    SELECT v_company_id, 'TIMEZONE', 'Asia/Karachi', 'STRING', 'Default timezone.'
    WHERE NOT EXISTS (SELECT 1 FROM organization.company_settings WHERE company_id = v_company_id AND setting_key = 'TIMEZONE');

    -- Seed business units
    INSERT INTO organization.business_units (company_id, business_unit_type_id, business_unit_code, business_unit_name, description, is_active)
    SELECT v_company_id,
           (SELECT business_unit_type_id FROM organization.business_unit_type_lookup WHERE code = 'HEAD_OFFICE'),
           'BU-HEAD', 'Head Office', 'Main head office business unit.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.business_units WHERE company_id = v_company_id AND business_unit_code = 'BU-HEAD');

    INSERT INTO organization.business_units (company_id, business_unit_type_id, business_unit_code, business_unit_name, description, is_active)
    SELECT v_company_id,
           (SELECT business_unit_type_id FROM organization.business_unit_type_lookup WHERE code = 'REGIONAL_OFFICE'),
           'BU-REGIONAL', 'Regional Office', 'Regional office business unit.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.business_units WHERE company_id = v_company_id AND business_unit_code = 'BU-REGIONAL');

    -- Seed departments
    INSERT INTO organization.departments (company_id, business_unit_id, department_code, department_name, description, is_active)
    SELECT v_company_id,
           (SELECT business_unit_id FROM organization.business_units WHERE company_id = v_company_id AND business_unit_code = 'BU-HEAD'),
           'DEPT-IT', 'IT Department', 'Information Technology department.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.departments WHERE company_id = v_company_id AND department_code = 'DEPT-IT');

    INSERT INTO organization.departments (company_id, business_unit_id, department_code, department_name, description, is_active)
    SELECT v_company_id,
           (SELECT business_unit_id FROM organization.business_units WHERE company_id = v_company_id AND business_unit_code = 'BU-HEAD'),
           'DEPT-HR', 'HR Department', 'Human Resources department.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.departments WHERE company_id = v_company_id AND department_code = 'DEPT-HR');

    INSERT INTO organization.departments (company_id, business_unit_id, department_code, department_name, description, is_active)
    SELECT v_company_id,
           (SELECT business_unit_id FROM organization.business_units WHERE company_id = v_company_id AND business_unit_code = 'BU-HEAD'),
           'DEPT-SALES', 'Sales Department', 'Sales department.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.departments WHERE company_id = v_company_id AND department_code = 'DEPT-SALES');

    -- Seed branches
    INSERT INTO organization.branches (company_id, branch_type_id, branch_code, branch_name, city, is_active)
    SELECT v_company_id,
           (SELECT branch_type_id FROM organization.branch_type_lookup WHERE code = 'HEAD_OFFICE'),
           'BR-MAIN', 'Main Branch', 'Karachi', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.branches WHERE company_id = v_company_id AND branch_code = 'BR-MAIN');

    -- Seed stores
    INSERT INTO organization.stores (company_id, branch_id, store_type_id, store_code, store_name, city, is_active)
    SELECT v_company_id,
           (SELECT branch_id FROM organization.branches WHERE company_id = v_company_id AND branch_code = 'BR-MAIN'),
           (SELECT store_type_id FROM organization.store_type_lookup WHERE code = 'RETAIL'),
           'ST-MAIN', 'Main Store', 'Karachi', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.stores WHERE company_id = v_company_id AND store_code = 'ST-MAIN');

    -- Seed warehouses
    INSERT INTO organization.warehouses (company_id, warehouse_type_id, warehouse_code, warehouse_name, city, is_active)
    SELECT v_company_id,
           (SELECT warehouse_type_id FROM organization.warehouse_type_lookup WHERE code = 'MAIN'),
           'WH-MAIN', 'Main Warehouse', 'Karachi', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.warehouses WHERE company_id = v_company_id AND warehouse_code = 'WH-MAIN');

    -- Seed sales channels
    INSERT INTO organization.sales_channels (company_id, channel_code, channel_name, channel_type, is_active)
    SELECT v_company_id, 'WEBSITE', 'Website', 'ONLINE', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.sales_channels WHERE company_id = v_company_id AND channel_code = 'WEBSITE');

    INSERT INTO organization.sales_channels (company_id, channel_code, channel_name, channel_type, is_active)
    SELECT v_company_id, 'POS', 'Point of Sale', 'POS', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.sales_channels WHERE company_id = v_company_id AND channel_code = 'POS');

    INSERT INTO organization.sales_channels (company_id, channel_code, channel_name, channel_type, is_active)
    SELECT v_company_id, 'MOBILE_APP', 'Mobile App', 'MOBILE', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM organization.sales_channels WHERE company_id = v_company_id AND channel_code = 'MOBILE_APP');

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 02 Organization
-- 30+ Tables + 6 Lookup Tables + Seed Data
-- ============================================================