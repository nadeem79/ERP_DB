BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- ============================================================
-- MODULE 13: ACCOUNTING & GENERAL LEDGER REPORTING
-- 20 Views + 5 Functions
-- Matched to actual DB: accounting.journal_entries,
--   accounting.journal_entry_lines, accounting.accounts,
--   accounting.account_types, accounting.customer_receivables,
--   accounting.supplier_payables
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Trial Balance (Monthly, Critical)
-- Complete trial balance with debits, credits, balances
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_trial_balance AS
SELECT
    a.account_code,
    a.account_name,
    at.code                                                   AS account_type,
    at.sort_order,
    a.normal_balance,
    COALESCE(SUM(jel.debit_amount), 0)                        AS total_debit,
    COALESCE(SUM(jel.credit_amount), 0)                       AS total_credit,
    CASE
        WHEN a.normal_balance = 'DEBIT'
        THEN COALESCE(SUM(jel.debit_amount), 0) - COALESCE(SUM(jel.credit_amount), 0)
        ELSE COALESCE(SUM(jel.credit_amount), 0) - COALESCE(SUM(jel.debit_amount), 0)
    END AS balance
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
GROUP BY a.account_code, a.account_name, at.code, at.sort_order, a.normal_balance
ORDER BY at.sort_order, a.account_code;


-- ------------------------------------------------------------
-- Report 2: Profit & Loss Statement (Monthly, Critical)
-- Income statement: revenue, COGS, expenses with net amounts
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_profit_and_loss AS
SELECT
    at.code                                                   AS category_code,
    at.sort_order,
    a.account_code,
    a.account_name,
    SUM(jel.credit_amount) - SUM(jel.debit_amount)            AS net_amount
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND at.is_profit_and_loss = TRUE
GROUP BY at.code, at.sort_order, a.account_code, a.account_name
ORDER BY at.sort_order, a.account_code;


-- ------------------------------------------------------------
-- Report 3: Balance Sheet (Monthly, Critical)
-- Statement of financial position: assets, liabilities, equity
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_balance_sheet AS
SELECT
    at.code                                                   AS category_code,
    at.sort_order,
    a.account_code,
    a.account_name,
    a.normal_balance,
    CASE
        WHEN a.normal_balance = 'DEBIT'
        THEN COALESCE(SUM(jel.debit_amount), 0) - COALESCE(SUM(jel.credit_amount), 0)
        ELSE COALESCE(SUM(jel.credit_amount), 0) - COALESCE(SUM(jel.debit_amount), 0)
    END AS balance
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND at.is_profit_and_loss = FALSE
GROUP BY at.code, at.sort_order, a.account_code, a.account_name, a.normal_balance
ORDER BY at.sort_order, a.account_code;


-- ------------------------------------------------------------
-- Report 4: Cash Flow Statement (Monthly, Critical)
-- Cash and bank account inflows and outflows by month
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_cash_flow AS
SELECT
    DATE_TRUNC('month', je.posted_at)                         AS flow_month,
    a.account_code,
    a.account_name,
    SUM(jel.debit_amount)                                     AS cash_inflow,
    SUM(jel.credit_amount)                                    AS cash_outflow,
    SUM(jel.debit_amount) - SUM(jel.credit_amount)            AS net_cash_flow
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND (a.account_code LIKE '1000%' OR a.account_code LIKE '1100%'
       OR LOWER(a.account_name) LIKE '%cash%' OR LOWER(a.account_name) LIKE '%bank%')
GROUP BY DATE_TRUNC('month', je.posted_at), a.account_code, a.account_name
ORDER BY flow_month DESC;


-- ------------------------------------------------------------
-- Report 5: General Ledger (Monthly, Critical)
-- Detailed transaction ledger with all posted journal entries
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_general_ledger AS
SELECT
    je.journal_entry_id,
    je.status                                                 AS entry_status,
    a.account_code,
    a.account_name,
    at.code                                                   AS account_type,
    jel.description                                           AS line_description,
    jel.debit_amount,
    jel.credit_amount,
    jel.base_debit_amount,
    jel.base_credit_amount,
    je.posted_at
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
ORDER BY je.posted_at DESC, a.account_code;


-- ------------------------------------------------------------
-- Report 6: Accounts Receivable Aging (Weekly, Critical)
-- Outstanding receivables by age bucket
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_accounts_receivable_aging AS
SELECT
    COALESCE(c.first_name || ' ' || c.last_name, 'Unknown')   AS customer_name,
    ar.transaction_date,
    ar.due_date,
    ar.original_amount,
    ar.outstanding_amount,
    CURRENT_DATE - ar.due_date                                AS days_overdue,
    CASE
        WHEN CURRENT_DATE <= ar.due_date              THEN 'Current'
        WHEN CURRENT_DATE - ar.due_date <= 30         THEN '1-30 Days'
        WHEN CURRENT_DATE - ar.due_date <= 60         THEN '31-60 Days'
        WHEN CURRENT_DATE - ar.due_date <= 90         THEN '61-90 Days'
        ELSE '90+ Days'
    END AS aging_bucket
FROM accounting.customer_receivables ar
LEFT JOIN crm.customers c ON c.customer_id = ar.customer_id
WHERE ar.status IN ('OPEN', 'PARTIALLY_PAID')
  AND ar.outstanding_amount > 0
ORDER BY days_overdue DESC;


-- ------------------------------------------------------------
-- Report 7: Accounts Payable Aging (Weekly, Critical)
-- Outstanding payables by age bucket and supplier
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_accounts_payable_aging AS
SELECT
    s.supplier_name,
    ap.transaction_date,
    ap.due_date,
    ap.original_amount,
    ap.paid_amount,
    ap.outstanding_amount,
    CURRENT_DATE - ap.due_date                                AS days_overdue,
    CASE
        WHEN CURRENT_DATE <= ap.due_date              THEN 'Current'
        WHEN CURRENT_DATE - ap.due_date <= 30         THEN '1-30 Days'
        WHEN CURRENT_DATE - ap.due_date <= 60         THEN '31-60 Days'
        WHEN CURRENT_DATE - ap.due_date <= 90         THEN '61-90 Days'
        ELSE '90+ Days'
    END AS aging_bucket
FROM accounting.supplier_payables ap
LEFT JOIN purchasing.suppliers s ON s.supplier_id = ap.supplier_id
WHERE ap.status IN ('OPEN', 'PARTIALLY_PAID')
  AND ap.outstanding_amount > 0
ORDER BY days_overdue DESC;


-- ------------------------------------------------------------
-- Report 8: Bank Reconciliation (Monthly, Critical)
-- Bank statement reconciliation status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_bank_reconciliation AS
SELECT
    psr.pos_shift_reconciliation_id,
    psr.company_id,
    ps.shift_number,
    DATE(ps.opened_at)                                        AS shift_date,
    psr.expected_cash,
    psr.actual_cash,
    psr.cash_difference,
    psr.expected_card,
    psr.actual_card,
    psr.card_difference,
    psr.expected_other,
    psr.actual_other,
    psr.other_difference,
    psr.status,
    psr.reconciled_at
FROM pos.pos_shift_reconciliations psr
LEFT JOIN pos.pos_shifts ps ON ps.pos_shift_id = psr.pos_shift_id
ORDER BY psr.reconciled_at DESC NULLS LAST;


-- ------------------------------------------------------------
-- Report 9: Tax Summary (Monthly, Critical)
-- Tax collected and paid by month
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_tax_summary AS
SELECT
    tt.code                                                   AS tax_type_code,
    tt.name                                                   AS tax_type_name,
    tc.name                                                   AS tax_category_name,
    tr.rate                                                   AS tax_rate_percent,
    tr.is_inclusive,
    tr.start_date,
    tr.end_date,
    tr.is_active
FROM pricing.tax_rates tr
JOIN pricing.tax_types tt ON tt.tax_type_id = tr.tax_type_id
JOIN pricing.tax_categories tc ON tc.tax_category_id = tr.tax_category_id
WHERE tr.is_active = TRUE
  AND (tr.end_date IS NULL OR tr.end_date >= CURRENT_DATE)
ORDER BY tt.code, tc.name;


-- ------------------------------------------------------------
-- Report 10: Journal Entry Summary (Monthly, Critical)
-- All journal entries by date and status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_journal_entry_summary AS
SELECT
    DATE(je.posted_at)                                        AS entry_date,
    je.status,
    COUNT(DISTINCT je.journal_entry_id)                       AS entry_count,
    SUM(jel.debit_amount)                                     AS total_debits,
    SUM(jel.credit_amount)                                    AS total_credits
FROM accounting.journal_entries je
JOIN accounting.journal_entry_lines jel ON jel.journal_entry_id = je.journal_entry_id
WHERE je.posted_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(je.posted_at), je.status
ORDER BY entry_date DESC;


-- ------------------------------------------------------------
-- Report 11: Expense by Cost Center (Monthly, Important)
-- Expenses by cost center / business unit
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_expense_by_cost_center AS
SELECT
    bu.business_unit_name,
    COUNT(DISTINCT ec.expense_claim_id)                       AS claim_count,
    SUM(ec.total_amount)                                      AS total_expense,
    SUM(ec.approved_amount)                                   AS approved_amount,
    AVG(ec.total_amount)                                      AS avg_claim_amount
FROM expenses.expense_claims ec
LEFT JOIN organization.business_units bu ON bu.business_unit_id = ec.business_unit_id
WHERE ec.status NOT IN ('DRAFT', 'CANCELLED')
GROUP BY bu.business_unit_name
ORDER BY total_expense DESC NULLS LAST;


-- ------------------------------------------------------------
-- Report 12: Expense by Department (Monthly, Important)
-- Expenses by department
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_expense_by_department AS
SELECT
    d.department_name,
    COUNT(DISTINCT ec.expense_claim_id)                       AS claim_count,
    SUM(ec.total_amount)                                      AS total_expense,
    SUM(ec.approved_amount)                                   AS approved_amount,
    AVG(ec.total_amount)                                      AS avg_claim_amount
FROM expenses.expense_claims ec
LEFT JOIN organization.departments d ON d.department_id = ec.department_id
WHERE ec.status NOT IN ('DRAFT', 'CANCELLED')
GROUP BY d.department_name
ORDER BY total_expense DESC NULLS LAST;


-- ------------------------------------------------------------
-- Report 13: Budget vs Actual (Monthly, Critical)
-- Budget variance analysis
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_budget_vs_actual AS
SELECT
    d.department_name,
    ecat.name                                                 AS category_name,
    eb.budget_amount                                          AS total_budget,
    COALESCE(SUM(ebp.actual_amount), 0)                       AS total_actual,
    COALESCE(SUM(ebp.committed_amount), 0)                    AS total_committed,
    eb.budget_amount
      - COALESCE(SUM(ebp.actual_amount), 0)
      - COALESCE(SUM(ebp.committed_amount), 0)                AS available,
    CASE
        WHEN eb.budget_amount > 0
        THEN ROUND((COALESCE(SUM(ebp.actual_amount), 0) / eb.budget_amount * 100)::NUMERIC, 2)
        ELSE 0
    END AS utilization_percent
FROM expenses.expense_budgets eb
LEFT JOIN expenses.expense_budget_periods ebp ON ebp.expense_budget_id = eb.expense_budget_id
LEFT JOIN organization.departments d ON d.department_id = eb.department_id
LEFT JOIN expenses.expense_categories ecat ON ecat.expense_category_id = eb.expense_category_id
GROUP BY eb.expense_budget_id, d.department_name, ecat.name, eb.budget_amount
ORDER BY utilization_percent DESC;


-- ------------------------------------------------------------
-- Report 14: Fixed Asset Register (Quarterly, Important)
-- All fixed assets (placeholder for fixed asset module)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_fixed_asset_register AS
SELECT
    a.account_code,
    a.account_name,
    COALESCE(SUM(jel.debit_amount), 0) - COALESCE(SUM(jel.credit_amount), 0) AS net_book_value
FROM accounting.accounts a
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
LEFT JOIN accounting.journal_entry_lines jel ON jel.account_id = a.account_id
LEFT JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id AND je.status = 'POSTED'
WHERE at.code = 'ASSET'
  AND a.is_profit_and_loss = FALSE
GROUP BY a.account_code, a.account_name
ORDER BY a.account_code;


-- ------------------------------------------------------------
-- Report 15: Depreciation Schedule (Monthly, Important)
-- Asset depreciation schedule (derived from asset accounts)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_depreciation_schedule AS
SELECT
    DATE_TRUNC('month', je.posted_at)                         AS depreciation_month,
    a.account_code,
    a.account_name,
    SUM(jel.debit_amount)                                     AS depreciation_expense
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND at.code IN ('EXPENSE', 'COGS')
  AND LOWER(a.account_name) LIKE '%depreciation%'
GROUP BY DATE_TRUNC('month', je.posted_at), a.account_code, a.account_name
ORDER BY depreciation_month DESC;


-- ------------------------------------------------------------
-- Report 16: Sales Tax Report (Monthly, Critical)
-- Sales tax collected by month
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_tax AS
SELECT
    DATE_TRUNC('month', je.posted_at)                         AS tax_month,
    a.account_code,
    a.account_name,
    SUM(jel.credit_amount) - SUM(jel.debit_amount)            AS net_tax_collected
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND (a.account_code LIKE '22%' OR LOWER(a.account_name) LIKE '%sales tax%')
GROUP BY DATE_TRUNC('month', je.posted_at), a.account_code, a.account_name
ORDER BY tax_month DESC;


-- ------------------------------------------------------------
-- Report 17: Purchase Tax Report (Monthly, Critical)
-- Purchase tax paid by month
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_purchase_tax AS
SELECT
    DATE_TRUNC('month', je.posted_at)                         AS tax_month,
    a.account_code,
    a.account_name,
    SUM(jel.debit_amount) - SUM(jel.credit_amount)            AS net_purchase_tax
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND (a.account_code LIKE '15%' OR LOWER(a.account_name) LIKE '%purchase tax%'
       OR LOWER(a.account_name) LIKE '%input tax%')
GROUP BY DATE_TRUNC('month', je.posted_at), a.account_code, a.account_name
ORDER BY tax_month DESC;


-- ------------------------------------------------------------
-- Report 18: Withholding Tax Report (Monthly, Critical)
-- Withholding tax deductions by month
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_withholding_tax AS
SELECT
    DATE_TRUNC('month', je.posted_at)                         AS tax_month,
    a.account_code,
    a.account_name,
    SUM(jel.credit_amount) - SUM(jel.debit_amount)            AS net_withholding
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND (a.account_code LIKE '23%' OR LOWER(a.account_name) LIKE '%withholding%'
       OR LOWER(a.account_name) LIKE '%wht%')
GROUP BY DATE_TRUNC('month', je.posted_at), a.account_code, a.account_name
ORDER BY tax_month DESC;


-- ------------------------------------------------------------
-- Report 19: Revenue Recognition Schedule (Monthly, Critical)
-- Revenue recognition by month and account
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_revenue_recognition AS
SELECT
    DATE_TRUNC('month', je.posted_at)                         AS revenue_month,
    a.account_code,
    a.account_name,
    SUM(jel.credit_amount) - SUM(jel.debit_amount)            AS recognized_revenue,
    COUNT(DISTINCT je.journal_entry_id)                       AS entry_count
FROM accounting.journal_entry_lines jel
JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
JOIN accounting.accounts a ON a.account_id = jel.account_id
JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
WHERE je.status = 'POSTED'
  AND at.code IN ('REVENUE', 'INCOME')
GROUP BY DATE_TRUNC('month', je.posted_at), a.account_code, a.account_name
ORDER BY revenue_month DESC;


-- ------------------------------------------------------------
-- Report 20: Gross Profit Analysis (Monthly, Critical)
-- Gross profit by product with margin percentage
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_gross_profit_analysis AS
SELECT
    DATE_TRUNC('month', o.order_date)                         AS profit_month,
    p.product_code,
    p.product_name,
    SUM(oi.quantity)                                          AS total_qty_sold,
    SUM(oi.final_amount)                                      AS total_revenue,
    SUM(oi.cost_snapshot * oi.quantity)                       AS total_cogs,
    SUM(oi.final_amount) - SUM(oi.cost_snapshot * oi.quantity) AS gross_profit,
    CASE
        WHEN SUM(oi.final_amount) > 0
        THEN ROUND(((SUM(oi.final_amount) - SUM(oi.cost_snapshot * oi.quantity))
            / SUM(oi.final_amount) * 100)::NUMERIC, 2)
        ELSE 0
    END AS gross_margin_percent
FROM sales.order_items oi
JOIN sales.orders o ON o.order_id = oi.order_id
JOIN catalog.product_variants v ON v.variant_id = oi.variant_id
JOIN catalog.products p ON p.product_id = v.product_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '365 days'
GROUP BY DATE_TRUNC('month', o.order_date), p.product_code, p.product_name
ORDER BY profit_month DESC, gross_profit DESC;


-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Trial Balance for Period
CREATE OR REPLACE FUNCTION reports.fn_trial_balance(
    p_start_date DATE,
    p_end_date   DATE
)
RETURNS TABLE (
    account_code  VARCHAR,
    account_name  VARCHAR,
    account_type  VARCHAR,
    total_debit   NUMERIC,
    total_credit  NUMERIC,
    balance       NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.account_code::VARCHAR,
        a.account_name::VARCHAR,
        at.code::VARCHAR,
        COALESCE(SUM(jel.debit_amount), 0),
        COALESCE(SUM(jel.credit_amount), 0),
        CASE
            WHEN a.normal_balance = 'DEBIT'
            THEN COALESCE(SUM(jel.debit_amount), 0) - COALESCE(SUM(jel.credit_amount), 0)
            ELSE COALESCE(SUM(jel.credit_amount), 0) - COALESCE(SUM(jel.debit_amount), 0)
        END
    FROM accounting.journal_entry_lines jel
    JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
    JOIN accounting.accounts a ON a.account_id = jel.account_id
    JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
    WHERE je.status = 'POSTED'
      AND je.posted_at BETWEEN p_start_date AND p_end_date
    GROUP BY a.account_code, a.account_name, at.code, at.sort_order, a.normal_balance
    ORDER BY at.sort_order, a.account_code;
END;
$$ LANGUAGE plpgsql;


-- Function 2: Get P&L for Period
CREATE OR REPLACE FUNCTION reports.fn_profit_and_loss(
    p_start_date DATE,
    p_end_date   DATE
)
RETURNS TABLE (
    category_code VARCHAR,
    account_name  VARCHAR,
    net_amount    NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        at.code::VARCHAR,
        a.account_name::VARCHAR,
        SUM(jel.credit_amount) - SUM(jel.debit_amount)
    FROM accounting.journal_entry_lines jel
    JOIN accounting.journal_entries je ON je.journal_entry_id = jel.journal_entry_id
    JOIN accounting.accounts a ON a.account_id = jel.account_id
    JOIN accounting.account_types at ON at.account_type_id = a.account_type_id
    WHERE je.status = 'POSTED'
      AND at.is_profit_and_loss = TRUE
      AND je.posted_at BETWEEN p_start_date AND p_end_date
    GROUP BY at.code, at.sort_order, a.account_code, a.account_name
    ORDER BY at.sort_order, a.account_code;
END;
$$ LANGUAGE plpgsql;


-- Function 3: Get AR Aging Summary
CREATE OR REPLACE FUNCTION reports.fn_ar_aging_summary()
RETURNS TABLE (
    aging_bucket      VARCHAR,
    invoice_count     BIGINT,
    total_outstanding NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN CURRENT_DATE <= ar.due_date        THEN 'Current'
            WHEN CURRENT_DATE - ar.due_date <= 30   THEN '1-30 Days'
            WHEN CURRENT_DATE - ar.due_date <= 60   THEN '31-60 Days'
            WHEN CURRENT_DATE - ar.due_date <= 90   THEN '61-90 Days'
            ELSE '90+ Days'
        END::VARCHAR,
        COUNT(DISTINCT ar.receivable_id),
        COALESCE(SUM(ar.outstanding_amount), 0)
    FROM accounting.customer_receivables ar
    WHERE ar.status IN ('OPEN', 'PARTIALLY_PAID')
      AND ar.outstanding_amount > 0
    GROUP BY 1
    ORDER BY MIN(CURRENT_DATE - ar.due_date);
END;
$$ LANGUAGE plpgsql;


-- Function 4: Get AP Aging Summary
CREATE OR REPLACE FUNCTION reports.fn_ap_aging_summary()
RETURNS TABLE (
    aging_bucket      VARCHAR,
    invoice_count     BIGINT,
    total_outstanding NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN CURRENT_DATE <= ap.due_date        THEN 'Current'
            WHEN CURRENT_DATE - ap.due_date <= 30   THEN '1-30 Days'
            WHEN CURRENT_DATE - ap.due_date <= 60   THEN '31-60 Days'
            WHEN CURRENT_DATE - ap.due_date <= 90   THEN '61-90 Days'
            ELSE '90+ Days'
        END::VARCHAR,
        COUNT(DISTINCT ap.payable_id),
        COALESCE(SUM(ap.outstanding_amount), 0)
    FROM accounting.supplier_payables ap
    WHERE ap.status IN ('OPEN', 'PARTIALLY_PAID')
      AND ap.outstanding_amount > 0
    GROUP BY 1
    ORDER BY MIN(CURRENT_DATE - ap.due_date);
END;
$$ LANGUAGE plpgsql;


-- Function 5: Get Gross Profit by Period
CREATE OR REPLACE FUNCTION reports.fn_gross_profit(
    p_start_date DATE,
    p_end_date   DATE
)
RETURNS TABLE (
    profit_month       DATE,
    total_revenue      NUMERIC,
    total_cogs         NUMERIC,
    gross_profit       NUMERIC,
    gross_margin_pct   NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE,
        SUM(oi.final_amount),
        SUM(oi.cost_snapshot * oi.quantity),
        SUM(oi.final_amount) - SUM(oi.cost_snapshot * oi.quantity),
        CASE
            WHEN SUM(oi.final_amount) > 0
            THEN ROUND(((SUM(oi.final_amount) - SUM(oi.cost_snapshot * oi.quantity))
                / SUM(oi.final_amount) * 100)::NUMERIC, 2)
            ELSE 0
        END
    FROM sales.order_items oi
    JOIN sales.orders o ON o.order_id = oi.order_id
    WHERE o.order_date BETWEEN p_start_date AND p_end_date
    GROUP BY DATE_TRUNC('month', o.order_date)
    ORDER BY profit_month;
END;
$$ LANGUAGE plpgsql;


COMMIT;

-- ============================================================
-- SUMMARY: Module 13 Accounting
-- 20 Views + 5 Functions = 25 Report Objects
-- 20 Reports as per reports02.html catalog
-- ============================================================