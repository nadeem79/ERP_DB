BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 15 — ADVANCED CRM & CUSTOMER SERVICE
-- DATABASE TABLES
-- ============================================================
-- Components:
--   15.1  Leads & Lead Sources
--   15.2  Opportunities & Pipelines
--   15.3  Sales Teams
--   15.4  Activities (reuse crm.customer_interactions)
--   15.5  Support Tickets
--   15.6  Support Teams
--   15.7  SLA Management
--   15.8  Complaints
--   15.9  Customer Satisfaction
--   15.10 Knowledge Base
-- ============================================================

CREATE SCHEMA IF NOT EXISTS crm;
CREATE SCHEMA IF NOT EXISTS support;

-- ============================================================
-- 15.1 LEAD MANAGEMENT
-- ============================================================

-- Lead Source Lookup
CREATE TABLE IF NOT EXISTS crm.customer_lead_source_lookup (
    customer_lead_source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_lead_source_lookup (code, name, description, sort_order) VALUES
    ('WEBSITE', 'Website', 'Lead came from website inquiry form.', 10),
    ('PHONE', 'Phone', 'Lead came via phone call.', 20),
    ('EMAIL', 'Email', 'Lead came via email inquiry.', 30),
    ('SOCIAL_MEDIA', 'Social Media', 'Lead came from social media.', 40),
    ('REFERRAL', 'Referral', 'Lead came from customer referral.', 50),
    ('WALK_IN', 'Walk-in', 'Lead walked into store.', 60),
    ('MARKETPLACE', 'Marketplace', 'Lead came from marketplace.', 70),
    ('CAMPAIGN', 'Campaign', 'Lead came from marketing campaign.', 80),
    ('EXHIBITION', 'Exhibition', 'Lead came from trade show/exhibition.', 90),
    ('PARTNER', 'Partner', 'Lead came from business partner.', 100),
    ('OTHER', 'Other', 'Other lead source.', 110)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Lead Status Lookup
CREATE TABLE IF NOT EXISTS crm.customer_lead_status_lookup (
    customer_lead_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_lead_status_lookup (code, name, description, sort_order) VALUES
    ('NEW', 'New', 'Lead just received.', 10),
    ('CONTACTED', 'Contacted', 'Initial contact made.', 20),
    ('QUALIFIED', 'Qualified', 'Lead meets criteria.', 30),
    ('PROPOSAL_SENT', 'Proposal Sent', 'Proposal/quotation sent.', 40),
    ('NEGOTIATION', 'Negotiation', 'In negotiation phase.', 50),
    ('WON', 'Won', 'Lead converted to customer/order.', 60),
    ('LOST', 'Lost', 'Lead lost.', 70),
    ('DISQUALIFIED', 'Disqualified', 'Lead does not meet criteria.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Lead Quality Lookup
CREATE TABLE IF NOT EXISTS crm.customer_lead_quality_lookup (
    customer_lead_quality_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_lead_quality_lookup (code, name, description, sort_order) VALUES
    ('HOT', 'Hot', 'High probability of conversion.', 10),
    ('WARM', 'Warm', 'Moderate probability.', 20),
    ('COLD', 'Cold', 'Low probability.', 30),
    ('INVALID', 'Invalid', 'Invalid or spam lead.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Leads Table
CREATE TABLE IF NOT EXISTS crm.customer_leads (
    customer_lead_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_lead_source_id UUID NOT NULL,
    customer_lead_status_id UUID NOT NULL DEFAULT (SELECT customer_lead_status_id FROM crm.customer_lead_status_lookup WHERE code = 'NEW'),
    customer_lead_quality_id UUID NULL,
    assigned_to_employee_id UUID NULL,
    assigned_to_user_id UUID NULL,

    lead_number VARCHAR(50) NOT NULL,
    display_name VARCHAR(200) NOT NULL,
    first_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    company_name VARCHAR(200) NULL,
    email VARCHAR(300) NULL,
    phone VARCHAR(50) NULL,
    mobile VARCHAR(50) NULL,
    website_url VARCHAR(500) NULL,
    address_line1 VARCHAR(300) NULL,
    city VARCHAR(100) NULL,
    state_province VARCHAR(100) NULL,
    country_id UUID NULL,

    lead_score NUMERIC(6,2) NULL,
    estimated_value NUMERIC(19,4) NULL,
    currency_id UUID NULL,

    notes TEXT NULL,
    conversion_reason VARCHAR(500) NULL,
    lost_reason VARCHAR(500) NULL,

    first_contacted_at TIMESTAMPTZ NULL,
    last_contacted_at TIMESTAMPTZ NULL,
    qualified_at TIMESTAMPTZ NULL,
    converted_at TIMESTAMPTZ NULL,
    converted_customer_id UUID NULL,
    lost_at TIMESTAMPTZ NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_lead_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_lead_source FOREIGN KEY (customer_lead_source_id) REFERENCES crm.customer_lead_source_lookup(customer_lead_source_id),
    CONSTRAINT fk_lead_status FOREIGN KEY (customer_lead_status_id) REFERENCES crm.customer_lead_status_lookup(customer_lead_status_id),
    CONSTRAINT fk_lead_quality FOREIGN KEY (customer_lead_quality_id) REFERENCES crm.customer_lead_quality_lookup(customer_lead_quality_id),
    CONSTRAINT fk_lead_employee FOREIGN KEY (assigned_to_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_lead_country FOREIGN KEY (country_id) REFERENCES reference.country_lookup(country_id),
    CONSTRAINT fk_lead_customer FOREIGN KEY (converted_customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT uq_lead_number UNIQUE (company_id, lead_number)
);

CREATE INDEX ix_lead_company ON crm.customer_leads(company_id);
CREATE INDEX ix_lead_status ON crm.customer_leads(customer_lead_status_id);
CREATE INDEX ix_lead_source ON crm.customer_leads(customer_lead_source_id);
CREATE INDEX ix_lead_employee ON crm.customer_leads(assigned_to_employee_id);
CREATE INDEX ix_lead_created ON crm.customer_leads(created_at DESC);

-- ============================================================
-- 15.2 OPPORTUNITIES & PIPELINES
-- ============================================================

-- Sales Pipeline Lookup
CREATE TABLE IF NOT EXISTS crm.customer_pipeline_lookup (
    customer_pipeline_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_pipeline_code UNIQUE (company_id, code)
);

-- Pipeline Stage Lookup
CREATE TABLE IF NOT EXISTS crm.customer_pipeline_stage_lookup (
    customer_pipeline_stage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_pipeline_id UUID NOT NULL,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    stage_order INTEGER NOT NULL DEFAULT 0,
    probability_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    is_won_stage BOOLEAN NOT NULL DEFAULT FALSE,
    is_lost_stage BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT fk_stage_pipeline FOREIGN KEY (customer_pipeline_id) REFERENCES crm.customer_pipeline_lookup(customer_pipeline_id) ON DELETE CASCADE,
    CONSTRAINT uq_stage_code UNIQUE (customer_pipeline_id, code)
);

-- Opportunity Status Lookup
CREATE TABLE IF NOT EXISTS crm.customer_opportunity_status_lookup (
    customer_opportunity_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_opportunity_status_lookup (code, name, description, sort_order) VALUES
    ('OPEN', 'Open', 'Opportunity is active.', 10),
    ('WON', 'Won', 'Opportunity won - converted to order.', 20),
    ('LOST', 'Lost', 'Opportunity lost.', 30),
    ('ON_HOLD', 'On Hold', 'Opportunity on hold.', 40),
    ('CANCELLED', 'Cancelled', 'Opportunity cancelled.', 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Opportunity Lost Reason Lookup
CREATE TABLE IF NOT EXISTS crm.customer_opportunity_lost_reason_lookup (
    customer_opportunity_lost_reason_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO crm.customer_opportunity_lost_reason_lookup (code, name, description, sort_order) VALUES
    ('PRICE', 'Price Too High', 'Customer found better pricing.', 10),
    ('COMPETITOR', 'Lost to Competitor', 'Customer chose competitor.', 20),
    ('NO_BUDGET', 'No Budget', 'Customer has no budget.', 30),
    ('NO_NEED', 'No Longer Needed', 'Customer need changed.', 40),
    ('NO_RESPONSE', 'No Response', 'Customer stopped responding.', 50),
    ('PRODUCT_FIT', 'Product Not Fit', 'Product does not meet requirements.', 60),
    ('TIMING', 'Bad Timing', 'Wrong timing for customer.', 70),
    ('OTHER', 'Other', 'Other reason.', 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Opportunities Table
CREATE TABLE IF NOT EXISTS crm.customer_opportunities (
    customer_opportunity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    customer_pipeline_stage_id UUID NOT NULL,
    customer_opportunity_status_id UUID NOT NULL DEFAULT (SELECT customer_opportunity_status_id FROM crm.customer_opportunity_status_lookup WHERE code = 'OPEN'),
    customer_lead_id UUID NULL,
    customer_opportunity_lost_reason_id UUID NULL,
    assigned_to_employee_id UUID NULL,
    assigned_to_user_id UUID NULL,

    opportunity_number VARCHAR(50) NOT NULL,
    opportunity_name VARCHAR(300) NOT NULL,
    description TEXT NULL,

    estimated_value NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NULL,
    probability_percent NUMERIC(5,2) NOT NULL DEFAULT 0,

    expected_close_date DATE NULL,
    actual_close_date DATE NULL,
    won_at TIMESTAMPTZ NULL,
    lost_at TIMESTAMPTZ NULL,
    lost_reason_notes TEXT NULL,

    related_order_id UUID NULL,
    related_quotation_id UUID NULL,

    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_opp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_opp_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_opp_stage FOREIGN KEY (customer_pipeline_stage_id) REFERENCES crm.customer_pipeline_stage_lookup(customer_pipeline_stage_id),
    CONSTRAINT fk_opp_status FOREIGN KEY (customer_opportunity_status_id) REFERENCES crm.customer_opportunity_status_lookup(customer_opportunity_status_id),
    CONSTRAINT fk_opp_lead FOREIGN KEY (customer_lead_id) REFERENCES crm.customer_leads(customer_lead_id),
    CONSTRAINT fk_opp_lost_reason FOREIGN KEY (customer_opportunity_lost_reason_id) REFERENCES crm.customer_opportunity_lost_reason_lookup(customer_opportunity_lost_reason_id),
    CONSTRAINT fk_opp_employee FOREIGN KEY (assigned_to_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT uq_opp_number UNIQUE (company_id, opportunity_number)
);

CREATE INDEX ix_opp_company ON crm.customer_opportunities(company_id);
CREATE INDEX ix_opp_customer ON crm.customer_opportunities(customer_id);
CREATE INDEX ix_opp_stage ON crm.customer_opportunities(customer_pipeline_stage_id);
CREATE INDEX ix_opp_status ON crm.customer_opportunities(customer_opportunity_status_id);
CREATE INDEX ix_opp_employee ON crm.customer_opportunities(assigned_to_employee_id);
CREATE INDEX ix_opp_close_date ON crm.customer_opportunities(expected_close_date);

-- Opportunity Stage History
CREATE TABLE IF NOT EXISTS crm.customer_opportunity_stage_history (
    opportunity_stage_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_opportunity_id UUID NOT NULL,
    from_stage_id UUID NULL,
    to_stage_id UUID NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by_user_id UUID NULL,
    notes TEXT NULL,
    CONSTRAINT fk_osh_opportunity FOREIGN KEY (customer_opportunity_id) REFERENCES crm.customer_opportunities(customer_opportunity_id) ON DELETE CASCADE,
    CONSTRAINT fk_osh_from_stage FOREIGN KEY (from_stage_id) REFERENCES crm.customer_pipeline_stage_lookup(customer_pipeline_stage_id),
    CONSTRAINT fk_osh_to_stage FOREIGN KEY (to_stage_id) REFERENCES crm.customer_pipeline_stage_lookup(customer_pipeline_stage_id)
);

CREATE INDEX ix_osh_opportunity ON crm.customer_opportunity_stage_history(customer_opportunity_id);

-- Opportunity Items (Products in opportunity)
CREATE TABLE IF NOT EXISTS crm.customer_opportunity_items (
    opportunity_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_opportunity_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    quantity NUMERIC(19,4) NOT NULL DEFAULT 1,
    unit_price NUMERIC(19,4) NOT NULL DEFAULT 0,
    discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(19,4) NOT NULL DEFAULT 0,
    currency_id UUID NULL,
    notes TEXT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT fk_oi_opportunity FOREIGN KEY (customer_opportunity_id) REFERENCES crm.customer_opportunities(customer_opportunity_id) ON DELETE CASCADE,
    CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id)
);

CREATE INDEX ix_oi_opportunity ON crm.customer_opportunity_items(customer_opportunity_id);

-- ============================================================
-- 15.3 SALES TEAMS
-- ============================================================

CREATE TABLE IF NOT EXISTS crm.customer_sales_teams (
    customer_sales_team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    team_code VARCHAR(50) NOT NULL,
    team_name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    team_lead_employee_id UUID NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_team_code UNIQUE (company_id, team_code),
    CONSTRAINT fk_team_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_team_lead FOREIGN KEY (team_lead_employee_id) REFERENCES identity.employees(employee_id)
);

CREATE TABLE IF NOT EXISTS crm.customer_sales_team_members (
    sales_team_member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_sales_team_id UUID NOT NULL,
    employee_id UUID NOT NULL,
    role_in_team VARCHAR(50) NOT NULL DEFAULT 'MEMBER',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    joined_at DATE NOT NULL DEFAULT CURRENT_DATE,
    left_at DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_team_member UNIQUE (customer_sales_team_id, employee_id),
    CONSTRAINT fk_stm_team FOREIGN KEY (customer_sales_team_id) REFERENCES crm.customer_sales_teams(customer_sales_team_id) ON DELETE CASCADE,
    CONSTRAINT fk_stm_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id)
);

-- ============================================================
-- 15.5 SUPPORT TICKETS
-- ============================================================

-- Ticket Category Lookup
CREATE TABLE IF NOT EXISTS support.ticket_category_lookup (
    ticket_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    parent_category_id UUID NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO support.ticket_category_lookup (code, name, description, sort_order) VALUES
    ('ORDER', 'Order Issue', 'Issues related to orders.', 10),
    ('DELIVERY', 'Delivery Issue', 'Issues related to delivery/shipping.', 20),
    ('PRODUCT', 'Product Issue', 'Issues with product quality/defect.', 30),
    ('PAYMENT', 'Payment Issue', 'Issues related to payments.', 40),
    ('RETURN', 'Return Issue', 'Issues related to returns.', 50),
    ('ACCOUNT', 'Account Issue', 'Issues with customer account.', 60),
    ('BILLING', 'Billing Issue', 'Issues related to billing/invoices.', 70),
    ('TECHNICAL', 'Technical Issue', 'Technical/system issues.', 80),
    ('GENERAL', 'General Inquiry', 'General questions and inquiries.', 90),
    ('COMPLAINT', 'Complaint', 'Formal customer complaint.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Ticket Priority Lookup
CREATE TABLE IF NOT EXISTS support.ticket_priority_lookup (
    ticket_priority_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    response_time_minutes INTEGER NULL,
    resolution_time_minutes INTEGER NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO support.ticket_priority_lookup (code, name, description, response_time_minutes, resolution_time_minutes, sort_order) VALUES
    ('LOW', 'Low', 'Non-urgent issue.', 480, 2880, 10),
    ('MEDIUM', 'Medium', 'Standard priority.', 240, 1440, 20),
    ('HIGH', 'High', 'Urgent issue.', 60, 480, 30),
    ('URGENT', 'Urgent', 'Very urgent.', 30, 240, 40),
    ('CRITICAL', 'Critical', 'System down / critical.', 15, 120, 50)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, response_time_minutes = EXCLUDED.response_time_minutes, resolution_time_minutes = EXCLUDED.resolution_time_minutes, sort_order = EXCLUDED.sort_order;

-- Ticket Status Lookup
CREATE TABLE IF NOT EXISTS support.ticket_status_lookup (
    ticket_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO support.ticket_status_lookup (code, name, description, is_open, sort_order) VALUES
    ('OPEN', 'Open', 'Ticket is open and awaiting response.', TRUE, 10),
    ('IN_PROGRESS', 'In Progress', 'Agent is working on the ticket.', TRUE, 20),
    ('PENDING_CUSTOMER', 'Pending Customer', 'Waiting for customer response.', TRUE, 30),
    ('PENDING_INTERNAL', 'Pending Internal', 'Waiting for internal team.', TRUE, 40),
    ('ESCALATED', 'Escalated', 'Ticket escalated to higher team.', TRUE, 50),
    ('RESOLVED', 'Resolved', 'Issue resolved, awaiting confirmation.', FALSE, 60),
    ('CLOSED', 'Closed', 'Ticket closed.', FALSE, 70),
    ('REOPENED', 'Reopened', 'Ticket reopened after resolution.', TRUE, 80)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, is_open = EXCLUDED.is_open, sort_order = EXCLUDED.sort_order;

-- Ticket Channel Lookup
CREATE TABLE IF NOT EXISTS support.ticket_channel_lookup (
    ticket_channel_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO support.ticket_channel_lookup (code, name, description, sort_order) VALUES
    ('EMAIL', 'Email', 'Ticket created via email.', 10),
    ('PHONE', 'Phone', 'Ticket created via phone call.', 20),
    ('CHAT', 'Chat', 'Ticket created via live chat.', 30),
    ('WEB_PORTAL', 'Web Portal', 'Ticket created via customer portal.', 40),
    ('WHATSAPP', 'WhatsApp', 'Ticket created via WhatsApp.', 50),
    ('SOCIAL_MEDIA', 'Social Media', 'Ticket created via social media.', 60),
    ('WALK_IN', 'Walk-in', 'Ticket created at physical store.', 70),
    ('INTERNAL', 'Internal', 'Ticket created internally.', 80),
    ('SYSTEM', 'System', 'Ticket auto-created by system.', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- Support Tickets Table
CREATE TABLE IF NOT EXISTS support.tickets (
    ticket_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    ticket_category_id UUID NOT NULL,
    ticket_priority_id UUID NOT NULL,
    ticket_status_id UUID NOT NULL DEFAULT (SELECT ticket_status_id FROM support.ticket_status_lookup WHERE code = 'OPEN'),
    ticket_channel_id UUID NOT NULL,
    customer_service_case_id UUID NULL,
    assigned_to_employee_id UUID NULL,
    assigned_to_user_id UUID NULL,
    assigned_team_id UUID NULL,

    ticket_number VARCHAR(50) NOT NULL,
    subject VARCHAR(500) NOT NULL,
    description TEXT NULL,

    related_order_id UUID NULL,
    related_shipment_id UUID NULL,
    related_return_request_id UUID NULL,
    related_payment_id UUID NULL,
    related_product_id UUID NULL,

    first_response_at TIMESTAMPTZ NULL,
    first_response_by_user_id UUID NULL,
    last_response_at TIMESTAMPTZ NULL,
    resolved_at TIMESTAMPTZ NULL,
    resolved_by_user_id UUID NULL,
    closed_at TIMESTAMPTZ NULL,
    reopened_at TIMESTAMPTZ NULL,
    due_date TIMESTAMPTZ NULL,

    customer_satisfaction_score INTEGER NULL,
    customer_feedback TEXT NULL,

    is_escalated BOOLEAN NOT NULL DEFAULT FALSE,
    escalation_level INTEGER NOT NULL DEFAULT 0,
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,

    tags TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_ticket_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ticket_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ticket_category FOREIGN KEY (ticket_category_id) REFERENCES support.ticket_category_lookup(ticket_category_id),
    CONSTRAINT fk_ticket_priority FOREIGN KEY (ticket_priority_id) REFERENCES support.ticket_priority_lookup(ticket_priority_id),
    CONSTRAINT fk_ticket_status FOREIGN KEY (ticket_status_id) REFERENCES support.ticket_status_lookup(ticket_status_id),
    CONSTRAINT fk_ticket_channel FOREIGN KEY (ticket_channel_id) REFERENCES support.ticket_channel_lookup(ticket_channel_id),
    CONSTRAINT fk_ticket_employee FOREIGN KEY (assigned_to_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT uq_ticket_number UNIQUE (company_id, ticket_number)
);

CREATE INDEX ix_ticket_company ON support.tickets(company_id);
CREATE INDEX ix_ticket_customer ON support.tickets(customer_id);
CREATE INDEX ix_ticket_status ON support.tickets(ticket_status_id);
CREATE INDEX ix_ticket_priority ON support.tickets(ticket_priority_id);
CREATE INDEX ix_ticket_category ON support.tickets(ticket_category_id);
CREATE INDEX ix_ticket_employee ON support.tickets(assigned_to_employee_id);
CREATE INDEX ix_ticket_created ON support.tickets(created_at DESC);

-- Ticket Messages (Conversation)
CREATE TABLE IF NOT EXISTS support.ticket_messages (
    ticket_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    sender_type VARCHAR(20) NOT NULL,
    sender_user_id UUID NULL,
    sender_employee_id UUID NULL,
    message_body TEXT NOT NULL,
    is_internal_note BOOLEAN NOT NULL DEFAULT FALSE,
    is_html BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tm_ticket FOREIGN KEY (ticket_id) REFERENCES support.tickets(ticket_id) ON DELETE CASCADE,
    CONSTRAINT ck_tm_sender CHECK (sender_type IN ('CUSTOMER', 'AGENT', 'SYSTEM'))
);

CREATE INDEX ix_tm_ticket ON support.ticket_messages(ticket_id);
CREATE INDEX ix_tm_sent ON support.ticket_messages(sent_at DESC);

-- Ticket Attachments
CREATE TABLE IF NOT EXISTS support.ticket_attachments (
    ticket_attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_message_id UUID NOT NULL,
    file_name VARCHAR(500) NOT NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,
    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ta_message FOREIGN KEY (ticket_message_id) REFERENCES support.ticket_messages(ticket_message_id) ON DELETE CASCADE
);

-- Ticket Status History
CREATE TABLE IF NOT EXISTS support.ticket_status_history (
    ticket_status_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    from_status_id UUID NULL,
    to_status_id UUID NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by_user_id UUID NULL,
    notes TEXT NULL,
    CONSTRAINT fk_tsh_ticket FOREIGN KEY (ticket_id) REFERENCES support.tickets(ticket_id) ON DELETE CASCADE,
    CONSTRAINT fk_tsh_from FOREIGN KEY (from_status_id) REFERENCES support.ticket_status_lookup(ticket_status_id),
    CONSTRAINT fk_tsh_to FOREIGN KEY (to_status_id) REFERENCES support.ticket_status_lookup(ticket_status_id)
);

-- ============================================================
-- 15.6 SUPPORT TEAMS
-- ============================================================

CREATE TABLE IF NOT EXISTS support.support_teams (
    support_team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    team_code VARCHAR(50) NOT NULL,
    team_name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    team_lead_employee_id UUID NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_support_team_code UNIQUE (company_id, team_code),
    CONSTRAINT fk_support_team_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_support_team_lead FOREIGN KEY (team_lead_employee_id) REFERENCES identity.employees(employee_id)
);

CREATE TABLE IF NOT EXISTS support.support_team_members (
    support_team_member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    support_team_id UUID NOT NULL,
    employee_id UUID NOT NULL,
    role_in_team VARCHAR(50) NOT NULL DEFAULT 'AGENT',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    max_concurrent_tickets INTEGER NULL,
    joined_at DATE NOT NULL DEFAULT CURRENT_DATE,
    left_at DATE NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_support_team_member UNIQUE (support_team_id, employee_id),
    CONSTRAINT fk_stm2_team FOREIGN KEY (support_team_id) REFERENCES support.support_teams(support_team_id) ON DELETE CASCADE,
    CONSTRAINT fk_stm2_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id)
);

-- ============================================================
-- 15.7 SLA MANAGEMENT
-- ============================================================

CREATE TABLE IF NOT EXISTS support.sla_policies (
    sla_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    policy_code VARCHAR(50) NOT NULL,
    policy_name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    ticket_category_id UUID NULL,
    ticket_priority_id UUID NULL,
    first_response_time_minutes INTEGER NOT NULL,
    resolution_time_minutes INTEGER NOT NULL,
    business_hours_only BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_sla_code UNIQUE (company_id, policy_code),
    CONSTRAINT fk_sla_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_sla_category FOREIGN KEY (ticket_category_id) REFERENCES support.ticket_category_lookup(ticket_category_id),
    CONSTRAINT fk_sla_priority FOREIGN KEY (ticket_priority_id) REFERENCES support.ticket_priority_lookup(ticket_priority_id)
);

CREATE TABLE IF NOT EXISTS support.sla_tracking (
    sla_tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL,
    sla_policy_id UUID NOT NULL,
    first_response_deadline TIMESTAMPTZ NULL,
    first_response_actual TIMESTAMPTZ NULL,
    first_response_met BOOLEAN NULL,
    resolution_deadline TIMESTAMPTZ NULL,
    resolution_actual TIMESTAMPTZ NULL,
    resolution_met BOOLEAN NULL,
    breached_at TIMESTAMPTZ NULL,
    is_breached BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT fk_slat_ticket FOREIGN KEY (ticket_id) REFERENCES support.tickets(ticket_id) ON DELETE CASCADE,
    CONSTRAINT fk_slat_policy FOREIGN KEY (sla_policy_id) REFERENCES support.sla_policies(sla_policy_id)
);

-- Escalation Rules
CREATE TABLE IF NOT EXISTS support.escalation_rules (
    escalation_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    sla_policy_id UUID NOT NULL,
    escalation_level INTEGER NOT NULL DEFAULT 1,
    trigger_after_minutes INTEGER NOT NULL,
    escalate_to_employee_id UUID NULL,
    escalate_to_team_id UUID NULL,
    notification_type VARCHAR(50) NOT NULL DEFAULT 'EMAIL',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_er_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_er_sla FOREIGN KEY (sla_policy_id) REFERENCES support.sla_policies(sla_policy_id) ON DELETE CASCADE,
    CONSTRAINT fk_er_employee FOREIGN KEY (escalate_to_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT fk_er_team FOREIGN KEY (escalate_to_team_id) REFERENCES support.support_teams(support_team_id)
);

-- ============================================================
-- 15.8 COMPLAINTS
-- ============================================================

CREATE TABLE IF NOT EXISTS support.complaint_root_cause_lookup (
    complaint_root_cause_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO support.complaint_root_cause_lookup (code, name, description, sort_order) VALUES
    ('PRODUCT_DEFECT', 'Product Defect', 'Product arrived damaged/defective.', 10),
    ('WRONG_PRODUCT', 'Wrong Product', 'Wrong product delivered.', 20),
    ('LATE_DELIVERY', 'Late Delivery', 'Delivery was delayed.', 30),
    ('MISSING_ITEMS', 'Missing Items', 'Items missing from order.', 40),
    ('BILLING_ERROR', 'Billing Error', 'Incorrect charge or billing issue.', 50),
    ('SERVICE_QUALITY', 'Service Quality', 'Poor customer service experience.', 60),
    ('COMMUNICATION', 'Communication', 'Lack of communication/updates.', 70),
    ('WEBSITE_ISSUE', 'Website Issue', 'Technical issue with website.', 80),
    ('OTHER', 'Other', 'Other root cause.', 90)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

CREATE TABLE IF NOT EXISTS support.complaint_resolution_lookup (
    complaint_resolution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO support.complaint_resolution_lookup (code, name, description, sort_order) VALUES
    ('REFUND', 'Refund', 'Full or partial refund issued.', 10),
    ('REPLACEMENT', 'Replacement', 'Product replaced.', 20),
    ('EXCHANGE', 'Exchange', 'Product exchanged.', 30),
    ('CREDIT_NOTE', 'Credit Note', 'Store credit issued.', 40),
    ('DISCOUNT', 'Discount', 'Discount on future purchase.', 50),
    ('APOLOGY', 'Apology', 'Formal apology issued.', 60),
    ('PROCESS_FIX', 'Process Fix', 'Internal process corrected.', 70),
    ('NO_ACTION', 'No Action', 'No action required.', 80),
    ('ESCALATED', 'Escalated', 'Escalated to management.', 90),
    ('OTHER', 'Other', 'Other resolution.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

CREATE TABLE IF NOT EXISTS support.complaints (
    complaint_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    ticket_id UUID NULL,
    complaint_root_cause_id UUID NULL,
    complaint_resolution_id UUID NULL,
    assigned_to_employee_id UUID NULL,

    complaint_number VARCHAR(50) NOT NULL,
    subject VARCHAR(500) NOT NULL,
    description TEXT NULL,

    related_order_id UUID NULL,
    related_product_id UUID NULL,

    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMPTZ NULL,
    resolved_at TIMESTAMPTZ NULL,
    closed_at TIMESTAMPTZ NULL,

    resolution_notes TEXT NULL,
    preventive_action TEXT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_comp_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_comp_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_comp_ticket FOREIGN KEY (ticket_id) REFERENCES support.tickets(ticket_id),
    CONSTRAINT fk_comp_root_cause FOREIGN KEY (complaint_root_cause_id) REFERENCES support.complaint_root_cause_lookup(complaint_root_cause_id),
    CONSTRAINT fk_comp_resolution FOREIGN KEY (complaint_resolution_id) REFERENCES support.complaint_resolution_lookup(complaint_resolution_id),
    CONSTRAINT fk_comp_employee FOREIGN KEY (assigned_to_employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT ck_comp_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_comp_status CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'INVESTIGATING', 'RESOLVED', 'CLOSED', 'REOPENED')),
    CONSTRAINT uq_complaint_number UNIQUE (company_id, complaint_number)
);

CREATE INDEX ix_comp_customer ON support.complaints(customer_id);
CREATE INDEX ix_comp_status ON support.complaints(status);
CREATE INDEX ix_comp_severity ON support.complaints(severity);

-- ============================================================
-- 15.9 CUSTOMER SATISFACTION
-- ============================================================

CREATE TABLE IF NOT EXISTS support.customer_satisfaction_surveys (
    satisfaction_survey_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    ticket_id UUID NULL,
    related_order_id UUID NULL,

    survey_type VARCHAR(30) NOT NULL DEFAULT 'POST_TICKET',
    overall_score INTEGER NULL,
    product_quality_score INTEGER NULL,
    delivery_score INTEGER NULL,
    service_score INTEGER NULL,
    communication_score INTEGER NULL,
    value_for_money_score INTEGER NULL,

    would_recommend BOOLEAN NULL,
    feedback TEXT NULL,
    improvements TEXT NULL,

    submitted_at TIMESTAMPTZ NULL,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_css_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_css_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_css_ticket FOREIGN KEY (ticket_id) REFERENCES support.tickets(ticket_id),
    CONSTRAINT ck_css_type CHECK (survey_type IN ('POST_TICKET', 'POST_ORDER', 'POST_RETURN', 'PERIODIC', 'GENERAL')),
    CONSTRAINT ck_css_score CHECK (overall_score IS NULL OR (overall_score >= 1 AND overall_score <= 5))
);

CREATE INDEX ix_css_customer ON support.customer_satisfaction_surveys(customer_id);
CREATE INDEX ix_css_ticket ON support.customer_satisfaction_surveys(ticket_id);

-- ============================================================
-- 15.10 KNOWLEDGE BASE
-- ============================================================

CREATE TABLE IF NOT EXISTS support.knowledge_base_categories (
    knowledge_base_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    parent_category_id UUID NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,
    CONSTRAINT fk_kbc_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_kbc_parent FOREIGN KEY (parent_category_id) REFERENCES support.knowledge_base_categories(knowledge_base_category_id)
);

CREATE TABLE IF NOT EXISTS support.knowledge_base_articles (
    knowledge_base_article_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    knowledge_base_category_id UUID NOT NULL,
    author_user_id UUID NULL,

    title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) NOT NULL,
    summary TEXT NULL,
    content TEXT NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    view_count INTEGER NOT NULL DEFAULT 0,
    helpful_count INTEGER NOT NULL DEFAULT 0,
    not_helpful_count INTEGER NOT NULL DEFAULT 0,

    published_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_kba_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_kba_category FOREIGN KEY (knowledge_base_category_id) REFERENCES support.knowledge_base_categories(knowledge_base_category_id),
    CONSTRAINT ck_kba_status CHECK (status IN ('DRAFT', 'REVIEW', 'PUBLISHED', 'ARCHIVED'))
);

CREATE INDEX ix_kba_category ON support.knowledge_base_articles(knowledge_base_category_id);
CREATE INDEX ix_kba_status ON support.knowledge_base_articles(status);

CREATE TABLE IF NOT EXISTS support.knowledge_base_feedback (
    knowledge_base_feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    knowledge_base_article_id UUID NOT NULL,
    customer_id UUID NULL,
    user_id UUID NULL,
    was_helpful BOOLEAN NOT NULL,
    comment TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kbf_article FOREIGN KEY (knowledge_base_article_id) REFERENCES support.knowledge_base_articles(knowledge_base_article_id) ON DELETE CASCADE
);

-- ============================================================
-- SEED DATA: Pipeline, Teams, SLA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
    v_pipeline_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Create default sales pipeline
    INSERT INTO crm.customer_pipeline_lookup (company_id, code, name, description, is_default)
    SELECT v_company_id, 'STANDARD', 'Standard Sales Pipeline', 'Default sales pipeline for all opportunities.', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM crm.customer_pipeline_lookup WHERE company_id = v_company_id AND code = 'STANDARD')
    RETURNING customer_pipeline_id INTO v_pipeline_id;

    IF v_pipeline_id IS NULL THEN
        SELECT customer_pipeline_id INTO v_pipeline_id FROM crm.customer_pipeline_lookup WHERE company_id = v_company_id AND code = 'STANDARD';
    END IF;

    -- Create pipeline stages
    INSERT INTO crm.customer_pipeline_stage_lookup (customer_pipeline_id, code, name, stage_order, probability_percent)
    SELECT v_pipeline_id, 'PROSPECT', 'Prospect', 10, 10.00
    WHERE NOT EXISTS (SELECT 1 FROM crm.customer_pipeline_stage_lookup WHERE customer_pipeline_id = v_pipeline_id AND code = 'PROSPECT');

    INSERT INTO crm.customer_pipeline_stage_lookup (customer_pipeline_id, code, name, stage_order, probability_percent)
    SELECT v_pipeline_id, 'QUALIFIED', 'Qualified', 20, 25.00
    WHERE NOT EXISTS (SELECT 1 FROM crm.customer_pipeline_stage_lookup WHERE customer_pipeline_id = v_pipeline_id AND code = 'QUALIFIED');

    INSERT INTO crm.customer_pipeline_stage_lookup (customer_pipeline_id, code, name, stage_order, probability_percent)
    SELECT v_pipeline_id, 'PROPOSAL', 'Proposal Sent', 30, 50.00
    WHERE NOT EXISTS (SELECT 1 FROM crm.customer_pipeline_stage_lookup WHERE customer_pipeline_id = v_pipeline_id AND code = 'PROPOSAL');

    INSERT INTO crm.customer_pipeline_stage_lookup (customer_pipeline_id, code, name, stage_order, probability_percent)
    SELECT v_pipeline_id, 'NEGOTIATION', 'Negotiation', 40, 70.00
    WHERE NOT EXISTS (SELECT 1 FROM crm.customer_pipeline_stage_lookup WHERE customer_pipeline_id = v_pipeline_id AND code = 'NEGOTIATION');

    INSERT INTO crm.customer_pipeline_stage_lookup (customer_pipeline_id, code, name, stage_order, probability_percent, is_won_stage)
    SELECT v_pipeline_id, 'WON', 'Won', 50, 100.00, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM crm.customer_pipeline_stage_lookup WHERE customer_pipeline_id = v_pipeline_id AND code = 'WON');

    INSERT INTO crm.customer_pipeline_stage_lookup (customer_pipeline_id, code, name, stage_order, probability_percent, is_lost_stage)
    SELECT v_pipeline_id, 'LOST', 'Lost', 60, 0.00, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM crm.customer_pipeline_stage_lookup WHERE customer_pipeline_id = v_pipeline_id AND code = 'LOST');

    -- Create default support team
    INSERT INTO support.support_teams (company_id, team_code, team_name, description)
    SELECT v_company_id, 'SUPPORT-MAIN', 'Main Support Team', 'Primary customer support team.'
    WHERE NOT EXISTS (SELECT 1 FROM support.support_teams WHERE company_id = v_company_id AND team_code = 'SUPPORT-MAIN');

    -- Create default SLA policy
    INSERT INTO support.sla_policies (company_id, policy_code, policy_name, description, first_response_time_minutes, resolution_time_minutes)
    SELECT v_company_id, 'SLA-STANDARD', 'Standard SLA', 'Standard SLA for all tickets.', 240, 1440
    WHERE NOT EXISTS (SELECT 1 FROM support.sla_policies WHERE company_id = v_company_id AND policy_code = 'SLA-STANDARD');

    -- Create knowledge base categories
    INSERT INTO support.knowledge_base_categories (company_id, name, description, sort_order)
    SELECT v_company_id, 'Orders', 'Help with orders.', 10
    WHERE NOT EXISTS (SELECT 1 FROM support.knowledge_base_categories WHERE company_id = v_company_id AND name = 'Orders');

    INSERT INTO support.knowledge_base_categories (company_id, name, description, sort_order)
    SELECT v_company_id, 'Payments', 'Help with payments.', 20
    WHERE NOT EXISTS (SELECT 1 FROM support.knowledge_base_categories WHERE company_id = v_company_id AND name = 'Payments');

    INSERT INTO support.knowledge_base_categories (company_id, name, description, sort_order)
    SELECT v_company_id, 'Returns', 'Help with returns and refunds.', 30
    WHERE NOT EXISTS (SELECT 1 FROM support.knowledge_base_categories WHERE company_id = v_company_id AND name = 'Returns');

    INSERT INTO support.knowledge_base_categories (company_id, name, description, sort_order)
    SELECT v_company_id, 'Shipping', 'Help with shipping and delivery.', 40
    WHERE NOT EXISTS (SELECT 1 FROM support.knowledge_base_categories WHERE company_id = v_company_id AND name = 'Shipping');

    INSERT INTO support.knowledge_base_categories (company_id, name, description, sort_order)
    SELECT v_company_id, 'Products', 'Help with products.', 50
    WHERE NOT EXISTS (SELECT 1 FROM support.knowledge_base_categories WHERE company_id = v_company_id AND name = 'Products');

    INSERT INTO support.knowledge_base_categories (company_id, name, description, sort_order)
    SELECT v_company_id, 'Account', 'Help with account management.', 60
    WHERE NOT EXISTS (SELECT 1 FROM support.knowledge_base_categories WHERE company_id = v_company_id AND name = 'Account');

END $$;

COMMIT;