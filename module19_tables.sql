BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 19 — NOTIFICATION CENTER & COMMUNICATION ENGINE
-- DATABASE TABLES
-- ============================================================
-- Components:
--   19.1  Notification Channels
--   19.2  Notification Providers & Registry
--   19.3  Provider Configurations & Webhooks
--   19.4  Notification Templates & Versioning
--   19.5  Template Variables
--   19.6  Notifications (Core)
--   19.7  Notification Recipients & Deliveries
--   19.8  Delivery Attempts & Retries
--   19.9  Notification Attachments
--   19.10 Dead Letter Queue
--   19.11 User/Customer Preferences
--   19.12 Suppression List
--   19.13 Scheduled Notifications
--   19.14 Digest Notifications
--   19.15 In-App Notification Center
--   19.16 Notification Events & Audit
--   19.17 Analytics Summary
-- ============================================================

CREATE SCHEMA IF NOT EXISTS notifications;

-- ============================================================
-- 19.1 NOTIFICATION LOOKUPS
-- ============================================================

-- Channel Lookup
CREATE TABLE IF NOT EXISTS notifications.notification_channel_lookup (
    notification_channel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    supports_html BOOLEAN NOT NULL DEFAULT FALSE,
    supports_attachments BOOLEAN NOT NULL DEFAULT FALSE,
    supports_rich_media BOOLEAN NOT NULL DEFAULT FALSE,
    max_recipients_per_send INTEGER NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.notification_channel_lookup (code, name, description, supports_html, supports_attachments, supports_rich_media, sort_order) VALUES
    ('EMAIL', 'Email', 'Email notifications via SMTP or API providers.', TRUE, TRUE, TRUE, 10),
    ('SMS', 'SMS', 'Text message notifications.', FALSE, FALSE, FALSE, 20),
    ('WHATSAPP', 'WhatsApp', 'WhatsApp Business API notifications.', FALSE, TRUE, TRUE, 30),
    ('PUSH', 'Push Notification', 'Mobile push notifications (iOS/Android).', FALSE, FALSE, TRUE, 40),
    ('IN_APP', 'In-App', 'In-application notification center.', TRUE, FALSE, FALSE, 50),
    ('WEB_PUSH', 'Web Push', 'Browser push notifications.', FALSE, FALSE, TRUE, 60),
    ('VOICE', 'Voice', 'Voice call/IVR notifications.', FALSE, FALSE, FALSE, 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Notification Type Lookup
CREATE TABLE IF NOT EXISTS notifications.notification_type_lookup (
    notification_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    requires_consent BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.notification_type_lookup (code, name, description, requires_consent, sort_order) VALUES
    ('TRANSACTIONAL', 'Transactional', 'Order confirmations, receipts, shipping updates.', FALSE, 10),
    ('MARKETING', 'Marketing', 'Promotions, campaigns, newsletters.', TRUE, 20),
    ('SYSTEM', 'System', 'System alerts, maintenance, downtime.', FALSE, 30),
    ('SECURITY', 'Security', 'Login alerts, password changes, MFA.', FALSE, 40),
    ('SUPPORT', 'Support', 'Ticket updates, case responses.', FALSE, 50),
    ('LOYALTY', 'Loyalty', 'Points earned, tier changes, rewards.', FALSE, 60),
    ('FINANCIAL', 'Financial', 'Invoices, payments, refunds.', FALSE, 70),
    ('REMINDER', 'Reminder', 'Scheduled reminders, follow-ups.', FALSE, 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Notification Status Lookup
CREATE TABLE IF NOT EXISTS notifications.notification_status_lookup (
    notification_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.notification_status_lookup (code, name, description, is_terminal, sort_order) VALUES
    ('QUEUED', 'Queued', 'Notification is in the queue.', FALSE, 10),
    ('PROCESSING', 'Processing', 'Notification is being processed.', FALSE, 20),
    ('SENT', 'Sent', 'Notification sent to provider.', FALSE, 30),
    ('DELIVERED', 'Delivered', 'Notification delivered to recipient.', FALSE, 40),
    ('OPENED', 'Opened', 'Recipient opened the notification.', FALSE, 50),
    ('CLICKED', 'Clicked', 'Recipient clicked a link.', FALSE, 60),
    ('BOUNCED', 'Bounced', 'Notification bounced.', TRUE, 70),
    ('COMPLAINED', 'Complained', 'Recipient marked as spam.', TRUE, 80),
    ('UNSUBSCRIBED', 'Unsubscribed', 'Recipient unsubscribed.', TRUE, 90),
    ('FAILED', 'Failed', 'Notification failed to send.', TRUE, 100),
    ('CANCELLED', 'Cancelled', 'Notification was cancelled.', TRUE, 110),
    ('SUPPRESSED', 'Suppressed', 'Suppressed due to preferences.', TRUE, 120)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Notification Priority
CREATE TABLE IF NOT EXISTS notifications.notification_priority_lookup (
    notification_priority_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    retry_count INTEGER NOT NULL DEFAULT 3,
    retry_delay_minutes INTEGER NOT NULL DEFAULT 5,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.notification_priority_lookup (code, name, description, retry_count, retry_delay_minutes, sort_order) VALUES
    ('LOW', 'Low', 'Non-urgent notifications.', 2, 30, 10),
    ('NORMAL', 'Normal', 'Standard priority.', 3, 15, 20),
    ('HIGH', 'High', 'Important notifications.', 5, 5, 30),
    ('URGENT', 'Urgent', 'Critical/time-sensitive.', 7, 2, 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Provider Status
CREATE TABLE IF NOT EXISTS notifications.provider_status_lookup (
    provider_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.provider_status_lookup (code, name, description, sort_order) VALUES
    ('ACTIVE', 'Active', 'Provider is operational.', 10),
    ('MAINTENANCE', 'Maintenance', 'Provider under maintenance.', 20),
    ('SUSPENDED', 'Suspended', 'Provider suspended.', 30),
    ('INACTIVE', 'Inactive', 'Provider disabled.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Template Status
CREATE TABLE IF NOT EXISTS notifications.template_status_lookup (
    template_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.template_status_lookup (code, name, description, sort_order) VALUES
    ('DRAFT', 'Draft', 'Template is being designed.', 10),
    ('ACTIVE', 'Active', 'Template is live.', 20),
    ('ARCHIVED', 'Archived', 'Template archived.', 30)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Preference Status
CREATE TABLE IF NOT EXISTS notifications.preference_status_lookup (
    preference_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.preference_status_lookup (code, name, description, sort_order) VALUES
    ('OPTED_IN', 'Opted In', 'User has opted in.', 10),
    ('OPTED_OUT', 'Opted Out', 'User has opted out.', 20),
    ('UNSUBSCRIBED', 'Unsubscribed', 'User unsubscribed.', 30),
    ('BOUNCED', 'Bounced', 'Address hard bounced.', 40),
    ('COMPLAINED', 'Complained', 'User marked as spam.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Digest Frequency
CREATE TABLE IF NOT EXISTS notifications.digest_frequency_lookup (
    digest_frequency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    interval_hours INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.digest_frequency_lookup (code, name, description, interval_hours, sort_order) VALUES
    ('HOURLY', 'Hourly', 'Digest sent every hour.', 1, 10),
    ('DAILY', 'Daily', 'Digest sent once daily.', 24, 20),
    ('WEEKLY', 'Weekly', 'Digest sent once weekly.', 168, 30),
    ('MONTHLY', 'Monthly', 'Digest sent once monthly.', 720, 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Schedule Status
CREATE TABLE IF NOT EXISTS notifications.schedule_status_lookup (
    schedule_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO notifications.schedule_status_lookup (code, name, description, sort_order) VALUES
    ('SCHEDULED', 'Scheduled', 'Notification scheduled for future send.', 10),
    ('PROCESSING', 'Processing', 'Scheduled notification being processed.', 20),
    ('SENT', 'Sent', 'Scheduled notification sent.', 30),
    ('CANCELLED', 'Cancelled', 'Scheduled notification cancelled.', 40),
    ('FAILED', 'Failed', 'Scheduled notification failed.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 19.2 NOTIFICATION PROVIDERS (Registry)
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_providers (
    notification_provider_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_status_id UUID NOT NULL DEFAULT (SELECT provider_status_id FROM notifications.provider_status_lookup WHERE code = 'ACTIVE'),
    notification_channel_id UUID NOT NULL,

    provider_code VARCHAR(50) NOT NULL UNIQUE,
    provider_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    api_endpoint VARCHAR(500) NULL,
    api_version VARCHAR(50) NULL,
    authentication_type VARCHAR(50) NULL,

    supports_tracking BOOLEAN NOT NULL DEFAULT FALSE,
    supports_templates BOOLEAN NOT NULL DEFAULT FALSE,
    supports_attachments BOOLEAN NOT NULL DEFAULT FALSE,
    supports_scheduling BOOLEAN NOT NULL DEFAULT FALSE,
    supports_batch BOOLEAN NOT NULL DEFAULT FALSE,

    rate_limit_per_minute INTEGER NULL,
    rate_limit_per_day INTEGER NULL,

    priority INTEGER NOT NULL DEFAULT 0,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    failover_provider_id UUID NULL,

    icon_url VARCHAR(500) NULL,
    documentation_url VARCHAR(500) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_np_status FOREIGN KEY (provider_status_id) REFERENCES notifications.provider_status_lookup(provider_status_id),
    CONSTRAINT fk_np_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_np_failover FOREIGN KEY (failover_provider_id) REFERENCES notifications.notification_providers(notification_provider_id)
);

CREATE INDEX ix_np_channel ON notifications.notification_providers(notification_channel_id);
CREATE INDEX ix_np_active ON notifications.notification_providers(is_active, is_primary);

-- ============================================================
-- 19.3 PROVIDER CONFIGURATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.provider_configurations (
    provider_configuration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_provider_id UUID NOT NULL,

    config_name VARCHAR(200) NOT NULL,

    api_key_encrypted TEXT NULL,
    api_secret_encrypted TEXT NULL,
    access_token_encrypted TEXT NULL,
    refresh_token_encrypted TEXT NULL,

    from_email VARCHAR(300) NULL,
    from_name VARCHAR(200) NULL,
    reply_to_email VARCHAR(300) NULL,

    sender_id VARCHAR(50) NULL,
    whatsapp_business_number VARCHAR(50) NULL,

    webhook_url VARCHAR(500) NULL,
    webhook_secret_encrypted TEXT NULL,

    environment VARCHAR(20) NOT NULL DEFAULT 'PRODUCTION',
    is_sandbox BOOLEAN NOT NULL DEFAULT FALSE,

    custom_settings JSONB NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_pc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pc_provider FOREIGN KEY (notification_provider_id) REFERENCES notifications.notification_providers(notification_provider_id),
    CONSTRAINT ck_pc_environment CHECK (environment IN ('PRODUCTION', 'STAGING', 'SANDBOX', 'DEVELOPMENT'))
);

CREATE INDEX ix_pc_company ON notifications.provider_configurations(company_id);
CREATE INDEX ix_pc_provider ON notifications.provider_configurations(notification_provider_id);

-- Provider Webhooks
CREATE TABLE IF NOT EXISTS notifications.provider_webhooks (
    provider_webhook_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_provider_id UUID NOT NULL,
    company_id UUID NULL,

    webhook_type VARCHAR(50) NOT NULL,
    webhook_url VARCHAR(500) NOT NULL,
    webhook_secret_encrypted TEXT NULL,

    events JSONB NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_at TIMESTAMPTZ NULL,

    last_received_at TIMESTAMPTZ NULL,
    last_status_code INTEGER NULL,
    failure_count INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pw_provider FOREIGN KEY (notification_provider_id) REFERENCES notifications.notification_providers(notification_provider_id),
    CONSTRAINT fk_pw_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT ck_pw_type CHECK (webhook_type IN ('DELIVERY', 'OPEN', 'CLICK', 'BOUNCE', 'COMPLAINT', 'UNSUBSCRIBE', 'SPAM', 'ALL'))
);

-- ============================================================
-- 19.4 NOTIFICATION TEMPLATES
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_templates (
    notification_template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_channel_id UUID NOT NULL,
    notification_type_id UUID NOT NULL,
    template_status_id UUID NOT NULL DEFAULT (SELECT template_status_id FROM notifications.template_status_lookup WHERE code = 'DRAFT'),

    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    subject_template VARCHAR(500) NULL,
    body_template TEXT NULL,
    html_template TEXT NULL,
    text_template TEXT NULL,
    push_title_template VARCHAR(200) NULL,
    push_body_template TEXT NULL,
    sms_template TEXT NULL,
    whatsapp_template TEXT NULL,

    cta_text VARCHAR(200) NULL,
    cta_url_template VARCHAR(500) NULL,

    header_image_url VARCHAR(500) NULL,
    footer_text TEXT NULL,

    locale VARCHAR(10) NOT NULL DEFAULT 'en',
    direction VARCHAR(5) NOT NULL DEFAULT 'LTR',

    current_version INTEGER NOT NULL DEFAULT 1,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_nt_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_nt_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_nt_type FOREIGN KEY (notification_type_id) REFERENCES notifications.notification_type_lookup(notification_type_id),
    CONSTRAINT fk_nt_status FOREIGN KEY (template_status_id) REFERENCES notifications.template_status_lookup(template_status_id),
    CONSTRAINT uq_template_code UNIQUE (company_id, template_code),
    CONSTRAINT ck_nt_direction CHECK (direction IN ('LTR', 'RTL'))
);

CREATE INDEX ix_nt_company ON notifications.notification_templates(company_id);
CREATE INDEX ix_nt_channel ON notifications.notification_templates(notification_channel_id);
CREATE INDEX ix_nt_type ON notifications.notification_templates(notification_type_id);
CREATE INDEX ix_nt_active ON notifications.notification_templates(is_active, template_status_id);

-- Template Versions
CREATE TABLE IF NOT EXISTS notifications.template_versions (
    template_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_template_id UUID NOT NULL,

    version_number INTEGER NOT NULL,
    subject_template VARCHAR(500) NULL,
    body_template TEXT NULL,
    html_template TEXT NULL,
    text_template TEXT NULL,

    change_description TEXT NULL,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_tv_template FOREIGN KEY (notification_template_id) REFERENCES notifications.notification_templates(notification_template_id) ON DELETE CASCADE,
    CONSTRAINT uq_template_version UNIQUE (notification_template_id, version_number)
);

CREATE INDEX ix_tv_template ON notifications.template_versions(notification_template_id);

-- Template Variables
CREATE TABLE IF NOT EXISTS notifications.template_variables (
    template_variable_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_template_id UUID NOT NULL,

    variable_name VARCHAR(100) NOT NULL,
    variable_type VARCHAR(30) NOT NULL DEFAULT 'STRING',
    description VARCHAR(500) NULL,
    default_value TEXT NULL,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    sample_value TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_tvar_template FOREIGN KEY (notification_template_id) REFERENCES notifications.notification_templates(notification_template_id) ON DELETE CASCADE,
    CONSTRAINT uq_template_variable UNIQUE (notification_template_id, variable_name),
    CONSTRAINT ck_tvar_type CHECK (variable_type IN ('STRING', 'INTEGER', 'DECIMAL', 'BOOLEAN', 'DATE', 'DATETIME', 'CURRENCY', 'URL', 'HTML'))
);

CREATE INDEX ix_tvar_template ON notifications.template_variables(notification_template_id);

-- ============================================================
-- 19.6 NOTIFICATIONS (Core)
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_channel_id UUID NOT NULL,
    notification_type_id UUID NOT NULL,
    notification_status_id UUID NOT NULL DEFAULT (SELECT notification_status_id FROM notifications.notification_status_lookup WHERE code = 'QUEUED'),
    notification_priority_id UUID NOT NULL DEFAULT (SELECT notification_priority_id FROM notifications.notification_priority_lookup WHERE code = 'NORMAL'),
    notification_template_id UUID NULL,
    notification_provider_id UUID NULL,
    provider_configuration_id UUID NULL,

    notification_number VARCHAR(50) NOT NULL,
    subject VARCHAR(500) NULL,
    body TEXT NULL,
    html_body TEXT NULL,
    text_body TEXT NULL,
    push_title VARCHAR(200) NULL,
    push_body TEXT NULL,

    cta_text VARCHAR(200) NULL,
    cta_url VARCHAR(500) NULL,

    reference_type VARCHAR(100) NULL,
    reference_id UUID NULL,
    reference_number VARCHAR(200) NULL,

    trigger_event VARCHAR(100) NULL,
    trigger_source VARCHAR(100) NULL,
    trigger_data JSONB NULL,

    template_variables JSONB NULL,
    metadata JSONB NULL,

    total_recipients INTEGER NOT NULL DEFAULT 0,
    sent_count INTEGER NOT NULL DEFAULT 0,
    delivered_count INTEGER NOT NULL DEFAULT 0,
    opened_count INTEGER NOT NULL DEFAULT 0,
    clicked_count INTEGER NOT NULL DEFAULT 0,
    failed_count INTEGER NOT NULL DEFAULT 0,
    bounced_count INTEGER NOT NULL DEFAULT 0,

    queued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processing_started_at TIMESTAMPTZ NULL,
    first_sent_at TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_n_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_n_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_n_type FOREIGN KEY (notification_type_id) REFERENCES notifications.notification_type_lookup(notification_type_id),
    CONSTRAINT fk_n_status FOREIGN KEY (notification_status_id) REFERENCES notifications.notification_status_lookup(notification_status_id),
    CONSTRAINT fk_n_priority FOREIGN KEY (notification_priority_id) REFERENCES notifications.notification_priority_lookup(notification_priority_id),
    CONSTRAINT fk_n_template FOREIGN KEY (notification_template_id) REFERENCES notifications.notification_templates(notification_template_id),
    CONSTRAINT fk_n_provider FOREIGN KEY (notification_provider_id) REFERENCES notifications.notification_providers(notification_provider_id),
    CONSTRAINT fk_n_config FOREIGN KEY (provider_configuration_id) REFERENCES notifications.provider_configurations(provider_configuration_id),
    CONSTRAINT uq_notification_number UNIQUE (company_id, notification_number)
);

CREATE INDEX ix_n_company ON notifications.notifications(company_id);
CREATE INDEX ix_n_channel ON notifications.notifications(notification_channel_id);
CREATE INDEX ix_n_type ON notifications.notifications(notification_type_id);
CREATE INDEX ix_n_status ON notifications.notifications(notification_status_id);
CREATE INDEX ix_n_reference ON notifications.notifications(reference_type, reference_id);
CREATE INDEX ix_n_queued ON notifications.notifications(queued_at DESC);

-- ============================================================
-- 19.7 NOTIFICATION RECIPIENTS & DELIVERIES
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_recipients (
    notification_recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,

    recipient_type VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER',
    customer_id UUID NULL,
    user_id UUID NULL,
    employee_id UUID NULL,

    recipient_name VARCHAR(200) NULL,
    recipient_email VARCHAR(300) NULL,
    recipient_phone VARCHAR(50) NULL,
    recipient_device_token VARCHAR(500) NULL,

    delivery_status_id UUID NULL,
    sent_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,
    opened_at TIMESTAMPTZ NULL,
    clicked_at TIMESTAMPTZ NULL,
    bounced_at TIMESTAMPTZ NULL,
    failed_at TIMESTAMPTZ NULL,
    unsubscribed_at TIMESTAMPTZ NULL,
    complained_at TIMESTAMPTZ NULL,

    failure_reason TEXT NULL,
    provider_message_id VARCHAR(200) NULL,

    personalization_data JSONB NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_nr_notification FOREIGN KEY (notification_id) REFERENCES notifications.notifications(notification_id) ON DELETE CASCADE,
    CONSTRAINT fk_nr_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_nr_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_nr_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT ck_nr_type CHECK (recipient_type IN ('CUSTOMER', 'USER', 'EMPLOYEE', 'EXTERNAL'))
);

CREATE INDEX ix_nr_notification ON notifications.notification_recipients(notification_id);
CREATE INDEX ix_nr_customer ON notifications.notification_recipients(customer_id);
CREATE INDEX ix_nr_user ON notifications.notification_recipients(user_id);
CREATE INDEX ix_nr_status ON notifications.notification_recipients(delivery_status_id);

-- Notification Deliveries
CREATE TABLE IF NOT EXISTS notifications.notification_deliveries (
    notification_delivery_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,
    notification_recipient_id UUID NOT NULL,
    notification_provider_id UUID NULL,

    delivery_status_id UUID NULL,
    provider_message_id VARCHAR(200) NULL,

    sent_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,
    opened_at TIMESTAMPTZ NULL,
    clicked_at TIMESTAMPTZ NULL,
    bounced_at TIMESTAMPTZ NULL,
    complained_at TIMESTAMPTZ NULL,

    provider_response JSONB NULL,
    error_message TEXT NULL,
    error_code VARCHAR(100) NULL,

    attempt_count INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_nd_notification FOREIGN KEY (notification_id) REFERENCES notifications.notifications(notification_id) ON DELETE CASCADE,
    CONSTRAINT fk_nd_recipient FOREIGN KEY (notification_recipient_id) REFERENCES notifications.notification_recipients(notification_recipient_id) ON DELETE CASCADE,
    CONSTRAINT fk_nd_provider FOREIGN KEY (notification_provider_id) REFERENCES notifications.notification_providers(notification_provider_id)
);

CREATE INDEX ix_nd_notification ON notifications.notification_deliveries(notification_id);
CREATE INDEX ix_nd_recipient ON notifications.notification_deliveries(notification_recipient_id);

-- ============================================================
-- 19.8 DELIVERY ATTEMPTS (Retry Logic)
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.delivery_attempts (
    delivery_attempt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_delivery_id UUID NOT NULL,
    notification_provider_id UUID NOT NULL,

    attempt_number INTEGER NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    attempted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    response_code INTEGER NULL,
    response_body TEXT NULL,
    error_message TEXT NULL,
    error_code VARCHAR(100) NULL,

    duration_ms INTEGER NULL,

    is_retry BOOLEAN NOT NULL DEFAULT FALSE,
    next_retry_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_da_delivery FOREIGN KEY (notification_delivery_id) REFERENCES notifications.notification_deliveries(notification_delivery_id) ON DELETE CASCADE,
    CONSTRAINT fk_da_provider FOREIGN KEY (notification_provider_id) REFERENCES notifications.notification_providers(notification_provider_id),
    CONSTRAINT ck_da_status CHECK (status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'BOUNCED', 'TIMEOUT'))
);

CREATE INDEX ix_da_delivery ON notifications.delivery_attempts(notification_delivery_id);
CREATE INDEX ix_da_retry ON notifications.delivery_attempts(next_retry_at) WHERE status = 'PENDING' AND is_retry = TRUE;

-- ============================================================
-- 19.9 NOTIFICATION ATTACHMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_attachments (
    notification_attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,

    file_name VARCHAR(500) NOT NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,

    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,
    file_hash VARCHAR(128) NULL,

    is_inline BOOLEAN NOT NULL DEFAULT FALSE,
    content_id VARCHAR(200) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_na_notification FOREIGN KEY (notification_id) REFERENCES notifications.notifications(notification_id) ON DELETE CASCADE
);

CREATE INDEX ix_na_notification ON notifications.notification_attachments(notification_id);

-- ============================================================
-- 19.10 DEAD LETTER QUEUE
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.dead_letter_queue (
    dead_letter_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NULL,
    notification_delivery_id UUID NULL,

    original_payload JSONB NOT NULL,
    error_message TEXT NULL,
    error_code VARCHAR(100) NULL,
    error_details JSONB NULL,

    failure_count INTEGER NOT NULL DEFAULT 1,
    first_failed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_failed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMPTZ NULL,
    resolved_by_user_id UUID NULL,
    resolution_notes TEXT NULL,

    retry_after TIMESTAMPTZ NULL,
    max_retries INTEGER NOT NULL DEFAULT 5,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_dlq_notification FOREIGN KEY (notification_id) REFERENCES notifications.notifications(notification_id) ON DELETE SET NULL,
    CONSTRAINT fk_dlq_delivery FOREIGN KEY (notification_delivery_id) REFERENCES notifications.notification_deliveries(notification_delivery_id) ON DELETE SET NULL
);

CREATE INDEX ix_dlq_unresolved ON notifications.dead_letter_queue(is_resolved, last_failed_at DESC) WHERE is_resolved = FALSE;

-- ============================================================
-- 19.11 USER/CUSTOMER PREFERENCES
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_preferences (
    notification_preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_channel_id UUID NOT NULL,
    notification_type_id UUID NOT NULL,

    customer_id UUID NULL,
    user_id UUID NULL,
    employee_id UUID NULL,

    preference_status_id UUID NOT NULL DEFAULT (SELECT preference_status_id FROM notifications.preference_status_lookup WHERE code = 'OPTED_IN'),

    quiet_hours_start TIME NULL,
    quiet_hours_end TIME NULL,
    timezone VARCHAR(100) NULL,

    preferred_language VARCHAR(10) NULL,

    updated_by_user_id UUID NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_nprefs_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_nprefs_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_nprefs_type FOREIGN KEY (notification_type_id) REFERENCES notifications.notification_type_lookup(notification_type_id),
    CONSTRAINT fk_nprefs_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_nprefs_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_nprefs_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_nprefs_status FOREIGN KEY (preference_status_id) REFERENCES notifications.preference_status_lookup(preference_status_id),
    CONSTRAINT uq_preference UNIQUE (company_id, notification_channel_id, notification_type_id, COALESCE(customer_id, '00000000-0000-0000-0000-000000000000'), COALESCE(user_id, '00000000-0000-0000-0000-000000000000'), COALESCE(employee_id, '00000000-0000-0000-0000-000000000000'))
);

CREATE INDEX ix_nprefs_customer ON notifications.notification_preferences(customer_id);
CREATE INDEX ix_nprefs_user ON notifications.notification_preferences(user_id);
CREATE INDEX ix_nprefs_channel_type ON notifications.notification_preferences(notification_channel_id, notification_type_id);

-- ============================================================
-- 19.12 SUPPRESSION LIST
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_suppressions (
    notification_suppression_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_channel_id UUID NOT NULL,

    customer_id UUID NULL,
    user_id UUID NULL,
    email_address VARCHAR(300) NULL,
    phone_number VARCHAR(50) NULL,

    suppression_reason VARCHAR(50) NOT NULL,
    suppression_source VARCHAR(50) NOT NULL DEFAULT 'USER',
    notes TEXT NULL,

    suppressed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    suppressed_by_user_id UUID NULL,
    expires_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_ns_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ns_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_ns_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ns_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_ns_reason CHECK (suppression_reason IN ('UNSUBSCRIBED', 'BOUNCED', 'COMPLAINED', 'MANUAL', 'LEGAL', 'FRAUD')),
    CONSTRAINT ck_ns_source CHECK (suppression_source IN ('USER', 'PROVIDER', 'ADMIN', 'SYSTEM', 'LEGAL'))
);

CREATE INDEX ix_ns_email ON notifications.notification_suppressions(email_address);
CREATE INDEX ix_ns_phone ON notifications.notification_suppressions(phone_number);
CREATE INDEX ix_ns_customer ON notifications.notification_suppressions(customer_id);
CREATE INDEX ix_ns_active ON notifications.notification_suppressions(is_active, suppression_reason);

-- ============================================================
-- 19.13 SCHEDULED NOTIFICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.scheduled_notifications (
    scheduled_notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_template_id UUID NULL,
    notification_channel_id UUID NOT NULL,
    notification_type_id UUID NOT NULL,
    schedule_status_id UUID NOT NULL DEFAULT (SELECT schedule_status_id FROM notifications.schedule_status_lookup WHERE code = 'SCHEDULED'),

    schedule_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    scheduled_at TIMESTAMPTZ NOT NULL,
    timezone VARCHAR(100) NOT NULL DEFAULT 'Asia/Karachi',

    recipient_filter JSONB NULL,
    template_variables JSONB NULL,

    sent_notification_id UUID NULL,
    sent_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,
    cancellation_reason TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sn_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sn_template FOREIGN KEY (notification_template_id) REFERENCES notifications.notification_templates(notification_template_id),
    CONSTRAINT fk_sn_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_sn_type FOREIGN KEY (notification_type_id) REFERENCES notifications.notification_type_lookup(notification_type_id),
    CONSTRAINT fk_sn_status FOREIGN KEY (schedule_status_id) REFERENCES notifications.schedule_status_lookup(schedule_status_id)
);

CREATE INDEX ix_sn_scheduled ON notifications.scheduled_notifications(scheduled_at) WHERE schedule_status_id = (SELECT schedule_status_id FROM notifications.schedule_status_lookup WHERE code = 'SCHEDULED');

-- ============================================================
-- 19.14 DIGEST NOTIFICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_digests (
    notification_digest_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_channel_id UUID NOT NULL,
    digest_frequency_id UUID NOT NULL,
    notification_template_id UUID NULL,

    digest_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    digest_query TEXT NULL,
    digest_filter JSONB NULL,

    send_time TIME NOT NULL DEFAULT '09:00:00',
    timezone VARCHAR(100) NOT NULL DEFAULT 'Asia/Karachi',
    day_of_week INTEGER NULL,

    recipient_filter JSONB NULL,

    last_sent_at TIMESTAMPTZ NULL,
    next_send_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ndig_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ndig_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_ndig_frequency FOREIGN KEY (digest_frequency_id) REFERENCES notifications.digest_frequency_lookup(digest_frequency_id),
    CONSTRAINT fk_ndig_template FOREIGN KEY (notification_template_id) REFERENCES notifications.notification_templates(notification_template_id),
    CONSTRAINT ck_ndig_dow CHECK (day_of_week IS NULL OR (day_of_week >= 1 AND day_of_week <= 7))
);

-- Digest Entries
CREATE TABLE IF NOT EXISTS notifications.digest_entries (
    digest_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_digest_id UUID NOT NULL,
    customer_id UUID NULL,
    user_id UUID NULL,
    employee_id UUID NULL,

    entry_data JSONB NOT NULL,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_de_digest FOREIGN KEY (notification_digest_id) REFERENCES notifications.notification_digests(notification_digest_id) ON DELETE CASCADE,
    CONSTRAINT fk_de_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id)
);

CREATE INDEX ix_de_digest ON notifications.digest_entries(notification_digest_id, is_sent);

-- ============================================================
-- 19.15 IN-APP NOTIFICATION CENTER
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.in_app_notifications (
    in_app_notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NULL,
    company_id UUID NOT NULL,

    recipient_type VARCHAR(20) NOT NULL DEFAULT 'USER',
    user_id UUID NULL,
    customer_id UUID NULL,
    employee_id UUID NULL,

    title VARCHAR(300) NOT NULL,
    body TEXT NULL,
    notification_type VARCHAR(50) NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'INFO',

    icon_url VARCHAR(500) NULL,
    action_url VARCHAR(500) NULL,
    action_text VARCHAR(100) NULL,

    reference_type VARCHAR(100) NULL,
    reference_id UUID NULL,

    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ NULL,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    archived_at TIMESTAMPTZ NULL,

    expires_at TIMESTAMPTZ NULL,
    metadata JSONB NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ian_notification FOREIGN KEY (notification_id) REFERENCES notifications.notifications(notification_id) ON DELETE SET NULL,
    CONSTRAINT fk_ian_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ian_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_ian_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ian_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT ck_ian_type CHECK (recipient_type IN ('USER', 'CUSTOMER', 'EMPLOYEE')),
    CONSTRAINT ck_ian_severity CHECK (severity IN ('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL'))
);

CREATE INDEX ix_ian_user ON notifications.in_app_notifications(user_id, is_read, created_at DESC);
CREATE INDEX ix_ian_customer ON notifications.in_app_notifications(customer_id, is_read, created_at DESC);
CREATE INDEX ix_ian_employee ON notifications.in_app_notifications(employee_id, is_read, created_at DESC);

-- ============================================================
-- 19.16 NOTIFICATION EVENTS & AUDIT
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_events (
    notification_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NULL,
    notification_recipient_id UUID NULL,
    notification_delivery_id UUID NULL,

    event_type VARCHAR(50) NOT NULL,
    event_data JSONB NULL,

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(50) NOT NULL DEFAULT 'SYSTEM',

    ip_address INET NULL,
    user_agent TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ne_notification FOREIGN KEY (notification_id) REFERENCES notifications.notifications(notification_id) ON DELETE CASCADE,
    CONSTRAINT fk_ne_recipient FOREIGN KEY (notification_recipient_id) REFERENCES notifications.notification_recipients(notification_recipient_id) ON DELETE CASCADE,
    CONSTRAINT fk_ne_delivery FOREIGN KEY (notification_delivery_id) REFERENCES notifications.notification_deliveries(notification_delivery_id) ON DELETE CASCADE,
    CONSTRAINT ck_ne_type CHECK (event_type IN (
        'QUEUED', 'PROCESSING', 'SENT', 'DELIVERED', 'OPENED', 'CLICKED',
        'BOUNCED', 'COMPLAINED', 'UNSUBSCRIBED', 'FAILED', 'CANCELLED',
        'RETRY_SCHEDULED', 'RETRY_ATTEMPTED', 'SUPPRESSED', 'TEMPLATE_RENDERED',
        'PROVIDER_SELECTED', 'PROVIDER_FAILOVER', 'DEAD_LETTERED'
    ))
);

CREATE INDEX ix_ne_notification ON notifications.notification_events(notification_id);
CREATE INDEX ix_ne_occurred ON notifications.notification_events(occurred_at DESC);
CREATE INDEX ix_ne_type ON notifications.notification_events(event_type);

-- ============================================================
-- 19.17 ANALYTICS SUMMARY (Cache Table)
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications.notification_analytics_summary (
    analytics_summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    notification_channel_id UUID NOT NULL,
    notification_type_id UUID NOT NULL,

    summary_date DATE NOT NULL,

    total_queued BIGINT NOT NULL DEFAULT 0,
    total_sent BIGINT NOT NULL DEFAULT 0,
    total_delivered BIGINT NOT NULL DEFAULT 0,
    total_opened BIGINT NOT NULL DEFAULT 0,
    total_clicked BIGINT NOT NULL DEFAULT 0,
    total_bounced BIGINT NOT NULL DEFAULT 0,
    total_complained BIGINT NOT NULL DEFAULT 0,
    total_unsubscribed BIGINT NOT NULL DEFAULT 0,
    total_failed BIGINT NOT NULL DEFAULT 0,

    delivery_rate NUMERIC(7,4) NULL,
    open_rate NUMERIC(7,4) NULL,
    click_rate NUMERIC(7,4) NULL,
    bounce_rate NUMERIC(7,4) NULL,
    complaint_rate NUMERIC(7,4) NULL,

    avg_delivery_time_ms INTEGER NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_nas_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_nas_channel FOREIGN KEY (notification_channel_id) REFERENCES notifications.notification_channel_lookup(notification_channel_id),
    CONSTRAINT fk_nas_type FOREIGN KEY (notification_type_id) REFERENCES notifications.notification_type_lookup(notification_type_id),
    CONSTRAINT uq_analytics UNIQUE (company_id, notification_channel_id, notification_type_id, summary_date)
);

CREATE INDEX ix_nas_date ON notifications.notification_analytics_summary(summary_date DESC);

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_email_channel UUID;
    v_sms_channel UUID;
    v_transactional_type UUID;
    v_marketing_type UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    SELECT notification_channel_id INTO v_email_channel FROM notifications.notification_channel_lookup WHERE code = 'EMAIL';
    SELECT notification_channel_id INTO v_sms_channel FROM notifications.notification_channel_lookup WHERE code = 'SMS';
    SELECT notification_type_id INTO v_transactional_type FROM notifications.notification_type_lookup WHERE code = 'TRANSACTIONAL';
    SELECT notification_type_id INTO v_marketing_type FROM notifications.notification_type_lookup WHERE code = 'MARKETING';

    -- Create default providers
    INSERT INTO notifications.notification_providers (notification_channel_id, provider_code, provider_name, description, api_endpoint, is_primary, priority)
    SELECT v_email_channel, 'SENDGRID', 'SendGrid', 'Email delivery via SendGrid API.', 'https://api.sendgrid.com/v3', TRUE, 1
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_providers WHERE provider_code = 'SENDGRID');

    INSERT INTO notifications.notification_providers (notification_channel_id, provider_code, provider_name, description, api_endpoint, is_primary, priority)
    SELECT v_email_channel, 'MAILGUN', 'Mailgun', 'Email delivery via Mailgun API.', 'https://api.mailgun.net/v3', FALSE, 2
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_providers WHERE provider_code = 'MAILGUN');

    INSERT INTO notifications.notification_providers (notification_channel_id, provider_code, provider_name, description, api_endpoint, is_primary, priority)
    SELECT v_sms_channel, 'TWILIO', 'Twilio', 'SMS delivery via Twilio API.', 'https://api.twilio.com', TRUE, 1
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_providers WHERE provider_code = 'TWILIO');

    INSERT INTO notifications.notification_providers (notification_channel_id, provider_code, provider_name, description, is_primary, priority)
    SELECT (SELECT notification_channel_id FROM notifications.notification_channel_lookup WHERE code = 'WHATSAPP'),
           'WHATSAPP_BUSINESS', 'WhatsApp Business', 'WhatsApp via Meta Business API.', TRUE, 1
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_providers WHERE provider_code = 'WHATSAPP_BUSINESS');

    INSERT INTO notifications.notification_providers (notification_channel_id, provider_code, provider_name, description, is_primary, priority)
    SELECT (SELECT notification_channel_id FROM notifications.notification_channel_lookup WHERE code = 'PUSH'),
           'FIREBASE_FCM', 'Firebase Cloud Messaging', 'Push notifications via Firebase.', TRUE, 1
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_providers WHERE provider_code = 'FIREBASE_FCM');

    -- Create default templates
    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, subject_template, body_template, locale)
    SELECT v_company_id, v_email_channel, v_transactional_type, 'ORDER_CONFIRMATION', 'Order Confirmation Email',
           'Order Confirmation - {{order_number}}',
           'Dear {{customer_name}},\n\nThank you for your order {{order_number}}.\n\nOrder Total: {{order_total}}\n\nWe will notify you when your order ships.\n\nThank you,\neStore',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'ORDER_CONFIRMATION');

    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, subject_template, body_template, locale)
    SELECT v_company_id, v_email_channel, v_transactional_type, 'SHIPPING_UPDATE', 'Shipping Update Email',
           'Your Order {{order_number}} Has Shipped!',
           'Dear {{customer_name}},\n\nYour order {{order_number}} has been shipped.\n\nTracking Number: {{tracking_number}}\nCarrier: {{carrier_name}}\n\nTrack your package: {{tracking_url}}\n\nThank you,\neStore',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'SHIPPING_UPDATE');

    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, subject_template, body_template, locale)
    SELECT v_company_id, v_email_channel, v_transactional_type, 'PAYMENT_RECEIVED', 'Payment Received Email',
           'Payment Received - {{payment_reference}}',
           'Dear {{customer_name}},\n\nWe have received your payment of {{payment_amount}}.\n\nPayment Reference: {{payment_reference}}\nPayment Method: {{payment_method}}\n\nThank you,\neStore',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'PAYMENT_RECEIVED');

    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, subject_template, body_template, locale)
    SELECT v_company_id, v_email_channel, v_transactional_type, 'PASSWORD_RESET', 'Password Reset Email',
           'Reset Your Password',
           'Dear {{user_name}},\n\nYou requested a password reset.\n\nClick the link below to reset your password:\n{{reset_url}}\n\nThis link expires in {{expiry_hours}} hours.\n\nIf you did not request this, please ignore this email.\n\neStore Security',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'PASSWORD_RESET');

    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, subject_template, body_template, locale)
    SELECT v_company_id, v_email_channel, v_marketing_type, 'WEEKLY_NEWSLETTER', 'Weekly Newsletter',
           'This Week at eStore - {{week_date}}',
           'Dear {{customer_name}},\n\nHere are this week''s highlights:\n\n{{newsletter_content}}\n\nHappy Shopping!\neStore',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'WEEKLY_NEWSLETTER');

    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, sms_template, locale)
    SELECT v_company_id, v_sms_channel, v_transactional_type, 'ORDER_SMS', 'Order SMS',
           'eStore: Order {{order_number}} confirmed. Total: {{order_total}}. Track at {{tracking_url}}',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'ORDER_SMS');

    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, subject_template, body_template, locale)
    SELECT v_company_id, v_email_channel, (SELECT notification_type_id FROM notifications.notification_type_lookup WHERE code = 'LOYALTY'),
           'POINTS_EARNED', 'Points Earned Notification',
           'You Earned {{points_earned}} Points!',
           'Dear {{customer_name}},\n\nCongratulations! You earned {{points_earned}} points from your recent purchase.\n\nCurrent Balance: {{points_balance}} points\n\nKeep shopping to earn more!\n\neStore Rewards',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'POINTS_EARNED');

    INSERT INTO notifications.notification_templates (company_id, notification_channel_id, notification_type_id, template_code, template_name, subject_template, body_template, locale)
    SELECT v_company_id, v_email_channel, (SELECT notification_type_id FROM notifications.notification_type_lookup WHERE code = 'SECURITY'),
           'LOGIN_ALERT', 'Login Alert Email',
           'New Login Detected',
           'Dear {{user_name}},\n\nA new login was detected on your account.\n\nDevice: {{device_info}}\nLocation: {{location}}\nTime: {{login_time}}\n\nIf this was not you, please secure your account immediately.\n\neStore Security',
           'en'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_templates WHERE company_id = v_company_id AND template_code = 'LOGIN_ALERT');

    -- Create default preferences for marketing opt-in
    INSERT INTO notifications.notification_preferences (company_id, notification_channel_id, notification_type_id, preference_status_id)
    SELECT v_company_id, v_email_channel, v_marketing_type,
           (SELECT preference_status_id FROM notifications.preference_status_lookup WHERE code = 'OPTED_IN')
    WHERE NOT EXISTS (
        SELECT 1 FROM notifications.notification_preferences
        WHERE company_id = v_company_id AND notification_channel_id = v_email_channel AND notification_type_id = v_marketing_type
        AND customer_id IS NULL AND user_id IS NULL AND employee_id IS NULL
    );

    -- Create a digest configuration
    INSERT INTO notifications.notification_digests (company_id, notification_channel_id, digest_frequency_id, digest_name, description, send_time)
    SELECT v_company_id, v_email_channel,
           (SELECT digest_frequency_id FROM notifications.digest_frequency_lookup WHERE code = 'DAILY'),
           'Daily Activity Summary', 'Daily summary of orders, payments, and support activities.', '09:00:00'
    WHERE NOT EXISTS (SELECT 1 FROM notifications.notification_digests WHERE company_id = v_company_id AND digest_name = 'Daily Activity Summary');

END $$;

COMMIT;