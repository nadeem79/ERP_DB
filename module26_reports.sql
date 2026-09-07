BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 26: REVIEWS, RATINGS & USER-GENERATED CONTENT REPORTING
-- 20 Views + 2 Functions
-- ============================================================

-- View 1: Review Summary Report
CREATE VIEW reports.vw_review_summary AS
SELECT
    DATE(r.submitted_at) as review_date,
    ret.code as entity_type,
    rs.code as review_status,
    COUNT(DISTINCT r.review_id) as review_count,
    AVG(r.rating) as avg_rating,
    COUNT(DISTINCT CASE WHEN r.is_verified_purchase = TRUE THEN r.review_id END) as verified_reviews,
    COUNT(DISTINCT CASE WHEN r.is_incentivized = TRUE THEN r.review_id END) as incentivized_reviews,
    SUM(r.helpful_count) as total_helpful_votes
FROM reviews.reviews r
JOIN reviews.review_entity_type_lookup ret ON ret.review_entity_type_id = r.review_entity_type_id
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE r.submitted_at IS NOT NULL
GROUP BY DATE(r.submitted_at), ret.code, rs.code
ORDER BY review_date DESC;

-- View 2: Product Rating Summary
CREATE VIEW reports.vw_product_rating_summary AS
SELECT
    p.product_code,
    p.product_name,
    rs.total_reviews,
    rs.approved_reviews,
    rs.verified_purchase_reviews,
    rs.average_rating,
    rs.rating_1_count,
    rs.rating_2_count,
    rs.rating_3_count,
    rs.rating_4_count,
    rs.rating_5_count,
    rs.total_helpful_votes,
    rs.total_media_count,
    rs.last_review_at,
    CASE
        WHEN rs.average_rating >= 4.5 THEN 'EXCELLENT'
        WHEN rs.average_rating >= 4.0 THEN 'VERY_GOOD'
        WHEN rs.average_rating >= 3.5 THEN 'GOOD'
        WHEN rs.average_rating >= 3.0 THEN 'AVERAGE'
        WHEN rs.average_rating >= 2.0 THEN 'BELOW_AVERAGE'
        ELSE 'POOR'
    END as rating_category
FROM reviews.rating_summaries rs
JOIN catalog.products p ON p.product_id = rs.product_id
WHERE rs.review_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT')
ORDER BY rs.average_rating DESC, rs.total_reviews DESC;

-- View 3: Review Moderation Queue
CREATE VIEW reports.vw_review_moderation_queue AS
SELECT
    r.review_id,
    r.title,
    r.rating,
    r.reviewer_name,
    r.submitted_at,
    rs.code as status,
    ret.code as entity_type,
    r.is_verified_purchase,
    r.is_incentivized,
    r.moderation_score,
    p.product_name,
    c.display_name as customer_name
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
JOIN reviews.review_entity_type_lookup ret ON ret.review_entity_type_id = r.review_entity_type_id
LEFT JOIN catalog.products p ON p.product_id = r.product_id
LEFT JOIN crm.customers c ON c.customer_id = r.customer_id
WHERE rs.code IN ('PENDING_MODERATION', 'FLAGGED', 'ESCALATED')
ORDER BY r.submitted_at ASC;

-- View 4: Review Sentiment Analysis
CREATE VIEW reports.vw_review_sentiment AS
SELECT
    CASE
        WHEN r.rating >= 4 THEN 'POSITIVE'
        WHEN r.rating = 3 THEN 'NEUTRAL'
        ELSE 'NEGATIVE'
    END as sentiment,
    COUNT(DISTINCT r.review_id) as review_count,
    AVG(r.rating) as avg_rating,
    SUM(r.helpful_count) as total_helpful_votes,
    COUNT(DISTINCT CASE WHEN r.is_verified_purchase = TRUE THEN r.review_id END) as verified_count
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.is_visible_public = TRUE
GROUP BY
    CASE
        WHEN r.rating >= 4 THEN 'POSITIVE'
        WHEN r.rating = 3 THEN 'NEUTRAL'
        ELSE 'NEGATIVE'
    END
ORDER BY review_count DESC;

-- View 5: Verified vs Unverified Reviews
CREATE VIEW reports.vw_verified_vs_unverified AS
SELECT
    CASE WHEN r.is_verified_purchase = TRUE THEN 'VERIFIED' ELSE 'UNVERIFIED' END as purchase_status,
    COUNT(DISTINCT r.review_id) as review_count,
    AVG(r.rating) as avg_rating,
    SUM(r.helpful_count) as total_helpful_votes,
    COUNT(DISTINCT CASE WHEN rs.is_visible_public = TRUE THEN r.review_id END) as approved_count
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
GROUP BY r.is_verified_purchase
ORDER BY review_count DESC;

-- View 6: Review Invitation Performance
CREATE VIEW reports.vw_review_invitation_performance AS
SELECT
    DATE(ri.invited_at) as invitation_date,
    ri.invitation_type,
    ri.status,
    COUNT(DISTINCT ri.review_invitation_id) as invitation_count,
    COUNT(DISTINCT CASE WHEN ri.review_id IS NOT NULL THEN ri.review_invitation_id END) as completed_count,
    ROUND((COUNT(DISTINCT CASE WHEN ri.review_id IS NOT NULL THEN ri.review_invitation_id END)::numeric /
           NULLIF(COUNT(DISTINCT ri.review_invitation_id), 0) * 100), 2) as completion_rate_percent
FROM reviews.review_invitations ri
GROUP BY DATE(ri.invited_at), ri.invitation_type, ri.status
ORDER BY invitation_date DESC;

-- View 7: Review Incentive Performance
CREATE VIEW reports.vw_review_incentive_performance AS
SELECT
    rin.incentive_name,
    rit.code as incentive_type,
    rin.points_amount,
    rin.discount_percentage,
    rin.total_redemptions,
    rin.max_redemptions_per_customer,
    rin.is_active,
    COUNT(DISTINCT rir.incentive_redemption_id) as actual_redemptions
FROM reviews.review_incentives rin
JOIN reviews.review_incentive_type_lookup rit ON rit.review_incentive_type_id = rin.review_incentive_type_id
LEFT JOIN reviews.review_incentive_redemptions rir ON rir.review_incentive_id = rin.review_incentive_id
GROUP BY rin.review_incentive_id, rin.incentive_name, rit.code, rin.points_amount, rin.discount_percentage, rin.total_redemptions, rin.max_redemptions_per_customer, rin.is_active
ORDER BY actual_redemptions DESC NULLS LAST;

-- View 8: Fraud Detection Report
CREATE VIEW reports.vw_review_fraud_report AS
SELECT
    fst.code as signal_type,
    fst.name as signal_name,
    fst.severity,
    COUNT(DISTINCT rfa.fraud_assessment_id) as assessment_count,
    COUNT(DISTINCT CASE WHEN rfa.is_confirmed = TRUE THEN rfa.fraud_assessment_id END) as confirmed_count,
    AVG(rfa.risk_score) as avg_risk_score,
    MAX(rfa.risk_score) as max_risk_score
FROM reviews.fraud_signal_type_lookup fst
LEFT JOIN reviews.review_fraud_assessments rfa ON rfa.fraud_signal_type_id = fst.fraud_signal_type_id
GROUP BY fst.fraud_signal_type_id, fst.code, fst.name, fst.severity
ORDER BY assessment_count DESC NULLS LAST;

-- View 9: Q&A Summary Report
CREATE VIEW reports.vw_qa_summary AS
SELECT
    p.product_code,
    p.product_name,
    COUNT(DISTINCT pq.product_question_id) as total_questions,
    COUNT(DISTINCT CASE WHEN qs.code = 'ANSWERED' THEN pq.product_question_id END) as answered_questions,
    COUNT(DISTINCT CASE WHEN qs.code = 'PENDING' THEN pq.product_question_id END) as pending_questions,
    ROUND((COUNT(DISTINCT CASE WHEN qs.code = 'ANSWERED' THEN pq.product_question_id END)::numeric /
           NULLIF(COUNT(DISTINCT pq.product_question_id), 0) * 100), 2) as answer_rate_percent
FROM reviews.product_questions pq
JOIN catalog.products p ON p.product_id = pq.product_id
JOIN reviews.question_status_lookup qs ON qs.question_status_id = pq.question_status_id
GROUP BY p.product_id, p.product_code, p.product_name
ORDER BY total_questions DESC;

-- View 10: Top Rated Products
CREATE VIEW reports.vw_top_rated_products AS
SELECT
    p.product_code,
    p.product_name,
    rs.average_rating,
    rs.total_reviews,
    rs.verified_purchase_reviews,
    rs.rating_5_count,
    rs.last_review_at
FROM reviews.rating_summaries rs
JOIN catalog.products p ON p.product_id = rs.product_id
WHERE rs.review_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT')
  AND rs.approved_reviews >= 5
ORDER BY rs.average_rating DESC, rs.total_reviews DESC
LIMIT 50;

-- View 11: Lowest Rated Products
CREATE VIEW reports.vw_lowest_rated_products AS
SELECT
    p.product_code,
    p.product_name,
    rs.average_rating,
    rs.total_reviews,
    rs.rating_1_count,
    rs.rating_2_count,
    rs.last_review_at
FROM reviews.rating_summaries rs
JOIN catalog.products p ON p.product_id = rs.product_id
WHERE rs.review_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT')
  AND rs.approved_reviews >= 3
ORDER BY rs.average_rating ASC, rs.total_reviews DESC
LIMIT 50;

-- View 12: Review Media Report
CREATE VIEW reports.vw_review_media_report AS
SELECT
    rm.media_type,
    COUNT(DISTINCT rm.review_media_id) as media_count,
    COUNT(DISTINCT rm.review_id) as reviews_with_media,
    SUM(rm.file_size_bytes) as total_storage_bytes
FROM reviews.review_media rm
WHERE rm.is_active = TRUE
GROUP BY rm.media_type
ORDER BY media_count DESC;

-- View 13: Review Response Report
CREATE VIEW reports.vw_review_response_report AS
SELECT
    COUNT(DISTINCT r.review_id) as total_reviews,
    COUNT(DISTINCT CASE WHEN r.seller_response IS NOT NULL THEN r.review_id END) as responded_reviews,
    ROUND((COUNT(DISTINCT CASE WHEN r.seller_response IS NOT NULL THEN r.review_id END)::numeric /
           NULLIF(COUNT(DISTINCT r.review_id), 0) * 100), 2) as response_rate_percent,
    AVG(EXTRACT(EPOCH FROM (r.seller_responded_at - r.approved_at))/3600) FILTER (WHERE r.seller_responded_at IS NOT NULL) as avg_response_hours
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.is_visible_public = TRUE;

-- View 14: Review Quality Analytics
CREATE VIEW reports.vw_review_quality_analytics AS
SELECT
    p.product_code,
    p.product_name,
    rs.average_rating,
    rt.total_returns,
    rt.return_rate_percent,
    CASE
        WHEN rs.average_rating < 3.0 AND rt.return_rate_percent > 20 THEN 'HIGH_RISK'
        WHEN rs.average_rating < 3.5 AND rt.return_rate_percent > 15 THEN 'MEDIUM_RISK'
        ELSE 'NORMAL'
    END as quality_risk_level
FROM reviews.rating_summaries rs
JOIN catalog.products p ON p.product_id = rs.product_id
LEFT JOIN (
    SELECT
        rr.product_id,
        COUNT(DISTINCT rr.return_request_id) as total_returns,
        ROUND((COUNT(DISTINCT rr.return_request_id)::numeric / NULLIF(COUNT(DISTINCT oi.order_item_id), 0) * 100), 2) as return_rate_percent
    FROM returns.return_requests rr
    JOIN returns.return_request_items rri ON rri.return_request_id = rr.return_request_id
    JOIN sales.order_items oi ON oi.order_item_id = rri.order_item_id
    GROUP BY rr.product_id
) rt ON rt.product_id = rs.product_id
WHERE rs.review_entity_type_id = (SELECT review_entity_type_id FROM reviews.review_entity_type_lookup WHERE code = 'PRODUCT')
ORDER BY quality_risk_level DESC, rs.average_rating ASC;

-- View 15: Customer Review Activity
CREATE VIEW reports.vw_customer_review_activity AS
SELECT
    c.customer_number,
    c.display_name,
    COUNT(DISTINCT r.review_id) as total_reviews,
    COUNT(DISTINCT CASE WHEN rs.is_visible_public = TRUE THEN r.review_id END) as approved_reviews,
    AVG(r.rating) as avg_rating_given,
    SUM(r.helpful_count) as helpful_votes_received,
    MAX(r.submitted_at) as last_review_at
FROM reviews.reviews r
JOIN crm.customers c ON c.customer_id = r.customer_id
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
GROUP BY c.customer_id, c.customer_number, c.display_name
ORDER BY total_reviews DESC;

-- View 16: Review Trend Report
CREATE VIEW reports.vw_review_trend AS
SELECT
    DATE_TRUNC('month', r.submitted_at) as month,
    COUNT(DISTINCT r.review_id) as review_count,
    AVG(r.rating) as avg_rating,
    COUNT(DISTINCT CASE WHEN r.is_verified_purchase = TRUE THEN r.review_id END) as verified_reviews,
    COUNT(DISTINCT CASE WHEN rs.is_visible_public = TRUE THEN r.review_id END) as approved_reviews
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE r.submitted_at IS NOT NULL
GROUP BY DATE_TRUNC('month', r.submitted_at)
ORDER BY month DESC;

-- View 17: Review Helpfulness Report
CREATE VIEW reports.vw_review_helpfulness AS
SELECT
    r.review_id,
    r.title,
    r.rating,
    r.helpful_count,
    r.not_helpful_count,
    CASE
        WHEN r.helpful_count + r.not_helpful_count > 0
        THEN ROUND((r.helpful_count::numeric / (r.helpful_count + r.not_helpful_count) * 100), 2)
        ELSE 0
    END as helpfulness_percent,
    p.product_name,
    c.display_name as customer_name
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
LEFT JOIN catalog.products p ON p.product_id = r.product_id
LEFT JOIN crm.customers c ON c.customer_id = r.customer_id
WHERE rs.is_visible_public = TRUE
  AND (r.helpful_count + r.not_helpful_count) > 0
ORDER BY helpfulness_percent DESC, r.helpful_count DESC
LIMIT 100;

-- View 18: Incentivized Review Impact
CREATE VIEW reports.vw_incentivized_review_impact AS
SELECT
    CASE WHEN r.is_incentivized = TRUE THEN 'INCENTIVIZED' ELSE 'ORGANIC' END as review_source,
    COUNT(DISTINCT r.review_id) as review_count,
    AVG(r.rating) as avg_rating,
    SUM(r.helpful_count) as total_helpful_votes,
    COUNT(DISTINCT CASE WHEN r.is_verified_purchase = TRUE THEN r.review_id END) as verified_count
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.is_visible_public = TRUE
GROUP BY r.is_incentivized
ORDER BY review_count DESC;

-- View 19: Review Distribution by Rating
CREATE VIEW reports.vw_review_distribution AS
SELECT
    r.rating,
    COUNT(DISTINCT r.review_id) as review_count,
    ROUND((COUNT(DISTINCT r.review_id)::numeric / NULLIF(SUM(COUNT(DISTINCT r.review_id)) OVER (), 0) * 100), 2) as percent_of_total,
    AVG(r.helpful_count) as avg_helpful_votes
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.is_visible_public = TRUE
GROUP BY r.rating
ORDER BY r.rating DESC;

-- View 20: Review Health Dashboard
CREATE VIEW reports.vw_review_health_dashboard AS
SELECT
    'Total Reviews' as metric,
    COUNT(DISTINCT r.review_id)::TEXT as value
FROM reviews.reviews r
UNION ALL
SELECT
    'Approved Reviews' as metric,
    COUNT(DISTINCT r.review_id)::TEXT
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.is_visible_public = TRUE
UNION ALL
SELECT
    'Pending Moderation' as metric,
    COUNT(DISTINCT r.review_id)::TEXT
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.code = 'PENDING_MODERATION'
UNION ALL
SELECT
    'Average Rating' as metric,
    ROUND(AVG(r.rating), 2)::TEXT
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.is_visible_public = TRUE
UNION ALL
SELECT
    'Verified Purchase Reviews' as metric,
    COUNT(DISTINCT r.review_id)::TEXT
FROM reviews.reviews r
JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
WHERE rs.is_visible_public = TRUE AND r.is_verified_purchase = TRUE
UNION ALL
SELECT
    'Reviews with Media' as metric,
    COUNT(DISTINCT rm.review_id)::TEXT
FROM reviews.review_media rm
WHERE rm.is_active = TRUE
UNION ALL
SELECT
    'Total Questions' as metric,
    COUNT(DISTINCT pq.product_question_id)::TEXT
FROM reviews.product_questions pq
UNION ALL
SELECT
    'Unanswered Questions' as metric,
    COUNT(DISTINCT pq.product_question_id)::TEXT
FROM reviews.product_questions pq
JOIN reviews.question_status_lookup qs ON qs.question_status_id = pq.question_status_id
WHERE qs.code = 'PENDING'
UNION ALL
SELECT
    'Fraud Assessments' as metric,
    COUNT(DISTINCT rfa.fraud_assessment_id)::TEXT
FROM reviews.review_fraud_assessments rfa
UNION ALL
SELECT
    'Review Invitations Sent' as metric,
    COUNT(DISTINCT ri.review_invitation_id)::TEXT
FROM reviews.review_invitations ri;

-- Function 1: Get Product Reviews
CREATE OR REPLACE FUNCTION reports.get_product_reviews(
    p_product_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0,
    p_min_rating INTEGER DEFAULT NULL,
    p_max_rating INTEGER DEFAULT NULL,
    p_verified_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    review_id UUID,
    rating INTEGER,
    title VARCHAR,
    review_text TEXT,
    reviewer_name VARCHAR,
    is_verified_purchase BOOLEAN,
    helpful_count INTEGER,
    submitted_at TIMESTAMPTZ,
    seller_response TEXT,
    media_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.review_id,
        r.rating,
        r.title::VARCHAR,
        r.review_text,
        CASE WHEN r.is_anonymous THEN 'Anonymous' ELSE COALESCE(r.reviewer_name, 'Customer') END,
        r.is_verified_purchase,
        r.helpful_count,
        r.submitted_at,
        r.seller_response,
        COUNT(DISTINCT rm.review_media_id)
    FROM reviews.reviews r
    JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
    LEFT JOIN reviews.review_media rm ON rm.review_id = r.review_id AND rm.is_active = TRUE
    WHERE r.product_id = p_product_id
      AND rs.is_visible_public = TRUE
      AND (p_min_rating IS NULL OR r.rating >= p_min_rating)
      AND (p_max_rating IS NULL OR r.rating <= p_max_rating)
      AND (NOT p_verified_only OR r.is_verified_purchase = TRUE)
    GROUP BY r.review_id, r.rating, r.title, r.review_text, r.reviewer_name, r.is_anonymous, r.is_verified_purchase, r.helpful_count, r.submitted_at, r.seller_response
    ORDER BY r.helpful_count DESC, r.submitted_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Review Analytics by Date Range
CREATE OR REPLACE FUNCTION reports.get_review_analytics(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    stat_date DATE,
    total_reviews BIGINT,
    approved_reviews BIGINT,
    avg_rating NUMERIC,
    verified_reviews BIGINT,
    reviews_with_media BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE(r.submitted_at),
        COUNT(DISTINCT r.review_id)::BIGINT,
        COUNT(DISTINCT CASE WHEN rs.is_visible_public = TRUE THEN r.review_id END)::BIGINT,
        ROUND(AVG(r.rating), 2),
        COUNT(DISTINCT CASE WHEN r.is_verified_purchase = TRUE THEN r.review_id END)::BIGINT,
        COUNT(DISTINCT rm.review_id)::BIGINT
    FROM reviews.reviews r
    JOIN reviews.review_status_lookup rs ON rs.review_status_id = r.review_status_id
    LEFT JOIN reviews.review_media rm ON rm.review_id = r.review_id AND rm.is_active = TRUE
    WHERE r.company_id = p_company_id
      AND r.submitted_at::DATE BETWEEN p_start_date AND p_end_date
    GROUP BY DATE(r.submitted_at)
    ORDER BY DATE(r.submitted_at);
END;
$$ LANGUAGE plpgsql;

COMMIT;