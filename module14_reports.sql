BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 14 — EXPENSE MANAGEMENT REPORTING
-- 15 Views + 10 Functions
-- ============================================================

-- View 1: Expense Claim Summary
CREATE OR REPLACE VIEW reports.vw_expense_claim_summary AS
SELECT
    ec.expense_claim_id,
    ec.claim_number,
    ec.claim_date,
    ec.status,
    ec.total_amount,
    ec.approved_amount,
    ec.rejected_amount,
    ec.reimbursed_amount,
    ec.currency_id,
    c.code AS currency_code,
    d.department_name,
    bu.business_unit_name,
    COUNT(DISTINCT eci.expense_claim_item_id) AS item_count,
    ec.submitted_at,
    ec.approved_at,
    ec.paid_at,
    ec.created_at
FROM expenses.expense_claims ec
LEFT JOIN reference.currency_lookup c ON c.currency_id = ec.currency_id
LEFT JOIN organization.departments d ON d.department_id = ec.department_id
LEFT JOIN organization.business_units bu ON bu.business_unit_id = ec.business_unit_id
LEFT JOIN expenses.expense_claim_items eci ON eci.expense_claim_id = ec.expense_claim_id
GROUP BY ec.expense_claim_id, ec.claim_number, ec.claim_date, ec.status, ec.total_amount,
         ec.approved_amount, ec.rejected_amount, ec.reimbursed_amount, ec.currency_id,
         c.code, d.department_name, bu.business_unit_name,
         ec.submitted_at, ec.approved_at, ec.paid_at, ec.created_at
ORDER BY ec.claim_date DESC;

-- View 2: Expense by Category
CREATE OR REPLACE VIEW reports.vw_expense_by_category AS
SELECT
    ecat.code AS category_code,
    ecat.name AS category_name,
    pcat.name AS parent_category_name,
    COUNT(DISTINCT eci.expense_claim_item_id) AS transaction_count,
    SUM(eci.amount) AS total_amount,
    SUM(eci.tax_amount) AS total_tax,
    SUM(eci.base_amount) AS total_base_amount,
    AVG(eci.amount) AS avg_amount
FROM expenses.expense_claim_items eci
JOIN expenses.expense_categories ecat ON ecat.expense_category_id = eci.expense_category_id
LEFT JOIN expenses.expense_categories pcat ON pcat.expense_category_id = ecat.parent_category_id
JOIN expenses.expense_claims ec ON ec.expense_claim_id = eci.expense_claim_id
WHERE ec.status NOT IN ('DRAFT', 'CANCELLED')
GROUP BY ecat.code, ecat.name, pcat.name
ORDER BY total_amount DESC;

-- View 3: Expense by Department
CREATE OR REPLACE VIEW reports.vw_expense_by_department AS
SELECT
    d.department_name,
    bu.business_unit_name,
    COUNT(DISTINCT ec.expense_claim_id) AS claim_count,
    SUM(ec.total_amount) AS total_amount,
    SUM(ec.approved_amount) AS approved_amount,
    SUM(ec.reimbursed_amount) AS reimbursed_amount,
    AVG(ec.total_amount) AS avg_claim_amount
FROM expenses.expense_claims ec
LEFT JOIN organization.departments d ON d.department_id = ec.department_id
LEFT JOIN organization.business_units bu ON bu.business_unit_id = ec.business_unit_id
WHERE ec.status NOT IN ('DRAFT', 'CANCELLED')
GROUP BY d.department_name, bu.business_unit_name
ORDER BY total_amount DESC;

-- View 4: Pending Approvals
CREATE OR REPLACE VIEW reports.vw_pending_approvals AS
SELECT
    ec.expense_claim_id,
    ec.claim_number,
    ec.claim_date,
    ec.total_amount,
    ec.status AS claim_status,
    ea.sequence AS approval_sequence,
    ea.required_role_code,
    ea.status AS approval_status,
    ec.submitted_at,
    CURRENT_DATE - ec.claim_date AS days_pending
FROM expenses.expense_claims ec
JOIN expenses.expense_approvals ea ON ea.expense_claim_id = ec.expense_claim_id
WHERE ea.status = 'PENDING'
  AND ec.status IN ('SUBMITTED', 'UNDER_REVIEW')
ORDER BY ec.submitted_at ASC;

-- View 5: Reimbursement Outstanding
CREATE OR REPLACE VIEW reports.vw_reimbursement_outstanding AS
SELECT
    er.reimbursement_id,
    er.reimbursement_number,
    er.status,
    er.requested_amount,
    er.approved_amount,
    er.paid_amount,
    COALESCE(er.approved_amount, er.requested_amount) - COALESCE(er.paid_amount, 0) AS outstanding_amount,
    er.created_at,
    CURRENT_DATE - er.created_at::DATE AS days_outstanding
FROM expenses.expense_reimbursements er
WHERE er.status IN ('APPROVED', 'PROCESSING', 'PARTIALLY_PAID')
ORDER BY days_outstanding DESC;

-- View 6: Petty Cash Balance
CREATE OR REPLACE VIEW reports.vw_petty_cash_balance AS
SELECT
    pca.petty_cash_account_id,
    pca.account_code,
    pca.account_name,
    pca.opening_balance,
    pca.current_balance,
    pca.maximum_balance,
    pca.status,
    bu.business_unit_name,
    c.code AS currency_code,
    (SELECT COALESCE(SUM(CASE WHEN transaction_type IN ('CASH_IN', 'REPLENISHMENT', 'OPENING_BALANCE') THEN amount ELSE 0 END), 0)
     FROM expenses.petty_cash_transactions pct WHERE pct.petty_cash_account_id = pca.petty_cash_account_id) AS total_in,
    (SELECT COALESCE(SUM(CASE WHEN transaction_type IN ('EXPENSE', 'CASH_OUT') THEN ABS(amount) ELSE 0 END), 0)
     FROM expenses.petty_cash_transactions pct WHERE pct.petty_cash_account_id = pca.petty_cash_account_id) AS total_out
FROM expenses.petty_cash_accounts pca
LEFT JOIN organization.business_units bu ON bu.business_unit_id = pca.business_unit_id
LEFT JOIN reference.currency_lookup c ON c.currency_id = pca.currency_id;

-- View 7: Budget vs Actual
CREATE OR REPLACE VIEW reports.vw_budget_vs_actual AS
SELECT
    eb.expense_budget_id,
    eb.budget_code,
    eb.budget_name,
    d.department_name,
    bu.business_unit_name,
    ecat.name AS category_name,
    eb.budget_amount AS total_budget,
    COALESCE(SUM(ebp.actual_amount), 0) AS total_actual,
    COALESCE(SUM(ebp.committed_amount), 0) AS total_committed,
    eb.budget_amount - COALESCE(SUM(ebp.actual_amount), 0) - COALESCE(SUM(ebp.committed_amount), 0) AS available,
    CASE
        WHEN eb.budget_amount > 0
        THEN ROUND((COALESCE(SUM(ebp.actual_amount), 0) / eb.budget_amount * 100)::NUMERIC, 2)
        ELSE 0
    END AS utilization_percent
FROM expenses.expense_budgets eb
LEFT JOIN expenses.expense_budget_periods ebp ON ebp.expense_budget_id = eb.expense_budget_id
LEFT JOIN organization.departments d ON d.department_id = eb.department_id
LEFT JOIN organization.business_units bu ON bu.business_unit_id = eb.business_unit_id
LEFT JOIN expenses.expense_categories ecat ON ecat.expense_category_id = eb.expense_category_id
GROUP BY eb.expense_budget_id, eb.budget_code, eb.budget_name, d.department_name, bu.business_unit_name, ecat.name, eb.budget_amount
ORDER BY utilization_percent DESC;

-- View 8: Policy Violations
CREATE OR REPLACE VIEW reports.vw_policy_violations AS
SELECT
    epv.expense_policy_violation_id,
    epv.violation_type,
    epv.expected_value,
    epv.actual_value,
    epv.severity,
    epv.status,
    eci.description AS item_description,
    eci.amount AS item_amount,
    ec.claim_number,
    ecat.name AS category_name,
    epv.created_at
FROM expenses.expense_policy_violations epv
JOIN expenses.expense_claim_items eci ON eci.expense_claim_item_id = epv.expense_claim_item_id
JOIN expenses.expense_claims ec ON ec.expense_claim_id = eci.expense_claim_id
JOIN expenses.expense_categories ecat ON ecat.expense_category_id = eci.expense_category_id
ORDER BY epv.severity DESC, epv.created_at DESC;

-- View 9: Recurring Expenses Due
CREATE OR REPLACE VIEW reports.vw_recurring_expenses_due AS
SELECT
    re.recurring_expense_id,
    re.expense_name,
    re.amount,
    re.frequency,
    re.next_due_date,
    re.status,
    ecat.name AS category_name,
    c.code AS currency_code,
    re.next_due_date - CURRENT_DATE AS days_until_due
FROM expenses.recurring_expenses re
JOIN expenses.expense_categories ecat ON ecat.expense_category_id = re.expense_category_id
LEFT JOIN reference.currency_lookup c ON c.currency_id = re.currency_id
WHERE re.status = 'ACTIVE'
ORDER BY re.next_due_date ASC;

-- View 10: Expense Trend Monthly
CREATE OR REPLACE VIEW reports.vw_expense_trend_monthly AS
SELECT
    DATE_TRUNC('month', ec.claim_date) AS expense_month,
    COUNT(DISTINCT ec.expense_claim_id) AS claim_count,
    SUM(ec.total_amount) AS total_amount,
    SUM(ec.approved_amount) AS approved_amount,
    AVG(ec.total_amount) AS avg_claim_amount
FROM expenses.expense_claims ec
WHERE ec.status NOT IN ('DRAFT', 'CANCELLED')
  AND ec.claim_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', ec.claim_date)
ORDER BY expense_month DESC;

-- View 11: Corporate Card Summary
CREATE OR REPLACE VIEW reports.vw_corporate_card_summary AS
SELECT
    cc.corporate_card_id,
    cc.card_provider,
    cc.card_number_masked,
    cc.status,
    cc.credit_limit,
    COUNT(DISTINCT cct.corporate_card_transaction_id) AS transaction_count,
    SUM(cct.amount) AS total_spent,
    SUM(CASE WHEN cct.reconciliation_status = 'UNMATCHED' THEN cct.amount ELSE 0 END) AS unmatched_amount
FROM expenses.corporate_cards cc
LEFT JOIN expenses.corporate_card_transactions cct ON cct.corporate_card_id = cc.corporate_card_id
GROUP BY cc.corporate_card_id, cc.card_provider, cc.card_number_masked, cc.status, cc.credit_limit;

-- View 12: Vehicle Expenses
CREATE OR REPLACE VIEW reports.vw_vehicle_expenses AS
SELECT
    v.vehicle_number,
    v.registration_number,
    v.vehicle_type,
    v.make,
    v.model,
    COUNT(DISTINCT mc.mileage_claim_id) AS mileage_claims,
    SUM(mc.calculated_amount) AS total_mileage_cost,
    SUM(mc.distance) AS total_distance
FROM expenses.vehicles v
LEFT JOIN expenses.mileage_claims mc ON mc.vehicle_id = v.vehicle_id
WHERE v.status = 'ACTIVE'
GROUP BY v.vehicle_id, v.vehicle_number, v.registration_number, v.vehicle_type, v.make, v.model;

-- View 13: Expense Aging
CREATE OR REPLACE VIEW reports.vw_expense_aging AS
SELECT
    ec.expense_claim_id,
    ec.claim_number,
    ec.claim_date,
    ec.total_amount,
    ec.status,
    CURRENT_DATE - ec.claim_date AS age_days,
    CASE
        WHEN CURRENT_DATE - ec.claim_date <= 7 THEN '0-7 Days'
        WHEN CURRENT_DATE - ec.claim_date <= 30 THEN '8-30 Days'
        WHEN CURRENT_DATE - ec.claim_date <= 60 THEN '31-60 Days'
        WHEN CURRENT_DATE - ec.claim_date <= 90 THEN '61-90 Days'
        ELSE '90+ Days'
    END AS aging_bucket
FROM expenses.expense_claims ec
WHERE ec.status IN ('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'PARTIALLY_APPROVED', 'PAYMENT_PENDING')
ORDER BY age_days DESC;

-- View 14: Expense by Payment Method
CREATE OR REPLACE VIEW reports.vw_expense_by_payment_method AS
SELECT
    epm.code AS payment_method_code,
    epm.name AS payment_method_name,
    COUNT(DISTINCT eci.expense_claim_item_id) AS transaction_count,
    SUM(eci.amount) AS total_amount,
    AVG(eci.amount) AS avg_amount
FROM expenses.expense_claim_items eci
LEFT JOIN expenses.expense_payment_methods epm ON epm.expense_payment_method_id = eci.payment_method_id
GROUP BY epm.code, epm.name
ORDER BY total_amount DESC;

-- View 15: Duplicate Expense Detection
CREATE OR REPLACE VIEW reports.vw_duplicate_expense_candidates AS
SELECT *
FROM (
    SELECT
        eci.expense_claim_item_id,
        eci.expense_date,
        eci.merchant_name,
        eci.amount,
        eci.reference_number,
        ec.claim_number,
        COUNT(*) OVER (
            PARTITION BY eci.expense_date, eci.merchant_name, eci.amount
        ) AS potential_duplicates
    FROM expenses.expense_claim_items eci
    JOIN expenses.expense_claims ec ON ec.expense_claim_id = eci.expense_claim_id
    WHERE ec.status NOT IN ('CANCELLED')
      AND eci.merchant_name IS NOT NULL
      AND eci.amount > 0
) sub
WHERE sub.potential_duplicates > 1
ORDER BY sub.expense_date DESC;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Expense Summary
CREATE OR REPLACE FUNCTION reports.get_expense_summary(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    total_claims BIGINT,
    total_amount NUMERIC,
    approved_amount NUMERIC,
    reimbursed_amount NUMERIC,
    pending_count BIGINT,
    avg_claim_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT ec.expense_claim_id),
        SUM(ec.total_amount),
        SUM(COALESCE(ec.approved_amount, 0)),
        SUM(COALESCE(ec.reimbursed_amount, 0)),
        COUNT(DISTINCT CASE WHEN ec.status IN ('SUBMITTED', 'UNDER_REVIEW') THEN ec.expense_claim_id END),
        ROUND(AVG(ec.total_amount)::NUMERIC, 2)
    FROM expenses.expense_claims ec
    WHERE ec.company_id = p_company_id
      AND ec.claim_date BETWEEN p_start_date AND p_end_date
      AND ec.status NOT IN ('DRAFT', 'CANCELLED');
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Employee Expense Report
CREATE OR REPLACE FUNCTION reports.get_employee_expense_report(
    p_employee_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    claim_number VARCHAR,
    claim_date DATE,
    status VARCHAR,
    total_amount NUMERIC,
    approved_amount NUMERIC,
    item_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ec.claim_number::VARCHAR,
        ec.claim_date,
        ec.status::VARCHAR,
        ec.total_amount,
        ec.approved_amount,
        COUNT(DISTINCT eci.expense_claim_item_id)
    FROM expenses.expense_claims ec
    LEFT JOIN expenses.expense_claim_items eci ON eci.expense_claim_id = ec.expense_claim_id
    WHERE ec.employee_id = p_employee_id
      AND ec.claim_date BETWEEN p_start_date AND p_end_date
    GROUP BY ec.expense_claim_id, ec.claim_number, ec.claim_date, ec.status, ec.total_amount, ec.approved_amount
    ORDER BY ec.claim_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Department Expense Report
CREATE OR REPLACE FUNCTION reports.get_department_expense_report(
    p_department_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    department_name VARCHAR,
    claim_count BIGINT,
    total_amount NUMERIC,
    approved_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.department_name::VARCHAR,
        COUNT(DISTINCT ec.expense_claim_id),
        SUM(ec.total_amount),
        SUM(COALESCE(ec.approved_amount, 0))
    FROM expenses.expense_claims ec
    JOIN organization.departments d ON d.department_id = ec.department_id
    WHERE ec.department_id = p_department_id
      AND ec.claim_date BETWEEN p_start_date AND p_end_date
      AND ec.status NOT IN ('DRAFT', 'CANCELLED')
    GROUP BY d.department_name;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Budget Utilization
CREATE OR REPLACE FUNCTION reports.get_budget_utilization(
    p_company_id UUID,
    p_fiscal_year_id UUID DEFAULT NULL
)
RETURNS TABLE (
    department_name VARCHAR,
    category_name VARCHAR,
    budget_amount NUMERIC,
    actual_amount NUMERIC,
    utilization_percent NUMERIC,
    remaining NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.department_name::VARCHAR,
        ecat.name::VARCHAR,
        eb.budget_amount,
        COALESCE(SUM(ebp.actual_amount), 0),
        CASE WHEN eb.budget_amount > 0
            THEN ROUND((COALESCE(SUM(ebp.actual_amount), 0) / eb.budget_amount * 100)::NUMERIC, 2)
            ELSE 0 END,
        eb.budget_amount - COALESCE(SUM(ebp.actual_amount), 0)
    FROM expenses.expense_budgets eb
    LEFT JOIN expenses.expense_budget_periods ebp ON ebp.expense_budget_id = eb.expense_budget_id
    LEFT JOIN organization.departments d ON d.department_id = eb.department_id
    LEFT JOIN expenses.expense_categories ecat ON ecat.expense_category_id = eb.expense_category_id
    WHERE eb.company_id = p_company_id
      AND (p_fiscal_year_id IS NULL OR eb.fiscal_year_id = p_fiscal_year_id)
    GROUP BY eb.expense_budget_id, d.department_name, ecat.name, eb.budget_amount
    ORDER BY utilization_percent DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Check Expense Policy
CREATE OR REPLACE FUNCTION reports.check_expense_policy(
    p_expense_claim_item_id UUID
)
RETURNS TABLE (
    violation_found BOOLEAN,
    violation_type VARCHAR,
    expected_value NUMERIC,
    actual_value NUMERIC,
    severity VARCHAR
) AS $$
DECLARE
    v_item RECORD;
    v_policy_rule RECORD;
BEGIN
    SELECT eci.*, ec.company_id INTO v_item
    FROM expenses.expense_claim_items eci
    JOIN expenses.expense_claims ec ON ec.expense_claim_id = eci.expense_claim_id
    WHERE eci.expense_claim_item_id = p_expense_claim_item_id;

    IF v_item IS NULL THEN
        RETURN QUERY SELECT FALSE, 'ITEM_NOT_FOUND'::VARCHAR, NULL::NUMERIC, NULL::NUMERIC, 'LOW'::VARCHAR;
        RETURN;
    END IF;

    FOR v_policy_rule IN
        SELECT epr.*
        FROM expenses.expense_policy_rules epr
        JOIN expenses.expense_policies ep ON ep.expense_policy_id = epr.expense_policy_id
        WHERE ep.company_id = v_item.company_id
          AND ep.is_active = TRUE
          AND (epr.expense_category_id IS NULL OR epr.expense_category_id = v_item.expense_category_id)
    LOOP
        IF v_policy_rule.maximum_amount IS NOT NULL AND v_item.amount > v_policy_rule.maximum_amount THEN
            RETURN QUERY SELECT TRUE, 'AMOUNT_LIMIT_EXCEEDED'::VARCHAR, v_policy_rule.maximum_amount, v_item.amount, 'HIGH'::VARCHAR;
            RETURN;
        END IF;
    END LOOP;

    RETURN QUERY SELECT FALSE, 'NO_VIOLATION'::VARCHAR, NULL::NUMERIC, NULL::NUMERIC, 'LOW'::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- Function 6: Detect Duplicate Expense
CREATE OR REPLACE FUNCTION reports.detect_duplicate_expense(
    p_expense_claim_item_id UUID
)
RETURNS TABLE (
    is_duplicate BOOLEAN,
    duplicate_count BIGINT,
    matching_items TEXT
) AS $$
DECLARE
    v_item RECORD;
    v_count BIGINT;
BEGIN
    SELECT eci.* INTO v_item
    FROM expenses.expense_claim_items eci
    WHERE eci.expense_claim_item_id = p_expense_claim_item_id;

    IF v_item IS NULL THEN
        RETURN QUERY SELECT FALSE, 0::BIGINT, 'Item not found'::TEXT;
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM expenses.expense_claim_items eci2
    WHERE eci2.expense_claim_item_id <> p_expense_claim_item_id
      AND eci2.expense_date = v_item.expense_date
      AND eci2.amount = v_item.amount
      AND (eci2.merchant_name = v_item.merchant_name OR (eci2.merchant_name IS NULL AND v_item.merchant_name IS NULL));

    RETURN QUERY SELECT v_count > 0, v_count,
        CASE WHEN v_count > 0 THEN 'Potential duplicate found' ELSE 'No duplicates detected' END;
END;
$$ LANGUAGE plpgsql;

-- Function 7: Get Petty Cash Reconciliation
CREATE OR REPLACE FUNCTION reports.get_petty_cash_reconciliation(
    p_petty_cash_account_id UUID
)
RETURNS TABLE (
    opening_balance NUMERIC,
    total_cash_in NUMERIC,
    total_expenses NUMERIC,
    total_cash_out NUMERIC,
    expected_balance NUMERIC,
    current_balance NUMERIC,
    difference NUMERIC
) AS $$
DECLARE
    v_account RECORD;
    v_in NUMERIC;
    v_out NUMERIC;
BEGIN
    SELECT * INTO v_account FROM expenses.petty_cash_accounts WHERE petty_cash_account_id = p_petty_cash_account_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_in
    FROM expenses.petty_cash_transactions
    WHERE petty_cash_account_id = p_petty_cash_account_id
      AND transaction_type IN ('CASH_IN', 'REPLENISHMENT', 'OPENING_BALANCE');

    SELECT COALESCE(SUM(ABS(amount)), 0) INTO v_out
    FROM expenses.petty_cash_transactions
    WHERE petty_cash_account_id = p_petty_cash_account_id
      AND transaction_type IN ('EXPENSE', 'CASH_OUT', 'ADJUSTMENT');

    RETURN QUERY SELECT
        v_account.opening_balance,
        v_in,
        v_out,
        0::NUMERIC,
        v_account.opening_balance + v_in - v_out,
        v_account.current_balance,
        v_account.current_balance - (v_account.opening_balance + v_in - v_out);
END;
$$ LANGUAGE plpgsql;

-- Function 8: Get Expense Trend
CREATE OR REPLACE FUNCTION reports.get_expense_trend(
    p_company_id UUID,
    p_months INTEGER DEFAULT 12
)
RETURNS TABLE (
    expense_month DATE,
    claim_count BIGINT,
    total_amount NUMERIC,
    avg_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC('month', ec.claim_date)::DATE,
        COUNT(DISTINCT ec.expense_claim_id),
        SUM(ec.total_amount),
        ROUND(AVG(ec.total_amount)::NUMERIC, 2)
    FROM expenses.expense_claims ec
    WHERE ec.company_id = p_company_id
      AND ec.claim_date >= CURRENT_DATE - (p_months || ' months')::INTERVAL
      AND ec.status NOT IN ('DRAFT', 'CANCELLED')
    GROUP BY DATE_TRUNC('month', ec.claim_date)
    ORDER BY expense_month DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 9: Get Outstanding Reimbursements
CREATE OR REPLACE FUNCTION reports.get_outstanding_reimbursements(
    p_company_id UUID
)
RETURNS TABLE (
    reimbursement_number VARCHAR,
    employee_id UUID,
    requested_amount NUMERIC,
    approved_amount NUMERIC,
    paid_amount NUMERIC,
    outstanding NUMERIC,
    days_outstanding INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        er.reimbursement_number::VARCHAR,
        er.employee_id,
        er.requested_amount,
        er.approved_amount,
        er.paid_amount,
        COALESCE(er.approved_amount, er.requested_amount) - COALESCE(er.paid_amount, 0),
        (CURRENT_DATE - er.created_at::DATE)
    FROM expenses.expense_reimbursements er
    WHERE er.company_id = p_company_id
      AND er.status IN ('APPROVED', 'PROCESSING', 'PARTIALLY_PAID')
    ORDER BY days_outstanding DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 10: Get Category Expense Breakdown
CREATE OR REPLACE FUNCTION reports.get_category_expense_breakdown(
    p_company_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    category_code VARCHAR,
    category_name VARCHAR,
    parent_category VARCHAR,
    transaction_count BIGINT,
    total_amount NUMERIC,
    percent_of_total NUMERIC
) AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT SUM(eci.amount) INTO v_total
    FROM expenses.expense_claim_items eci
    JOIN expenses.expense_claims ec ON ec.expense_claim_id = eci.expense_claim_id
    WHERE ec.company_id = p_company_id
      AND ec.claim_date BETWEEN p_start_date AND p_end_date
      AND ec.status NOT IN ('DRAFT', 'CANCELLED');

    RETURN QUERY
    SELECT
        ecat.code::VARCHAR,
        ecat.name::VARCHAR,
        pcat.name::VARCHAR,
        COUNT(DISTINCT eci.expense_claim_item_id),
        SUM(eci.amount),
        CASE WHEN v_total > 0 THEN ROUND((SUM(eci.amount) / v_total * 100)::NUMERIC, 2) ELSE 0 END
    FROM expenses.expense_claim_items eci
    JOIN expenses.expense_categories ecat ON ecat.expense_category_id = eci.expense_category_id
    LEFT JOIN expenses.expense_categories pcat ON pcat.expense_category_id = ecat.parent_category_id
    JOIN expenses.expense_claims ec ON ec.expense_claim_id = eci.expense_claim_id
    WHERE ec.company_id = p_company_id
      AND ec.claim_date BETWEEN p_start_date AND p_end_date
      AND ec.status NOT IN ('DRAFT', 'CANCELLED')
    GROUP BY ecat.code, ecat.name, pcat.name
    ORDER BY SUM(eci.amount) DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;