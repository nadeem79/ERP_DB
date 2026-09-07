BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 01: IDENTITY & ACCESS MANAGEMENT
-- DATABASE TABLES
-- ============================================================
-- Key Principle:
--   The Identity module defines WHO can access the system,
--   WHAT they can access, and HOW they authenticate.
--   Multi-company / multi-tenant from the beginning.
-- ============================================================
-- Components:
--   01A  Persons
--   01B  Users
--   01C  User Status
--   01D  Roles
--   01E  Permissions
--   01F  User Roles
--   01G  Role Permissions
--   01H  User Sessions
--   01I  User MFA Methods
--   01J  User Login History
--   01K  User Security Events
--   01L  User Password History
--   01M  User Devices
--   01N  User Tokens
--   01O  User Notifications
--   01P  User Preferences
--   01Q  User Audit Log
--   01R  Identity 360 / Read Models
-- ============================================================

-- ============================================================
-- 01A: USER STATUS LOOKUP
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_status_lookup (
    user_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO identity.user_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'User is active.', 10),
    ('INACTIVE', 'Inactive', 'User is inactive.', 20),
    ('LOCKED', 'Locked', 'User account locked.', 30),
    ('SUSPENDED', 'Suspended', 'User suspended.', 40),
    ('PENDING_VERIFICATION', 'Pending Verification', 'User pending verification.', 50),
    ('DELETED', 'Deleted', 'User deleted.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 01A: PERSONS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.persons (
    person_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    date_of_birth DATE NULL,
    gender VARCHAR(10) NULL,
    email VARCHAR(300) NULL,
    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,
    address_line1 VARCHAR(300) NULL,
    address_line2 VARCHAR(300) NULL,
    city VARCHAR(200) NULL,
    state_id UUID NULL,
    country_id UUID NULL,
    postal_code VARCHAR(20) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_person_state FOREIGN KEY (state_id) REFERENCES reference.state_lookup(state_id),
    CONSTRAINT fk_person_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT ck_person_gender CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER'))
);

CREATE INDEX ix_person_email ON identity.persons(email);
CREATE INDEX ix_person_active ON identity.persons(is_active);

-- ============================================================
-- 01B: USERS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(300) NULL UNIQUE,
    password_hash VARCHAR(300) NULL,
    user_status_id UUID NOT NULL DEFAULT (SELECT user_status_id FROM identity.user_status_lookup WHERE code = 'ACTIVE'),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ NULL,
    last_login_ip INET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_user_person FOREIGN KEY (person_id) REFERENCES identity.persons(person_id),
    CONSTRAINT fk_user_status FOREIGN KEY (user_status_id) REFERENCES identity.user_status_lookup(user_status_id)
);

CREATE INDEX ix_user_person ON identity.users(person_id);
CREATE INDEX ix_user_status ON identity.users(user_status_id);
CREATE INDEX ix_user_active ON identity.users(is_active);

-- ============================================================
-- 01D: ROLES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NULL,
    role_code VARCHAR(50) NOT NULL,
    role_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_role_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT uq_role_code UNIQUE (company_id, role_code)
);

CREATE INDEX ix_role_company ON identity.roles(company_id);
CREATE INDEX ix_role_active ON identity.roles(is_active);

-- ============================================================
-- 01E: PERMISSIONS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_code VARCHAR(100) NOT NULL UNIQUE,
    permission_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    module VARCHAR(50) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_permission_code UNIQUE (permission_code)
);

CREATE INDEX ix_perm_module ON identity.permissions(module);
CREATE INDEX ix_perm_active ON identity.permissions(is_active);

-- ============================================================
-- 01F: USER ROLES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_roles (
    user_role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    role_id UUID NOT NULL,
    company_id UUID NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by_user_id UUID NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES identity.roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ur_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_user_role UNIQUE (user_id, role_id, company_id)
);

CREATE INDEX ix_ur_user ON identity.user_roles(user_id);
CREATE INDEX ix_ur_role ON identity.user_roles(role_id);
CREATE INDEX ix_ur_active ON identity.user_roles(is_active);

-- ============================================================
-- 01G: ROLE PERMISSIONS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.role_permissions (
    role_permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL,
    permission_id UUID NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by_user_id UUID NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES identity.roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES identity.permissions(permission_id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_role_permission UNIQUE (role_id, permission_id)
);

CREATE INDEX ix_rp_role ON identity.role_permissions(role_id);
CREATE INDEX ix_rp_permission ON identity.role_permissions(permission_id);
CREATE INDEX ix_rp_active ON identity.role_permissions(is_active);

-- ============================================================
-- 01H: USER SESSIONS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    session_token VARCHAR(300) NOT NULL UNIQUE,
    ip_address INET NULL,
    user_agent TEXT NULL,
    device_type VARCHAR(30) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT ck_us_device CHECK (device_type IS NULL OR device_type IN ('WEB', 'MOBILE', 'TABLET', 'API', 'OTHER'))
);

CREATE INDEX ix_us_user ON identity.user_sessions(user_id);
CREATE INDEX ix_us_token ON identity.user_sessions(session_token);
CREATE INDEX ix_us_active ON identity.user_sessions(is_active);
CREATE INDEX ix_us_expires ON identity.user_sessions(expires_at);

-- ============================================================
-- 01I: USER MFA METHODS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_mfa_methods (
    user_mfa_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    mfa_type VARCHAR(30) NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_umfa_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT ck_umfa_type CHECK (mfa_type IN ('TOTP', 'SMS', 'EMAIL', 'WEBAUTHN', 'BACKUP_CODE'))
);

CREATE INDEX ix_umfa_user ON identity.user_mfa_methods(user_id);
CREATE INDEX ix_umfa_active ON identity.user_mfa_methods(is_active);

-- ============================================================
-- 01J: USER LOGIN HISTORY (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_login_history (
    login_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    login_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET NULL,
    user_agent TEXT NULL,
    device_type VARCHAR(30) NULL,
    is_successful BOOLEAN NOT NULL DEFAULT TRUE,
    failure_reason TEXT NULL,

    CONSTRAINT ulh_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE
);

CREATE INDEX ix_ulh_user ON identity.user_login_history(user_id);
CREATE INDEX ix_ulh_login_at ON identity.user_login_history(login_at);
CREATE INDEX ix_ulh_successful ON identity.user_login_history(is_successful);

-- ============================================================
-- 01K: USER SECURITY EVENTS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_security_events (
    security_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    event_details TEXT NULL,
    ip_address INET NULL,
    user_agent TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_use_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT ck_use_type CHECK (event_type IN ('LOGIN', 'LOGOUT', 'PASSWORD_CHANGED', 'PASSWORD_RESET', 'MFA_ENABLED', 'MFA_DISABLED', 'ACCOUNT_LOCKED', 'ACCOUNT_UNLOCKED', 'SESSION_REVOKED', 'PERMISSION_CHANGED', 'ROLE_CHANGED', 'OTHER'))
);

CREATE INDEX ix_use_user ON identity.user_security_events(user_id);
CREATE INDEX ix_use_type ON identity.user_security_events(event_type);
CREATE INDEX ix_use_created ON identity.user_security_events(created_at);

-- ============================================================
-- 01L: USER PASSWORD HISTORY (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_password_history (
    password_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    password_hash VARCHAR(300) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by_user_id UUID NULL,

    CONSTRAINT fk_uph_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_uph_changed_by FOREIGN KEY (changed_by_user_id) REFERENCES identity.users(user_id)
);

CREATE INDEX ix_uph_user ON identity.user_password_history(user_id);
CREATE INDEX ix_uph_changed ON identity.user_password_history(changed_at);

-- ============================================================
-- 01M: USER DEVICES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_name VARCHAR(200) NULL,
    device_type VARCHAR(30) NULL,
    device_token VARCHAR(300) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ud_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT ck_ud_device CHECK (device_type IS NULL OR device_type IN ('WEB', 'MOBILE', 'TABLET', 'API', 'OTHER'))
);

CREATE INDEX ix_ud_user ON identity.user_devices(user_id);
CREATE INDEX ix_ud_active ON identity.user_devices(is_active);

-- ============================================================
-- 01N: USER TOKENS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    token_type VARCHAR(30) NOT NULL,
    token_value VARCHAR(500) NOT NULL,
    expires_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ut_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT ck_ut_type CHECK (token_type IN ('ACCESS', 'REFRESH', 'API', 'RESET', 'VERIFICATION'))
);

CREATE INDEX ix_ut_user ON identity.user_tokens(user_id);
CREATE INDEX ix_ut_type ON identity.user_tokens(token_type);
CREATE INDEX ix_ut_active ON identity.user_tokens(is_active);
CREATE INDEX ix_ut_expires ON identity.user_tokens(expires_at);

-- ============================================================
-- 01O: USER NOTIFICATIONS (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(300) NOT NULL,
    message TEXT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_un_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT ck_un_type CHECK (notification_type IN ('INFO', 'WARNING', 'ERROR', 'SECURITY', 'SYSTEM', 'MARKETING'))
);

CREATE INDEX ix_un_user ON identity.user_notifications(user_id);
CREATE INDEX ix_un_type ON identity.user_notifications(notification_type);
CREATE INDEX ix_un_read ON identity.user_notifications(is_read);
CREATE INDEX ix_un_created ON identity.user_notifications(created_at);

-- ============================================================
-- 01P: USER PREFERENCES (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_preferences (
    preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    preference_key VARCHAR(100) NOT NULL,
    preference_value TEXT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_up_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE CASCADE,
    CONSTRAINT uq_user_preference UNIQUE (user_id, preference_key)
);

CREATE INDEX ix_up_user ON identity.user_preferences(user_id);

-- ============================================================
-- 01Q: USER AUDIT LOG (Enhanced)
-- ============================================================

CREATE TABLE IF NOT EXISTS identity.user_audit_log (
    audit_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NULL,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NULL,
    entity_id UUID NULL,
    old_values JSONB NULL,
    new_values JSONB NULL,
    ip_address INET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ual_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id) ON DELETE SET NULL
);

CREATE INDEX ix_ual_user ON identity.user_audit_log(user_id);
CREATE INDEX ix_ual_action ON identity.user_audit_log(action);
CREATE INDEX ix_ual_entity ON identity.user_audit_log(entity_type, entity_id);
CREATE INDEX ix_ual_created ON identity.user_audit_log(created_at);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Seed default roles
    INSERT INTO identity.roles (company_id, role_code, role_name, description, is_system, is_active) VALUES
        (v_company_id, 'ADMIN', 'Administrator', 'Full system administrator.', TRUE, TRUE),
        (v_company_id, 'MANAGER', 'Manager', 'Department manager.', TRUE, TRUE),
        (v_company_id, 'SALES', 'Sales Representative', 'Sales representative.', TRUE, TRUE),
        (v_company_id, 'SUPPORT', 'Support Agent', 'Customer support agent.', TRUE, TRUE),
        (v_company_id, 'FINANCE', 'Finance Officer', 'Finance officer.', TRUE, TRUE),
        (v_company_id, 'WAREHOUSE', 'Warehouse Manager', 'Warehouse manager.', TRUE, TRUE),
        (v_company_id, 'HR', 'HR Manager', 'Human resources manager.', TRUE, TRUE),
        (v_company_id, 'VIEWER', 'Viewer', 'Read-only access.', TRUE, TRUE)
    ON CONFLICT (company_id, role_code) DO NOTHING;

    -- Seed default permissions
    INSERT INTO identity.permissions (permission_code, permission_name, description, module, is_active) VALUES
        ('USERS_VIEW', 'View Users', 'View user list.', 'IDENTITY', TRUE),
        ('USERS_CREATE', 'Create Users', 'Create new users.', 'IDENTITY', TRUE),
        ('USERS_EDIT', 'Edit Users', 'Edit user details.', 'IDENTITY', TRUE),
        ('USERS_DELETE', 'Delete Users', 'Delete users.', 'IDENTITY', TRUE),
        ('ROLES_VIEW', 'View Roles', 'View roles.', 'IDENTITY', TRUE),
        ('ROLES_CREATE', 'Create Roles', 'Create roles.', 'IDENTITY', TRUE),
        ('ROLES_EDIT', 'Edit Roles', 'Edit roles.', 'IDENTITY', TRUE),
        ('ROLES_DELETE', 'Delete Roles', 'Delete roles.', 'IDENTITY', TRUE),
        ('PERMISSIONS_VIEW', 'View Permissions', 'View permissions.', 'IDENTITY', TRUE),
        ('PERMISSIONS_ASSIGN', 'Assign Permissions', 'Assign permissions to roles.', 'IDENTITY', TRUE),
        ('SESSIONS_VIEW', 'View Sessions', 'View user sessions.', 'IDENTITY', TRUE),
        ('SESSIONS_REVOKE', 'Revoke Sessions', 'Revoke user sessions.', 'IDENTITY', TRUE),
        ('AUDIT_VIEW', 'View Audit Log', 'View audit log.', 'IDENTITY', TRUE),
        ('CUSTOMERS_VIEW', 'View Customers', 'View customers.', 'CRM', TRUE),
        ('CUSTOMERS_CREATE', 'Create Customers', 'Create customers.', 'CRM', TRUE),
        ('CUSTOMERS_EDIT', 'Edit Customers', 'Edit customers.', 'CRM', TRUE),
        ('ORDERS_VIEW', 'View Orders', 'View orders.', 'SALES', TRUE),
        ('ORDERS_CREATE', 'Create Orders', 'Create orders.', 'SALES', TRUE),
        ('ORDERS_EDIT', 'Edit Orders', 'Edit orders.', 'SALES', TRUE),
        ('INVENTORY_VIEW', 'View Inventory', 'View inventory.', 'INVENTORY', TRUE),
        ('INVENTORY_ADJUST', 'Adjust Inventory', 'Adjust inventory.', 'INVENTORY', TRUE),
        ('REPORTS_VIEW', 'View Reports', 'View reports.', 'REPORTS', TRUE),
        ('SETTINGS_VIEW', 'View Settings', 'View settings.', 'SETTINGS', TRUE),
        ('SETTINGS_EDIT', 'Edit Settings', 'Edit settings.', 'SETTINGS', TRUE)
    ON CONFLICT (permission_code) DO NOTHING;

END $$;

COMMIT;

-- ============================================================
-- SUMMARY: Module 01 Identity
-- 17 Tables + 1 Lookup Table + Seed Data
-- ============================================================