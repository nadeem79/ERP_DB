BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 02: ORGANIZATION / COMPANY / BUSINESS UNITS REPORTING
-- 20 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: Company Overview (Monthly, Critical)
-- Multi-company structure summary
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_company_overview AS
SELECT
    c.company_id,
    c.company_code,
    c.company_name,
    ctl.name AS company_type,
    c.is_active,
    COUNT(DISTINCT bu.business_unit_id) AS business_unit_count,
    COUNT(DISTINCT dept.department_id) AS department_count,
    COUNT(DISTINCT br.branch_id) AS branch_count,
    COUNT(DISTINCT st.store_id) AS store_count,
    COUNT(DISTINCT wh.warehouse_id) AS warehouse_count,
    COUNT(DISTINCT emp.employee_id) AS employee_count
FROM organization.companies c
LEFT JOIN organization.company_type_lookup ctl ON ctl.company_type_id = c.company_type_id
LEFT JOIN organization.business_units bu ON bu.company_id = c.company_id AND bu.is_active = TRUE
LEFT JOIN organization.departments dept ON dept.company_id = c.company_id AND dept.is_active = TRUE
LEFT JOIN organization.branches br ON br.company_id = c.company_id AND br.is_active = TRUE
LEFT JOIN organization.stores st ON st.company_id = c.company_id AND st.is_active = TRUE
LEFT JOIN organization.warehouses wh ON wh.company_id = c.company_id AND wh.is_active = TRUE
LEFT JOIN identity.employees emp ON emp.company_id = c.company_id AND emp.is_active = TRUE
GROUP BY c.company_id, c.company_code, c.company_name, ctl.name, c.is_active
ORDER BY c.company_name;

-- ------------------------------------------------------------
-- Report 2: Business Unit Hierarchy (Monthly, Critical)
-- Organizational structure tree
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_business_unit_hierarchy AS
SELECT
    bu.business_unit_id,
    bu.business_unit_code,
    bu.business_unit_name,
    but.code AS business_unit_type,
    c.company_name,
    COUNT(DISTINCT dept.department_id) AS department_count,
    COUNT(DISTINCT emp.employee_id) AS employee_count,
    bu.is_active
FROM organization.business_units bu
JOIN organization.companies c ON c.company_id = bu.company_id
LEFT JOIN organization.business_unit_type_lookup but ON but.business_unit_type_id = bu.business_unit_type_id
LEFT JOIN organization.departments dept ON dept.business_unit_id = bu.business_unit_id AND dept.is_active = TRUE
LEFT JOIN organization.employee_assignments ea ON ea.business_unit_id = bu.business_unit_id AND ea.is_active = TRUE
LEFT JOIN identity.employees emp ON emp.employee_id = ea.employee_id AND emp.is_active = TRUE
GROUP BY bu.business_unit_id, bu.business_unit_code, bu.business_unit_name, but.code, c.company_name, bu.is_active
ORDER BY bu.business_unit_name;

-- ------------------------------------------------------------
-- Report 3: Department Headcount (Monthly, Critical)
-- Employees by department
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_department_headcount AS
SELECT
    dept.department_id,
    dept.department_code,
    dept.department_name,
    bu.business_unit_name,
    COUNT(DISTINCT ea.employee_id) AS employee_count,
    COUNT(DISTINCT CASE WHEN emp.is_active = TRUE THEN ea.employee_id END) AS active_employees,
    dept.is_active
FROM organization.departments dept
LEFT JOIN organization.business_units bu ON bu.business_unit_id = dept.business_unit_id
LEFT JOIN organization.employee_assignments ea ON ea.department_id = dept.department_id AND ea.is_active = TRUE
LEFT JOIN identity.employees emp ON emp.employee_id = ea.employee_id
GROUP BY dept.department_id, dept.department_code, dept.department_name, bu.business_unit_name, dept.is_active
ORDER BY employee_count DESC;

-- ------------------------------------------------------------
-- Report 4: Branch Operations (Monthly, Critical)
-- Performance by branch
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_branch_operations AS
SELECT
    br.branch_id,
    br.branch_code,
    br.branch_name,
    bt.name AS branch_type,
    br.city,
    COUNT(DISTINCT st.store_id) AS store_count,
    COUNT(DISTINCT wh.warehouse_id) AS warehouse_count,
    COUNT(DISTINCT ea.employee_id) AS employee_count,
    br.is_active
FROM organization.branches br
LEFT JOIN organization.branch_type_lookup bt ON bt.branch_type_id = br.branch_type_id
LEFT JOIN organization.stores st ON st.branch_id = br.branch_id AND st.is_active = TRUE
LEFT JOIN organization.warehouses wh ON wh.branch_id = br.branch_id AND wh.is_active = TRUE
LEFT JOIN organization.employee_assignments ea ON ea.branch_id = br.branch_id AND ea.is_active = TRUE
GROUP BY br.branch_id, br.branch_code, br.branch_name, bt.name, br.city, br.is_active
ORDER BY employee_count DESC;

-- ------------------------------------------------------------
-- Report 5: Store Performance (Weekly, Critical)
-- Sales by physical store
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_store_performance AS
SELECT
    st.store_id,
    st.store_code,
    st.store_name,
    stt.name AS store_type,
    st.city,
    br.branch_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.grand_total) AS total_revenue,
    AVG(o.grand_total) AS avg_order_value,
    st.is_active
FROM organization.stores st
LEFT JOIN organization.store_type_lookup stt ON stt.store_type_id = st.store_type_id
LEFT JOIN organization.branches br ON br.branch_id = st.branch_id
LEFT JOIN sales.orders o ON o.store_id = st.store_id
GROUP BY st.store_id, st.store_code, st.store_name, stt.name, st.city, br.branch_name, st.is_active
ORDER BY total_revenue DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 6: Warehouse Utilization (Daily, Critical)
-- Inventory by warehouse
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_warehouse_utilization AS
SELECT
    wh.warehouse_id,
    wh.warehouse_code,
    wh.warehouse_name,
    wt.name AS warehouse_type,
    COUNT(DISTINCT i.product_variant_id) AS unique_skus,
    SUM(i.quantity_on_hand) AS total_on_hand,
    SUM(i.quantity_reserved) AS total_reserved,
    SUM(i.quantity_on_hand - i.quantity_reserved) AS available_quantity,
    wh.is_active
FROM organization.warehouses wh
LEFT JOIN organization.warehouse_type_lookup wt ON wt.warehouse_type_id = wh.warehouse_type_id
LEFT JOIN inventory.inventories i ON i.warehouse_id = wh.warehouse_id
GROUP BY wh.warehouse_id, wh.warehouse_code, wh.warehouse_name, wt.name, wh.is_active
ORDER BY total_on_hand DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 7: Sales Channel Analysis (Weekly, Critical)
-- Orders by sales channel
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_channel_analysis AS
SELECT
    sc.channel_code,
    sc.channel_name,
    sc.channel_type,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.grand_total) AS total_revenue,
    AVG(o.grand_total) AS avg_order_value,
    sc.is_active
FROM organization.sales_channels sc
LEFT JOIN sales.orders o ON o.sales_channel_id = sc.sales_channel_id
GROUP BY sc.sales_channel_id, sc.channel_code, sc.channel_name, sc.channel_type, sc.is_active
ORDER BY total_revenue DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 8: Employee Assignment (Monthly, Important)
-- Employees by org unit
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_employee_assignment AS
SELECT
    emp.employee_id,
    emp.employee_code,
    emp.employee_name,
    bu.business_unit_name,
    dept.department_name,
    br.branch_name,
    st.store_name,
    wh.warehouse_name,
    ea.assignment_type,
    ea.is_primary,
    ea.is_active
FROM organization.employee_assignments ea
JOIN identity.employees emp ON emp.employee_id = ea.employee_id
LEFT JOIN organization.business_units bu ON bu.business_unit_id = ea.business_unit_id
LEFT JOIN organization.departments dept ON dept.department_id = ea.department_id
LEFT JOIN organization.branches br ON br.branch_id = ea.branch_id
LEFT JOIN organization.stores st ON st.store_id = ea.store_id
LEFT JOIN organization.warehouses wh ON wh.warehouse_id = ea.warehouse_id
ORDER BY emp.employee_name;

-- ------------------------------------------------------------
-- Report 9: Company Settings Audit (Quarterly, Important)
-- Configuration compliance
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_company_settings_audit AS
SELECT
    c.company_code,
    c.company_name,
    cs.setting_key,
    cs.setting_value,
    cs.setting_type,
    cs.is_active,
    cs.created_at,
    cs.updated_at
FROM organization.company_settings cs
JOIN organization.companies c ON c.company_id = cs.company_id
ORDER BY c.company_name, cs.setting_key;

-- ------------------------------------------------------------
-- Report 10: Multi-Currency Setup (Monthly, Standard)
-- Companies by base currency
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_multi_currency_setup AS
SELECT
    c.company_code,
    c.company_name,
    cs.setting_value AS base_currency,
    c.country_code,
    c.is_active
FROM organization.companies c
LEFT JOIN organization.company_settings cs ON cs.company_id = c.company_id AND cs.setting_key = 'BASE_CURRENCY'
ORDER BY c.company_name;

-- ------------------------------------------------------------
-- Report 11: Store Warehouse Mapping (Monthly, Important)
-- Fulfillment location relationships
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_store_warehouse_mapping AS
SELECT
    st.store_code,
    st.store_name,
    st.city AS store_city,
    wh.warehouse_code,
    wh.warehouse_name,
    wt.name AS warehouse_type,
    wh.city AS warehouse_city,
    st.is_active AS store_active,
    wh.is_active AS warehouse_active
FROM organization.stores st
LEFT JOIN organization.branches br ON br.branch_id = st.branch_id
LEFT JOIN organization.warehouses wh ON wh.branch_id = br.branch_id
LEFT JOIN organization.warehouse_type_lookup wt ON wt.warehouse_type_id = wh.warehouse_type_id
ORDER BY st.store_name, wh.warehouse_name;

-- ------------------------------------------------------------
-- Report 12: Branch Geographic Distribution (Quarterly, Standard)
-- Locations by region/city
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_branch_geographic_distribution AS
SELECT
    br.city,
    sl.name AS state_name,
    cl.name AS country_name,
    COUNT(DISTINCT br.branch_id) AS branch_count,
    COUNT(DISTINCT st.store_id) AS store_count,
    COUNT(DISTINCT wh.warehouse_id) AS warehouse_count
FROM organization.branches br
LEFT JOIN reference.state_lookup sl ON sl.state_id = br.state_id
LEFT JOIN reference.country_lookup cl ON cl.country_id = br.country_id
LEFT JOIN organization.stores st ON st.branch_id = br.branch_id AND st.is_active = TRUE
LEFT JOIN organization.warehouses wh ON wh.branch_id = br.branch_id AND wh.is_active = TRUE
WHERE br.is_active = TRUE
GROUP BY br.city, sl.name, cl.name
ORDER BY branch_count DESC;

-- ------------------------------------------------------------
-- Report 13: Organizational Changes (Monthly, Important)
-- Structure modifications
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_organizational_changes AS
SELECT
    'Business Unit' AS entity_type,
    bu.business_unit_name AS entity_name,
    bu.created_at AS created_at,
    bu.updated_at AS updated_at,
    bu.is_active
FROM organization.business_units bu
UNION ALL
SELECT
    'Department' AS entity_type,
    dept.department_name AS entity_name,
    dept.created_at AS created_at,
    dept.updated_at AS updated_at,
    dept.is_active
FROM organization.departments dept
UNION ALL
SELECT
    'Branch' AS entity_type,
    br.branch_name AS entity_name,
    br.created_at AS created_at,
    br.updated_at AS updated_at,
    br.is_active
FROM organization.branches br
UNION ALL
SELECT
    'Store' AS entity_type,
    st.store_name AS entity_name,
    st.created_at AS created_at,
    st.updated_at AS updated_at,
    st.is_active
FROM organization.stores st
UNION ALL
SELECT
    'Warehouse' AS entity_type,
    wh.warehouse_name AS entity_name,
    wh.created_at AS created_at,
    wh.updated_at AS updated_at,
    wh.is_active
FROM organization.warehouses wh
ORDER BY created_at DESC;

-- ------------------------------------------------------------
-- Report 14: Inactive Business Units (Quarterly, Standard)
-- Dormant organizational entities
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_inactive_business_units AS
SELECT
    bu.business_unit_id,
    bu.business_unit_code,
    bu.business_unit_name,
    but.name AS business_unit_type,
    c.company_name,
    bu.created_at,
    bu.updated_at
FROM organization.business_units bu
JOIN organization.companies c ON c.company_id = bu.company_id
LEFT JOIN organization.business_unit_type_lookup but ON but.business_unit_type_id = bu.business_unit_type_id
WHERE bu.is_active = FALSE
ORDER BY bu.updated_at DESC;

-- ------------------------------------------------------------
-- Report 15: Sales Channel Performance (Monthly, Critical)
-- Revenue by channel type
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_sales_channel_performance AS
SELECT
    sc.channel_type,
    COUNT(DISTINCT sc.sales_channel_id) AS channel_count,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.grand_total) AS total_revenue,
    AVG(o.grand_total) AS avg_order_value
FROM organization.sales_channels sc
LEFT JOIN sales.orders o ON o.sales_channel_id = sc.sales_channel_id
GROUP BY sc.channel_type
ORDER BY total_revenue DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 16: Employee Summary (Monthly, Important)
-- Employee overview by company
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_employee_summary AS
SELECT
    c.company_code,
    c.company_name,
    COUNT(DISTINCT emp.employee_id) AS total_employees,
    COUNT(DISTINCT CASE WHEN emp.is_active = TRUE THEN emp.employee_id END) AS active_employees,
    COUNT(DISTINCT CASE WHEN emp.is_active = FALSE THEN emp.employee_id END) AS inactive_employees,
    COUNT(DISTINCT CASE WHEN et.code = 'FULL_TIME' THEN emp.employee_id END) AS full_time_employees,
    COUNT(DISTINCT CASE WHEN et.code = 'PART_TIME' THEN emp.employee_id END) AS part_time_employees,
    COUNT(DISTINCT CASE WHEN et.code = 'CONTRACT' THEN emp.employee_id END) AS contract_employees
FROM organization.companies c
LEFT JOIN identity.employees emp ON emp.company_id = c.company_id
LEFT JOIN identity.employment_type_lookup et ON et.employment_type_id = emp.employment_type_id
GROUP BY c.company_id, c.company_code, c.company_name
ORDER BY total_employees DESC;

-- ------------------------------------------------------------
-- Report 17: Employee Leave Report (Monthly, Important)
-- Leave requests by status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_employee_leave_report AS
SELECT
    emp.employee_code,
    emp.employee_name,
    el.leave_type,
    el.start_date,
    el.end_date,
    el.status,
    el.reason,
    el.created_at
FROM organization.employee_leaves el
JOIN identity.employees emp ON emp.employee_id = el.employee_id
ORDER BY el.start_date DESC;

-- ------------------------------------------------------------
-- Report 18: Employee Attendance Report (Daily, Important)
-- Attendance by employee
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_employee_attendance_report AS
SELECT
    emp.employee_code,
    emp.employee_name,
    ea.attendance_date,
    ea.check_in_time,
    ea.check_out_time,
    ea.status,
    ea.notes
FROM organization.employee_attendance ea
JOIN identity.employees emp ON emp.employee_id = ea.employee_id
WHERE ea.attendance_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY ea.attendance_date DESC;

-- ------------------------------------------------------------
-- Report 19: Employee Payroll Report (Monthly, Important)
-- Payroll by employee
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_employee_payroll_report AS
SELECT
    emp.employee_code,
    emp.employee_name,
    ep.payroll_period,
    ep.payroll_month,
    ep.payroll_year,
    ep.basic_salary,
    ep.allowances,
    ep.deductions,
    ep.net_salary,
    ep.status,
    ep.paid_at
FROM organization.employee_payroll ep
JOIN identity.employees emp ON emp.employee_id = ep.employee_id
ORDER BY ep.payroll_year DESC, ep.payroll_month DESC;

-- ------------------------------------------------------------
-- Report 20: Organization Health Dashboard (Daily, Critical)
-- Organization health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_organization_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT company_id) FROM organization.companies WHERE is_active = TRUE) AS active_companies,
    (SELECT COUNT(DISTINCT business_unit_id) FROM organization.business_units WHERE is_active = TRUE) AS active_business_units,
    (SELECT COUNT(DISTINCT department_id) FROM organization.departments WHERE is_active = TRUE) AS active_departments,
    (SELECT COUNT(DISTINCT branch_id) FROM organization.branches WHERE is_active = TRUE) AS active_branches,
    (SELECT COUNT(DISTINCT store_id) FROM organization.stores WHERE is_active = TRUE) AS active_stores,
    (SELECT COUNT(DISTINCT warehouse_id) FROM organization.warehouses WHERE is_active = TRUE) AS active_warehouses,
    (SELECT COUNT(DISTINCT sales_channel_id) FROM organization.sales_channels WHERE is_active = TRUE) AS active_channels,
    (SELECT COUNT(DISTINCT employee_id) FROM identity.employees WHERE is_active = TRUE) AS active_employees,
    (SELECT COUNT(DISTINCT employee_id) FROM organization.employee_assignments WHERE is_active = TRUE) AS active_assignments,
    (SELECT COUNT(DISTINCT employee_leave_id) FROM organization.employee_leaves WHERE status = 'PENDING') AS pending_leaves;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get Company Summary
CREATE OR REPLACE FUNCTION reports.fn_get_company_summary(
    p_company_id UUID
)
RETURNS TABLE (
    company_code VARCHAR,
    company_name VARCHAR,
    business_unit_count BIGINT,
    department_count BIGINT,
    branch_count BIGINT,
    store_count BIGINT,
    warehouse_count BIGINT,
    employee_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.company_code::VARCHAR,
        c.company_name::VARCHAR,
        COUNT(DISTINCT bu.business_unit_id),
        COUNT(DISTINCT dept.department_id),
        COUNT(DISTINCT br.branch_id),
        COUNT(DISTINCT st.store_id),
        COUNT(DISTINCT wh.warehouse_id),
        COUNT(DISTINCT emp.employee_id)
    FROM organization.companies c
    LEFT JOIN organization.business_units bu ON bu.company_id = c.company_id AND bu.is_active = TRUE
    LEFT JOIN organization.departments dept ON dept.company_id = c.company_id AND dept.is_active = TRUE
    LEFT JOIN organization.branches br ON br.company_id = c.company_id AND br.is_active = TRUE
    LEFT JOIN organization.stores st ON st.company_id = c.company_id AND st.is_active = TRUE
    LEFT JOIN organization.warehouses wh ON wh.company_id = c.company_id AND wh.is_active = TRUE
    LEFT JOIN identity.employees emp ON emp.company_id = c.company_id AND emp.is_active = TRUE
    WHERE c.company_id = p_company_id
    GROUP BY c.company_id, c.company_code, c.company_name;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get Employees by Department
CREATE OR REPLACE FUNCTION reports.fn_get_employees_by_department(
    p_department_id UUID
)
RETURNS TABLE (
    employee_id UUID,
    employee_code VARCHAR,
    employee_name VARCHAR,
    employment_type VARCHAR,
    employment_status VARCHAR,
    hire_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        emp.employee_id,
        emp.employee_code::VARCHAR,
        emp.employee_name::VARCHAR,
        et.name::VARCHAR,
        es.name::VARCHAR,
        emp.hire_date
    FROM organization.employee_assignments ea
    JOIN identity.employees emp ON emp.employee_id = ea.employee_id
    LEFT JOIN identity.employment_type_lookup et ON et.employment_type_id = emp.employment_type_id
    LEFT JOIN identity.employment_status_lookup es ON es.employment_status_id = emp.employment_status_id
    WHERE ea.department_id = p_department_id
      AND ea.is_active = TRUE
      AND emp.is_active = TRUE
    ORDER BY emp.employee_name;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get Store Summary
CREATE OR REPLACE FUNCTION reports.fn_get_store_summary(
    p_store_id UUID
)
RETURNS TABLE (
    store_code VARCHAR,
    store_name VARCHAR,
    store_type VARCHAR,
    city VARCHAR,
    branch_name VARCHAR,
    order_count BIGINT,
    total_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        st.store_code::VARCHAR,
        st.store_name::VARCHAR,
        stt.name::VARCHAR,
        st.city::VARCHAR,
        br.branch_name::VARCHAR,
        COUNT(DISTINCT o.order_id),
        COALESCE(SUM(o.grand_total), 0)
    FROM organization.stores st
    LEFT JOIN organization.store_type_lookup stt ON stt.store_type_id = st.store_type_id
    LEFT JOIN organization.branches br ON br.branch_id = st.branch_id
    LEFT JOIN sales.orders o ON o.store_id = st.store_id
    WHERE st.store_id = p_store_id
    GROUP BY st.store_id, st.store_code, st.store_name, stt.name, st.city, br.branch_name;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get Warehouse Inventory Summary
CREATE OR REPLACE FUNCTION reports.fn_get_warehouse_inventory(
    p_warehouse_id UUID
)
RETURNS TABLE (
    warehouse_code VARCHAR,
    warehouse_name VARCHAR,
    warehouse_type VARCHAR,
    unique_skus BIGINT,
    total_on_hand NUMERIC,
    total_reserved NUMERIC,
    available_quantity NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        wh.warehouse_code::VARCHAR,
        wh.warehouse_name::VARCHAR,
        wt.name::VARCHAR,
        COUNT(DISTINCT i.product_variant_id),
        COALESCE(SUM(i.quantity_on_hand), 0),
        COALESCE(SUM(i.quantity_reserved), 0),
        COALESCE(SUM(i.quantity_on_hand - i.quantity_reserved), 0)
    FROM organization.warehouses wh
    LEFT JOIN organization.warehouse_type_lookup wt ON wt.warehouse_type_id = wh.warehouse_type_id
    LEFT JOIN inventory.inventories i ON i.warehouse_id = wh.warehouse_id
    WHERE wh.warehouse_id = p_warehouse_id
    GROUP BY wh.warehouse_id, wh.warehouse_code, wh.warehouse_name, wt.name;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get Employee Summary
CREATE OR REPLACE FUNCTION reports.fn_get_employee_summary(
    p_employee_id UUID
)
RETURNS TABLE (
    employee_code VARCHAR,
    employee_name VARCHAR,
    employment_type VARCHAR,
    employment_status VARCHAR,
    hire_date DATE,
    department_name VARCHAR,
    business_unit_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        emp.employee_code::VARCHAR,
        emp.employee_name::VARCHAR,
        et.name::VARCHAR,
        es.name::VARCHAR,
        emp.hire_date,
        dept.department_name::VARCHAR,
        bu.business_unit_name::VARCHAR
    FROM identity.employees emp
    LEFT JOIN identity.employment_type_lookup et ON et.employment_type_id = emp.employment_type_id
    LEFT JOIN identity.employment_status_lookup es ON es.employment_status_id = emp.employment_status_id
    LEFT JOIN organization.employee_assignments ea ON ea.employee_id = emp.employee_id AND ea.is_active = TRUE AND ea.is_primary = TRUE
    LEFT JOIN organization.departments dept ON dept.department_id = ea.department_id
    LEFT JOIN organization.business_units bu ON bu.business_unit_id = ea.business_unit_id
    WHERE emp.employee_id = p_employee_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 02 Organization
-- 20 Views + 5 Functions = 25 Report Objects
-- 20 Reports as per reports01.html catalog
-- ============================================================