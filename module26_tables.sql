BEGIN;

-- ============================================================
-- ============================================================
-- MODULE 26 — REVIEWS, RATINGS & USER-GENERATED CONTENT
-- DATABASE TABLES
-- ============================================================
-- Design Decisions:
--   1. Review ≠ Product — Reviews belong to their own module
--   2. Review ≠ Order — Order proves purchase; Review records opinion
--   3. Verified purchase must be transaction-derived
--   4. Rating summary is a read model — Reviews are authoritative
--   5. Customer media uses existing storage
--   6. Rewards use Loyalty — Don't create a second points system
--   7. Review delivery uses Notification — Don't create another engine
--   8. Review revenue doesn't exist — Revenue stays in Orders/Payments
--   9. Reviews can drive quality analytics
--   10. Don't permanently delete review history
-- ============================================================
-- Components:
--   26.1  Reviews
--   26.2  Review Media (Photos/Videos)
--   26.3  Review Versions
--   26.4  Review Moderation
--   26.5  Review Votes (Helpful)
--   26.6  Review Invitations
--   26.7  Review Incentives
--   26.8  Fraud/Risk
--   26.9  Rating Summaries (Read Model)
--   26.10 Questions & Answers
--   26.11 Complaints (linked to Reviews)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS reviews;

-- ============================================================
-- 26.0 REVIEWS LOOKUPS
-- ============================================================

-- Review Entity Type
CREATE TABLE IF NOT EXISTS reviews.review_entity_type_lookup (
    review_entity_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO reviews.review_entity_type_lookup (code, name, description, sort_order) VALUES
    ('PRODUCT', 'Product', 'Review for a specific product.', 10),
    ('PRODUCT_VARIANT', 'Product Variant', 'Review for a specific product variant.', 20),
    ('SELLER', 'Seller', 'Review for a seller/vendor.', 30),
    ('STORE', 'Store', 'Review for a physical/online store.', 40),
    ('SERVICE', 'Service', 'Review for a service experience.', 50),
    ('DELIVERY', 'Delivery', 'Review for delivery experience.', 60)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Review Status
CREATE TABLE IF NOT EXISTS reviews.review_status_lookup (
    review_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_visible_public BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO reviews.review_status_lookup (code, name, description, is_visible_public, sort_order) VALUES
    ('DRAFT', 'Draft', 'Customer is still writing the review.', FALSE, 10),
    ('PENDING_MODERATION', 'Pending Moderation', 'Review submitted, awaiting moderation.', FALSE, 20),
    ('APPROVED', 'Approved', 'Review approved and visible.', TRUE, 30),
    ('REJECTED', 'Rejected', 'Review rejected by moderator.', FALSE, 40),
    ('FLAGGED', 'Flagged', 'Review flagged for investigation.', FALSE, 50),
    ('REMOVED', 'Removed', 'Review removed (policy violation).', FALSE, 60),
    ('HIDDEN', 'Hidden', 'Review hidden by customer.', FALSE, 70)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, is_visible_public = EXCLUDED.is_visible_public;

-- Review Moderation Action
CREATE TABLE IF NOT EXISTS reviews.review_moderation_action_lookup (
    review_moderation_action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO reviews.review_moderation_action_lookup (code, name, description, sort_order) VALUES
    ('SUBMITTED', 'Submitted', 'Review submitted by customer.', 10),
    ('AUTO_APPROVED', 'Auto Approved', 'Automatically approved by system.', 20),
    ('APPROVED', 'Approved', 'Manually approved by moderator.', 30),
    ('REJECTED', 'Rejected', 'Rejected by moderator.', 40),
    ('FLAGGED', 'Flagged', 'Flagged for further review.', 50),
    ('ESCALATED', 'Escalated', 'Escalated to senior moderator.', 60),
    ('REMOVED', 'Removed', 'Removed due to policy violation.', 70),
    ('RESTORED', 'Restored', 'Previously removed review restored.', 80),
    ('EDITED', 'Edited', 'Review edited by customer.', 90),
    ('RESPONDED', 'Responded', 'Seller/store responded to review.', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Review Incentive Type
CREATE TABLE IF NOT EXISTS reviews.review_incentive_type_lookup (
    review_incentive_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO reviews.review_incentive_type_lookup (code, name, description, sort_order) VALUES
    ('LOYALTY_POINTS', 'Loyalty Points', 'Award loyalty points for review.', 10),
    ('DISCOUNT_COUPON', 'Discount Coupon', 'Award discount coupon for review.', 20),
    ('STORE_CREDIT', 'Store Credit', 'Award store credit for review.', 30),
    ('ENTRY_DRAW', 'Entry to Draw', 'Entry into prize draw for review.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Fraud Signal Type
CREATE TABLE IF NOT EXISTS reviews.fraud_signal_type_lookup (
    fraud_signal_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO reviews.fraud_signal_type_lookup (code, name, description, severity, sort_order) VALUES
    ('SPAM_CONTENT', 'Spam Content', 'Review contains spam/advertising.', 'HIGH', 10),
    ('FAKE_REVIEW', 'Fake Review', 'Suspected fake/manufactured review.', 'CRITICAL', 20),
    ('DUPLICATE_REVIEW', 'Duplicate Review', 'Duplicate or near-duplicate review.', 'MEDIUM', 30),
    ('SELF_REVIEW', 'Self Review', 'Customer reviewing own product/order.', 'HIGH', 40),
    ('INCENTIVIZED_BIAS', 'Incentivized Bias', 'Review appears biased due to incentive.', 'MEDIUM', 50),
    ('COMPETITOR_ATTACK', 'Competitor Attack', 'Suspected competitor negative review.', 'HIGH', 60),
    ('ABUSIVE_LANGUAGE', 'Abusive Language', 'Review contains abusive content.', 'HIGH', 70),
    ('IRRELEVANT_CONTENT', 'Irrelevant Content', 'Review content not relevant to product.', 'LOW', 80),
    ('UNVERIFIED_CLAIM', 'Unverified Claim', 'Claims without purchase verification.', 'MEDIUM', 90),
    ('RAPID_FIRE', 'Rapid Fire', 'Multiple reviews in short time period.', 'HIGH', 100)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, severity = EXCLUDED.severity;

-- Question Status
CREATE TABLE IF NOT EXISTS reviews.question_status_lookup (
    question_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL
);

INSERT INTO reviews.question_status_lookup (code, name, description, sort_order) VALUES
    ('PENDING', 'Pending', 'Question awaiting answer.', 10),
    ('ANSWERED', 'Answered', 'Question has been answered.', 20),
    ('CLOSED', 'Closed', 'Question closed.', 30),
    ('REMOVED', 'Removed', 'Question removed.', 40)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- ============================================================
-- 26.1 REVIEWS
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.reviews (
    review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    review_entity_type_id UUID NOT NULL,
    review_status_id UUID NOT NULL DEFAULT (SELECT review_status_id FROM reviews.review_status_lookup WHERE code = 'DRAFT'),

    entity_id UUID NOT NULL,
    product_id UUID NULL,
    product_variant_id UUID NULL,
    order_id UUID NULL,
    order_item_id UUID NULL,

    customer_id UUID NULL,
    user_id UUID NULL,

    reviewer_name VARCHAR(200) NULL,
    reviewer_email VARCHAR(300) NULL,
    reviewer_location VARCHAR(200) NULL,

    rating INTEGER NOT NULL,
    title VARCHAR(300) NULL,
    review_text TEXT NULL,

    pros TEXT NULL,
    cons TEXT NULL,

    is_verified_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    verified_purchase_checked_at TIMESTAMPTZ NULL,

    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    is_incentivized BOOLEAN NOT NULL DEFAULT FALSE,
    incentive_disclosed BOOLEAN NOT NULL DEFAULT FALSE,

    helpful_count INTEGER NOT NULL DEFAULT 0,
    not_helpful_count INTEGER NOT NULL DEFAULT 0,
    reply_count INTEGER NOT NULL DEFAULT 0,

    seller_response TEXT NULL,
    seller_responded_at TIMESTAMPTZ NULL,
    seller_responded_by_user_id UUID NULL,

    moderation_notes TEXT NULL,
    moderation_score NUMERIC(5,2) NULL,

    submitted_at TIMESTAMPTZ NULL,
    approved_at TIMESTAMPTZ NULL,
    approved_by_user_id UUID NULL,
    rejected_at TIMESTAMPTZ NULL,
    rejected_by_user_id UUID NULL,
    rejection_reason TEXT NULL,

    ip_address INET NULL,
    user_agent TEXT NULL,

    current_version INTEGER NOT NULL DEFAULT 1,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rev_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rev_entity_type FOREIGN KEY (review_entity_type_id) REFERENCES reviews.review_entity_type_lookup(review_entity_type_id),
    CONSTRAINT fk_rev_status FOREIGN KEY (review_status_id) REFERENCES reviews.review_status_lookup(review_status_id),
    CONSTRAINT fk_rev_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rev_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_rev_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_rev_order_item FOREIGN KEY (order_item_id) REFERENCES sales.order_items(order_item_id),
    CONSTRAINT fk_rev_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rev_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT ck_rev_rating CHECK (rating >= 1 AND rating <= 5),
    CONSTRAINT ck_rev_entity CHECK (
        (review_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT') AND product_id IS NOT NULL) OR
        (review_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT_VARIANT') AND product_variant_id IS NOT NULL) OR
        (review_entity_type_id NOT IN (
            (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT'),
            (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT_VARIANT')
        ))
    )
);

CREATE INDEX ix_rev_company ON reviews.reviews(company_id);
CREATE INDEX ix_rev_entity ON reviews.reviews(entity_id);
CREATE INDEX ix_rev_product ON reviews.reviews(product_id);
CREATE INDEX ix_rev_customer ON reviews.reviews(customer_id);
CREATE INDEX ix_rev_order ON reviews.reviews(order_id);
CREATE INDEX ix_rev_status ON reviews.reviews(review_status_id);
CREATE INDEX ix_rev_rating ON reviews.reviews(rating);
CREATE INDEX ix_rev_submitted ON reviews.reviews(submitted_at DESC);

-- ============================================================
-- 26.2 REVIEW MEDIA
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.review_media (
    review_media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL,

    media_type VARCHAR(20) NOT NULL DEFAULT 'IMAGE',
    storage_provider VARCHAR(50) NULL,
    storage_bucket VARCHAR(200) NULL,
    storage_key VARCHAR(500) NULL,
    storage_url VARCHAR(1500) NULL,

    file_name VARCHAR(500) NULL,
    file_extension VARCHAR(20) NULL,
    mime_type VARCHAR(200) NULL,
    file_size_bytes BIGINT NULL,

    thumbnail_url VARCHAR(1500) NULL,
    caption TEXT NULL,
    alt_text VARCHAR(300) NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rm_review FOREIGN KEY (review_id) REFERENCES reviews.reviews(review_id) ON DELETE CASCADE,
    CONSTRAINT ck_rm_type CHECK (media_type IN ('IMAGE', 'VIDEO'))
);

CREATE INDEX ix_rm_review ON reviews.review_media(review_id);

-- ============================================================
-- 26.3 REVIEW VERSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.review_versions (
    review_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL,

    version_number INTEGER NOT NULL,
    rating INTEGER NOT NULL,
    title VARCHAR(300) NULL,
    review_text TEXT NULL,
    pros TEXT NULL,
    cons TEXT NULL,

    change_description TEXT NULL,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,

    CONSTRAINT fk_rv_review FOREIGN KEY (review_id) REFERENCES reviews.reviews(review_id) ON DELETE CASCADE,
    CONSTRAINT uq_review_version UNIQUE (review_id, version_number),
    CONSTRAINT ck_rv_rating CHECK (rating >= 1 AND rating <= 5)
);

CREATE INDEX ix_rv_review ON reviews.review_versions(review_id);

-- ============================================================
-- 26.4 REVIEW MODERATION HISTORY
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.review_moderation_history (
    review_moderation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL,
    review_moderation_action_id UUID NOT NULL,

    from_status_id UUID NULL,
    to_status_id UUID NOT NULL,

    performed_by_user_id UUID NULL,
    moderation_notes TEXT NULL,

    performed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fmh_review FOREIGN KEY (review_id) REFERENCES reviews.reviews(review_id) ON DELETE CASCADE,
    CONSTRAINT fk_rmh_action FOREIGN KEY (review_moderation_action_id) REFERENCES reviews.review_moderation_action_lookup(review_moderation_action_id),
    CONSTRAINT fk_rmh_from_status FOREIGN KEY (from_status_id) REFERENCES reviews.review_status_lookup(review_status_id),
    CONSTRAINT fk_rmh_to_status FOREIGN KEY (to_status_id) REFERENCES reviews.review_status_lookup(review_status_id)
);

CREATE INDEX ix_rmh_review ON reviews.review_moderation_history(review_id);
CREATE INDEX ix_rmh_performed ON reviews.review_moderation_history(performed_at DESC);

-- ============================================================
-- 26.5 REVIEW VOTES (Helpful)
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.review_votes (
    review_vote_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL,

    customer_id UUID NULL,
    user_id UUID NULL,

    is_helpful BOOLEAN NOT NULL,

    ip_address INET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rvote_review FOREIGN KEY (review_id) REFERENCES reviews.reviews(review_id) ON DELETE CASCADE,
    CONSTRAINT fk_rvote_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_rvote_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_review_vote UNIQUE (review_id, COALESCE(customer_id, '00000000-0000-0000-0000-000000000000'), COALESCE(user_id, '00000000-0000-0000-0000-000000000000'))
);

CREATE INDEX ix_rvote_review ON reviews.review_votes(review_id);

-- ============================================================
-- 26.6 REVIEW INVITATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.review_invitations (
    review_invitation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    order_id UUID NOT NULL,
    order_item_id UUID NULL,
    customer_id UUID NOT NULL,

    invitation_type VARCHAR(30) NOT NULL DEFAULT 'EMAIL',
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    invited_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMPTZ NULL,
    opened_at TIMESTAMPTZ NULL,
    clicked_at TIMESTAMPTZ NULL,
    review_submitted_at TIMESTAMPTZ NULL,
    review_id UUID NULL,

    expires_at TIMESTAMPTZ NULL,

    reminder_count INTEGER NOT NULL DEFAULT 0,
    last_reminder_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ri_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_ri_order FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    CONSTRAINT fk_ri_order_item FOREIGN KEY (order_item_id) REFERENCES sales.order_items(order_item_id),
    CONSTRAINT fk_ri_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_ri_review FOREIGN KEY (review_id) REFERENCES reviews.reviews(review_id),
    CONSTRAINT ck_ri_type CHECK (invitation_type IN ('EMAIL', 'SMS', 'WHATSAPP', 'PUSH', 'IN_APP')),
    CONSTRAINT ck_ri_status CHECK (status IN ('PENDING', 'SENT', 'OPENED', 'CLICKED', 'COMPLETED', 'EXPIRED', 'CANCELLED'))
);

CREATE INDEX ix_ri_order ON reviews.review_invitations(order_id);
CREATE INDEX ix_ri_customer ON reviews.review_invitations(customer_id);
CREATE INDEX ix_ri_status ON reviews.review_invitations(status);

-- ============================================================
-- 26.7 REVIEW INCENTIVES
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.review_incentives (
    review_incentive_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    review_incentive_type_id UUID NOT NULL,

    incentive_name VARCHAR(200) NOT NULL,
    description TEXT NULL,

    points_amount INTEGER NULL,
    discount_percentage NUMERIC(5,2) NULL,
    discount_amount NUMERIC(19,4) NULL,
    store_credit_amount NUMERIC(19,4) NULL,

    minimum_rating_required INTEGER NULL,
    minimum_text_length INTEGER NULL,
    requires_photo BOOLEAN NOT NULL DEFAULT FALSE,
    requires_verified_purchase BOOLEAN NOT NULL DEFAULT TRUE,

    max_redemptions_per_customer INTEGER NULL,
    total_redemptions INTEGER NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    start_date DATE NULL,
    end_date DATE NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id UUID NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by_user_id UUID NULL,

    CONSTRAINT fk_rin_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rin_type FOREIGN KEY (review_incentive_type_id) REFERENCES reviews.review_incentive_type_lookup(review_incentive_type_id),
    CONSTRAINT ck_rin_rating CHECK (minimum_rating_required IS NULL OR (minimum_rating_required >= 1 AND minimum_rating_required <= 5))
);

CREATE INDEX ix_rin_company ON reviews.review_incentives(company_id);
CREATE INDEX ix_rin_active ON reviews.review_incentives(is_active);

-- Incentive Redemptions
CREATE TABLE IF NOT EXISTS reviews.review_incentive_redemptions (
    incentive_redemption_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_incentive_id UUID NOT NULL,
    review_id UUID NOT NULL,
    customer_id UUID NOT NULL,

    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    loyalty_transaction_id UUID NULL,
    coupon_id UUID NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rir_incentive FOREIGN KEY (review_incentive_id) REFERENCES reviews.review_incentives(review_incentive_id),
    CONSTRAINT fk_rir_review FOREIGN KEY (review_id) REFERENCES reviews.reviews(review_id),
    CONSTRAINT fk_rir_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT uq_incentive_redemption UNIQUE (review_incentive_id, review_id, customer_id)
);

CREATE INDEX ix_rir_incentive ON reviews.review_incentive_redemptions(review_incentive_id);
CREATE INDEX ix_rir_customer ON reviews.review_incentive_redemptions(customer_id);

-- ============================================================
-- 26.8 FRAUD/RISK ASSESSMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.review_fraud_assessments (
    fraud_assessment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL,
    fraud_signal_type_id UUID NOT NULL,

    risk_score NUMERIC(5,2) NOT NULL DEFAULT 0,
    signal_details JSONB NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    is_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    confirmed_by_user_id UUID NULL,
    confirmed_at TIMESTAMPTZ NULL,
    resolution_notes TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rfa_review FOREIGN KEY (review_id) REFERENCES reviews.reviews(review_id) ON DELETE CASCADE,
    CONSTRAINT fk_rfa_signal FOREIGN KEY (fraud_signal_type_id) REFERENCES reviews.fraud_signal_type_lookup(fraud_signal_type_id),
    CONSTRAINT ck_rfa_score CHECK (risk_score >= 0 AND risk_score <= 100)
);

CREATE INDEX ix_rfa_review ON reviews.review_fraud_assessments(review_id);
CREATE INDEX ix_rfa_signal ON reviews.review_fraud_assessments(fraud_signal_type_id);

-- ============================================================
-- 26.9 RATING SUMMARIES (Read Model)
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.rating_summaries (
    rating_summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    review_entity_type_id UUID NOT NULL,

    entity_id UUID NOT NULL,
    product_id UUID NULL,
    product_variant_id UUID NULL,

    total_reviews INTEGER NOT NULL DEFAULT 0,
    approved_reviews INTEGER NOT NULL DEFAULT 0,
    verified_purchase_reviews INTEGER NOT NULL DEFAULT 0,

    average_rating NUMERIC(3,2) NOT NULL DEFAULT 0,
    rating_1_count INTEGER NOT NULL DEFAULT 0,
    rating_2_count INTEGER NOT NULL DEFAULT 0,
    rating_3_count INTEGER NOT NULL DEFAULT 0,
    rating_4_count INTEGER NOT NULL DEFAULT 0,
    rating_5_count INTEGER NOT NULL DEFAULT 0,

    total_helpful_votes INTEGER NOT NULL DEFAULT 0,
    total_media_count INTEGER NOT NULL DEFAULT 0,

    last_review_at TIMESTAMPTZ NULL,
    last_calculated_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rs_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_rs_entity_type FOREIGN KEY (review_entity_type_id) REFERENCES reviews.review_entity_type_lookup(review_entity_type_id),
    CONSTRAINT fk_rs_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_rs_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT uq_rating_summary UNIQUE (company_id, review_entity_type_id, entity_id)
);

CREATE INDEX ix_rs_entity ON reviews.rating_summaries(entity_id);
CREATE INDEX ix_rs_product ON reviews.rating_summaries(product_id);

-- ============================================================
-- 26.10 QUESTIONS & ANSWERS
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews.product_questions (
    product_question_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_variant_id UUID NULL,
    question_status_id UUID NOT NULL DEFAULT (SELECT question_status_id FROM reviews.question_status_lookup WHERE code = 'PENDING'),

    customer_id UUID NULL,
    user_id UUID NULL,

    question_text TEXT NOT NULL,
    asker_name VARCHAR(200) NULL,

    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,

    helpful_count INTEGER NOT NULL DEFAULT 0,
    answer_count INTEGER NOT NULL DEFAULT 0,

    answered_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pq_company FOREIGN KEY (company_id) REFERENCES organization.companies(company_id),
    CONSTRAINT fk_pq_product FOREIGN KEY (product_id) REFERENCES catalog.products(product_id),
    CONSTRAINT fk_pq_variant FOREIGN KEY (product_variant_id) REFERENCES catalog.product_variants(variant_id),
    CONSTRAINT fk_pq_status FOREIGN KEY (question_status_id) REFERENCES reviews.question_status_lookup(question_status_id),
    CONSTRAINT fk_pq_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_pq_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id)
);

CREATE INDEX ix_pq_product ON reviews.product_questions(product_id);
CREATE INDEX ix_pq_customer ON reviews.product_questions(customer_id);
CREATE INDEX ix_pq_status ON reviews.product_questions(question_status_id);

-- Product Answers
CREATE TABLE IF NOT EXISTS reviews.product_answers (
    product_answer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_question_id UUID NOT NULL,

    answerer_type VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER',
    customer_id UUID NULL,
    user_id UUID NULL,
    employee_id UUID NULL,

    answer_text TEXT NOT NULL,
    answerer_name VARCHAR(200) NULL,

    is_official_answer BOOLEAN NOT NULL DEFAULT FALSE,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,

    helpful_count INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_pa_question FOREIGN KEY (product_question_id) REFERENCES reviews.product_questions(product_question_id) ON DELETE CASCADE,
    CONSTRAINT fk_pa_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_pa_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT fk_pa_employee FOREIGN KEY (employee_id) REFERENCES identity.employees(employee_id),
    CONSTRAINT ck_pa_type CHECK (answerer_type IN ('CUSTOMER', 'SELLER', 'EMPLOYEE', 'SYSTEM'))
);

CREATE INDEX ix_pa_question ON reviews.product_answers(product_question_id);

-- Answer Votes
CREATE TABLE IF NOT EXISTS reviews.answer_votes (
    answer_vote_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_answer_id UUID NOT NULL,

    customer_id UUID NULL,
    user_id UUID NULL,

    is_helpful BOOLEAN NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_av_answer FOREIGN KEY (product_answer_id) REFERENCES reviews.product_answers(product_answer_id) ON DELETE CASCADE,
    CONSTRAINT fk_av_customer FOREIGN KEY (customer_id) REFERENCES crm.customers(customer_id),
    CONSTRAINT fk_av_user FOREIGN KEY (user_id) REFERENCES identity.users(user_id),
    CONSTRAINT uq_answer_vote UNIQUE (product_answer_id, COALESCE(customer_id, '00000000-0000-0000-0000-000000000000'), COALESCE(user_id, '00000000-0000-0000-0000-000000000000'))
);

CREATE INDEX ix_av_answer ON reviews.answer_votes(product_answer_id);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Function: Verify Purchase
CREATE OR REPLACE FUNCTION reviews.verify_purchase(
    p_customer_id UUID,
    p_product_id UUID,
    p_order_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF p_order_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_count
        FROM sales.order_items oi
        JOIN sales.orders o ON o.order_id = oi.order_id
        WHERE o.order_id = p_order_id
          AND o.customer_id = p_customer_id
          AND oi.product_id = p_product_id
          AND o.status IN (
              (SELECT order_status_id FROM sales.order_status_lookup WHERE code = 'COMPLETED'),
              (SELECT order_status_id FROM sales.order_status_lookup WHERE code = 'DELIVERED')
          );
    ELSE
        SELECT COUNT(*) INTO v_count
        FROM sales.order_items oi
        JOIN sales.orders o ON o.order_id = oi.order_id
        WHERE o.customer_id = p_customer_id
          AND oi.product_id = p_product_id
          AND o.status IN (
              (SELECT order_status_id FROM sales.order_status_lookup WHERE code = 'COMPLETED'),
              (SELECT order_status_id FROM sales.order_status_lookup WHERE code = 'DELIVERED')
          );
    END IF;

    RETURN v_count > 0;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate Rating Summary
CREATE OR REPLACE FUNCTION reviews.calculate_rating_summary(
    p_company_id UUID,
    p_entity_type_id UUID,
    p_entity_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_product_id UUID;
    v_variant_id UUID;
BEGIN
    -- Get product/variant IDs if applicable
    IF p_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT') THEN
        v_product_id := p_entity_id;
    ELSIF p_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT_VARIANT') THEN
        SELECT product_id, variant_id INTO v_product_id, v_variant_id
        FROM catalog.product_variants WHERE variant_id = p_entity_id;
    END IF;

    INSERT INTO reviews.rating_summaries (
        company_id, review_entity_type_id, entity_id, product_id, product_variant_id,
        total_reviews, approved_reviews, verified_purchase_reviews,
        average_rating, rating_1_count, rating_2_count, rating_3_count, rating_4_count, rating_5_count,
        total_helpful_votes, total_media_count, last_review_at, last_calculated_at
    )
    SELECT
        p_company_id,
        p_entity_type_id,
        p_entity_id,
        v_product_id,
        v_variant_id,
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE),
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE),
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE AND r.is_verified_purchase = TRUE),
        COALESCE(AVG(r.rating) FILTER (WHERE rs.is_visible_public = TRUE), 0),
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE AND r.rating = 1),
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE AND r.rating = 2),
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE AND r.rating = 3),
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE AND r.rating = 4),
        COUNT(*) FILTER (WHERE rs.is_visible_public = TRUE AND r.rating = 5),
        COALESCE(SUM(r.helpful_count) FILTER (WHERE rs.is_visible_public = TRUE), 0),
        COUNT(DISTINCT rm.review_media_id) FILTER (WHERE rs.is_visible_public = TRUE),
        MAX(r.submitted_at) FILTER (WHERE rs.is_visible_public = TRUE),
        CURRENT_TIMESTAMP
    FROM reviews.reviews r
    JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
    LEFT JOIN reviews.review_media rm ON rm.review_id = r.review_id AND rm.is_active = TRUE
    WHERE r.company_id = p_company_id
      AND r.review_entity_type_id = p_entity_type_id
      AND r.entity_id = p_entity_id
    ON CONFLICT (company_id, review_entity_type_id, entity_id)
    DO UPDATE SET
        total_reviews = EXCLUDED.total_reviews,
        approved_reviews = EXCLUDED.approved_reviews,
        verified_purchase_reviews = EXCLUDED.verified_purchase_reviews,
        average_rating = EXCLUDED.average_rating,
        rating_1_count = EXCLUDED.rating_1_count,
        rating_2_count = EXCLUDED.rating_2_count,
        rating_3_count = EXCLUDED.rating_3_count,
        rating_4_count = EXCLUDED.rating_4_count,
        rating_5_count = EXCLUDED.rating_5_count,
        total_helpful_votes = EXCLUDED.total_helpful_votes,
        total_media_count = EXCLUDED.total_media_count,
        last_review_at = EXCLUDED.last_review_at,
        last_calculated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function: Check Review Eligibility
CREATE OR REPLACE FUNCTION reviews.check_review_eligibility(
    p_customer_id UUID,
    p_product_id UUID,
    p_order_id UUID DEFAULT NULL
)
RETURNS TABLE (
    can_review BOOLEAN,
    is_verified_purchase BOOLEAN,
    existing_review_count BIGINT,
    reason TEXT
) AS $$
DECLARE
    v_is_verified BOOLEAN;
    v_existing_count BIGINT;
BEGIN
    -- Check if customer already reviewed this product
    SELECT COUNT(*) INTO v_existing_count
    FROM reviews.reviews r
    WHERE r.customer_id = p_customer_id
      AND r.product_id = p_product_id
      AND r.review_status_id NOT IN (
          (SELECT review_status_id FROM reviews.review_status_lookup WHERE code = 'REMOVED'),
          (SELECT review_status_id FROM reviews.review_status_lookup WHERE code = 'REJECTED')
      );

    -- Verify purchase
    v_is_verified := reviews.verify_purchase(p_customer_id, p_product_id, p_order_id);

    IF v_existing_count > 0 THEN
        RETURN QUERY SELECT FALSE, v_is_verified, v_existing_count, 'Customer has already reviewed this product.'::TEXT;
    ELSIF NOT v_is_verified THEN
        RETURN QUERY SELECT TRUE, FALSE, v_existing_count, 'Review allowed but not verified purchase.'::TEXT;
    ELSE
        RETURN QUERY SELECT TRUE, TRUE, v_existing_count, 'Review eligible.'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEED DATA
-- ============================================================

DO $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM organization.companies LIMIT 1;
    IF v_company_id IS NULL THEN RETURN; END IF;

    -- Create default review incentive
    INSERT INTO reviews.review_incentives (company_id, review_incentive_type_id, incentive_name, description, points_amount, requires_verified_purchase, is_active)
    SELECT v_company_id,
           (SELECT review_incentive_type_id FROM reviews.review_incentive_type_lookup WHERE code = 'LOYALTY_POINTS'),
           'Review for Points', 'Earn 50 loyalty points for each approved review.', 50, TRUE, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM reviews.review_incentives WHERE company_id = v_company_id AND incentive_name = 'Review for Points');

END $$;

COMMIT;