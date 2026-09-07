BEGIN;

CREATE SCHEMA IF NOT EXISTS reports;

-- ============================================================
-- MODULE 01: IDENTITY & ACCESS MANAGEMENT REPORTING
-- 15 Views + 5 Functions
-- ============================================================

-- ------------------------------------------------------------
-- Report 1: User Overview (Daily, Critical)
-- Active users by role/company
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_user_overview AS
SELECT
    u.user_id,
    u.username,
    u.email,
    usl.code AS user_status,
    usl.name AS status_name,
    p.first_name,
    p.last_name,
    u.last_login_at,
    u.last_login_ip,
    u.is_active,
    u.created_at,
    COUNT(DISTINCT ur.role_id) AS role_count
FROM identity.users u
JOIN identity.user_status_lookup usl ON usl.user_status_id = u.user_status_id
LEFT JOIN identity.persons p ON p.person_id = u.person_id
LEFT JOIN identity.user_roles ur ON ur.user_id = u.user_id AND ur.is_active = TRUE
GROUP BY u.user_id, u.username, u.email, usl.code, usl.name, p.first_name, p.last_name,
         u.last_login_at, u.last_login_ip, u.is_active, u.created_at
ORDER BY u.created_at DESC;

-- ------------------------------------------------------------
-- Report 2: Role Assignment (Monthly, Critical)
-- Users by role
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_role_assignment AS
SELECT
    r.role_code,
    r.role_name,
    r.is_system,
    COUNT(DISTINCT ur.user_id) AS user_count,
    COUNT(DISTINCT CASE WHEN ur.is_active = TRUE THEN ur.user_id END) AS active_users,
    r.created_at
FROM identity.roles r
LEFT JOIN identity.user_roles ur ON ur.role_id = r.role_id
GROUP BY r.role_id, r.role_code, r.role_name, r.is_system, r.created_at
ORDER BY user_count DESC;

-- ------------------------------------------------------------
-- Report 3: Login Activity (Daily, Critical)
-- Recent login history
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_login_activity AS
SELECT
    ulh.login_history_id,
    u.username,
    u.email,
    ulh.login_at,
    ulh.ip_address,
    ulh.user_agent,
    ulh.device_type,
    ulh.is_successful,
    ulh.failure_reason
FROM identity.user_login_history ulh
JOIN identity.users u ON u.user_id = ulh.user_id
WHERE ulh.login_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY ulh.login_at DESC;

-- ------------------------------------------------------------
-- Report 4: Failed Login Attempts (Daily, Critical)
-- Security monitoring
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_failed_login_attempts AS
SELECT
    u.username,
    u.email,
    COUNT(DISTINCT ulh.login_history_id) AS failed_attempts,
    MAX(ulh.login_at) AS last_failed_at,
    MIN(ulh.login_at) AS first_failed_at,
    COUNT(DISTINCT ulh.ip_address) AS unique_ips
FROM identity.user_login_history ulh
JOIN identity.users u ON u.user_id = ulh.user_id
WHERE ulh.is_successful = FALSE
  AND ulh.login_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY u.username, u.email
ORDER BY failed_attempts DESC;

-- ------------------------------------------------------------
-- Report 5: MFA Adoption (Monthly, Important)
-- MFA adoption rate
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_mfa_adoption AS
SELECT
    umfa.mfa_type,
    COUNT(DISTINCT umfa.user_id) AS users_with_mfa,
    COUNT(DISTINCT CASE WHEN umfa.is_verified = TRUE THEN umfa.user_id END) AS verified_users,
    COUNT(DISTINCT CASE WHEN umfa.is_active = TRUE THEN umfa.user_id END) AS active_mfa_users,
    ROUND((COUNT(DISTINCT umfa.user_id)::NUMERIC / 
           NULLIF((SELECT COUNT(DISTINCT user_id) FROM identity.users WHERE is_active = TRUE), 0) * 100), 2) AS adoption_rate_percent
FROM identity.user_mfa_methods umfa
GROUP BY umfa.mfa_type
ORDER BY users_with_mfa DESC;

-- ------------------------------------------------------------
-- Report 6: Session Activity (Real-time, Critical)
-- Active sessions
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_session_activity AS
SELECT
    us.session_id,
    u.username,
    u.email,
    us.ip_address,
    us.user_agent,
    us.device_type,
    us.created_at,
    us.last_activity_at,
    us.expires_at,
    CASE
        WHEN us.expires_at < CURRENT_TIMESTAMP THEN 'EXPIRED'
        WHEN us.last_activity_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes' THEN 'IDLE'
        ELSE 'ACTIVE'
    END AS session_status
FROM identity.user_sessions us
JOIN identity.users u ON u.user_id = us.user_id
WHERE us.is_active = TRUE
ORDER BY us.last_activity_at DESC;

-- ------------------------------------------------------------
-- Report 7: Security Events (Real-time, Critical)
-- Security event monitoring
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_security_events AS
SELECT
    use.security_event_id,
    u.username,
    u.email,
    use.event_type,
    use.event_details,
    use.ip_address,
    use.user_agent,
    use.created_at
FROM identity.user_security_events use
JOIN identity.users u ON u.user_id = use.user_id
WHERE use.created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY use.created_at DESC;

-- ------------------------------------------------------------
-- Report 8: Password History (On-demand, Important)
-- Password change history
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_password_history AS
SELECT
    uph.password_history_id,
    u.username,
    u.email,
    uph.changed_at,
    u.username AS changed_by
FROM identity.user_password_history uph
JOIN identity.users u ON u.user_id = uph.user_id
ORDER BY uph.changed_at DESC;

-- ------------------------------------------------------------
-- Report 9: User Device Report (Monthly, Important)
-- Registered devices
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_user_devices AS
SELECT
    ud.device_id,
    u.username,
    u.email,
    ud.device_name,
    ud.device_type,
    ud.is_active,
    ud.last_seen_at,
    ud.created_at
FROM identity.user_devices ud
JOIN identity.users u ON u.user_id = ud.user_id
ORDER BY ud.last_seen_at DESC NULLS LAST;

-- ------------------------------------------------------------
-- Report 10: Token Usage (Daily, Important)
-- API token usage
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_token_usage AS
SELECT
    ut.token_type,
    COUNT(DISTINCT ut.token_id) AS token_count,
    COUNT(DISTINCT CASE WHEN ut.is_active = TRUE THEN ut.token_id END) AS active_tokens,
    COUNT(DISTINCT CASE WHEN ut.expires_at < CURRENT_TIMESTAMP THEN ut.token_id END) AS expired_tokens,
    COUNT(DISTINCT ut.user_id) AS users_with_tokens
FROM identity.user_tokens ut
GROUP BY ut.token_type
ORDER BY token_count DESC;

-- ------------------------------------------------------------
-- Report 11: User Notifications (Daily, Important)
-- Notification delivery
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_user_notifications AS
SELECT
    un.notification_type,
    COUNT(DISTINCT un.notification_id) AS notification_count,
    COUNT(DISTINCT CASE WHEN un.is_read = TRUE THEN un.notification_id END) AS read_count,
    COUNT(DISTINCT CASE WHEN un.is_read = FALSE THEN un.notification_id END) AS unread_count,
    ROUND((COUNT(DISTINCT CASE WHEN un.is_read = TRUE THEN un.notification_id END)::NUMERIC / 
           NULLIF(COUNT(DISTINCT un.notification_id), 0) * 100), 2) AS read_rate_percent
FROM identity.user_notifications un
GROUP BY un.notification_type
ORDER BY notification_count DESC;

-- ------------------------------------------------------------
-- Report 12: User Preferences (Monthly, Standard)
-- Preference distribution
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_user_preferences AS
SELECT
    up.preference_key,
    COUNT(DISTINCT up.user_id) AS users_with_preference,
    COUNT(DISTINCT CASE WHEN up.preference_value = 'true' THEN up.user_id END) AS enabled_count,
    COUNT(DISTINCT CASE WHEN up.preference_value = 'false' THEN up.user_id END) AS disabled_count
FROM identity.user_preferences up
GROUP BY up.preference_key
ORDER BY users_with_preference DESC;

-- ------------------------------------------------------------
-- Report 13: User Audit Log (On-demand, Critical)
-- Audit trail
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_user_audit_log AS
SELECT
    ual.audit_log_id,
    u.username,
    ual.action,
    ual.entity_type,
    ual.entity_id,
    ual.ip_address,
    ual.created_at
FROM identity.user_audit_log ual
LEFT JOIN identity.users u ON u.user_id = ual.user_id
WHERE ual.created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY ual.created_at DESC;

-- ------------------------------------------------------------
-- Report 14: Identity 360 (On-demand, Critical)
-- Consolidated identity view
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_identity_360 AS
SELECT
    u.user_id,
    u.username,
    u.email,
    p.first_name,
    p.last_name,
    usl.code AS user_status,
    u.last_login_at,
    u.is_active,
    COUNT(DISTINCT ur.role_id) AS role_count,
    COUNT(DISTINCT CASE WHEN umfa.is_active = TRUE THEN umfa.user_mfa_method_id END) AS active_mfa_count,
    COUNT(DISTINCT ud.device_id) AS device_count,
    COUNT(DISTINCT CASE WHEN un.is_read = FALSE THEN un.notification_id END) AS unread_notifications,
    COUNT(DISTINCT CASE WHEN use.event_type IN ('LOGIN', 'PASSWORD_CHANGED') THEN use.security_event_id END) AS security_events_count
FROM identity.users u
JOIN identity.user_status_lookup usl ON usl.user_status_id = u.user_status_id
LEFT JOIN identity.persons p ON p.person_id = u.person_id
LEFT JOIN identity.user_roles ur ON ur.user_id = u.user_id AND ur.is_active = TRUE
LEFT JOIN identity.user_mfa_methods umfa ON umfa.user_id = u.user_id
LEFT JOIN identity.user_devices ud ON ud.user_id = u.user_id AND ud.is_active = TRUE
LEFT JOIN identity.user_notifications un ON un.user_id = u.user_id
LEFT JOIN identity.user_security_events use ON use.user_id = u.user_id
GROUP BY u.user_id, u.username, u.email, p.first_name, p.last_name, usl.code, u.last_login_at, u.is_active
ORDER BY u.username;

-- ------------------------------------------------------------
-- Report 15: Identity Health Dashboard (Daily, Critical)
-- Identity health metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW reports.vw_identity_health_dashboard AS
SELECT
    (SELECT COUNT(DISTINCT user_id) FROM identity.users WHERE is_active = TRUE) AS active_users,
    (SELECT COUNT(DISTINCT user_id) FROM identity.users WHERE is_active = FALSE) AS inactive_users,
    (SELECT COUNT(DISTINCT user_id) FROM identity.user_sessions WHERE is_active = TRUE AND expires_at > CURRENT_TIMESTAMP) AS active_sessions,
    (SELECT COUNT(DISTINCT user_id) FROM identity.user_mfa_methods WHERE is_active = TRUE) AS users_with_mfa,
    (SELECT COUNT(DISTINCT login_history_id) FROM identity.user_login_history WHERE is_successful = FALSE AND login_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS failed_logins_7d,
    (SELECT COUNT(DISTINCT security_event_id) FROM identity.user_security_events WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS security_events_7d,
    (SELECT COUNT(DISTINCT device_id) FROM identity.user_devices WHERE is_active = TRUE) AS active_devices,
    (SELECT COUNT(DISTINCT token_id) FROM identity.user_tokens WHERE is_active = TRUE AND expires_at > CURRENT_TIMESTAMP) AS active_tokens,
    (SELECT COUNT(DISTINCT notification_id) FROM identity.user_notifications WHERE is_read = FALSE) AS unread_notifications,
    (SELECT COUNT(DISTINCT audit_log_id) FROM identity.user_audit_log WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') AS audit_events_7d;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function 1: Get User by Username
CREATE OR REPLACE FUNCTION reports.fn_get_user_by_username(
    p_username VARCHAR
)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    email VARCHAR,
    user_status VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    last_login_at TIMESTAMPTZ,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.user_id,
        u.username::VARCHAR,
        u.email::VARCHAR,
        usl.code::VARCHAR,
        p.first_name::VARCHAR,
        p.last_name::VARCHAR,
        u.last_login_at,
        u.is_active
    FROM identity.users u
    JOIN identity.user_status_lookup usl ON usl.user_status_id = u.user_status_id
    LEFT JOIN identity.persons p ON p.person_id = u.person_id
    WHERE LOWER(u.username) = LOWER(p_username);
END;
$$ LANGUAGE plpgsql;

-- Function 2: Get User Roles
CREATE OR REPLACE FUNCTION reports.fn_get_user_roles(
    p_user_id UUID
)
RETURNS TABLE (
    role_code VARCHAR,
    role_name VARCHAR,
    is_system BOOLEAN,
    assigned_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.role_code::VARCHAR,
        r.role_name::VARCHAR,
        r.is_system,
        ur.assigned_at
    FROM identity.user_roles ur
    JOIN identity.roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = p_user_id
      AND ur.is_active = TRUE
    ORDER BY r.role_name;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Get User Login History
CREATE OR REPLACE FUNCTION reports.fn_get_user_login_history(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    login_at TIMESTAMPTZ,
    ip_address INET,
    user_agent TEXT,
    device_type VARCHAR,
    is_successful BOOLEAN,
    failure_reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ulh.login_at,
        ulh.ip_address,
        ulh.user_agent,
        ulh.device_type::VARCHAR,
        ulh.is_successful,
        ulh.failure_reason
    FROM identity.user_login_history ulh
    WHERE ulh.user_id = p_user_id
    ORDER BY ulh.login_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Get User Security Events
CREATE OR REPLACE FUNCTION reports.fn_get_user_security_events(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    event_type VARCHAR,
    event_details TEXT,
    ip_address INET,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        use.event_type::VARCHAR,
        use.event_details,
        use.ip_address,
        use.created_at
    FROM identity.user_security_events use
    WHERE use.user_id = p_user_id
    ORDER BY use.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Get User Notifications
CREATE OR REPLACE FUNCTION reports.fn_get_user_notifications(
    p_user_id UUID,
    p_unread_only BOOLEAN DEFAULT FALSE,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    notification_id UUID,
    notification_type VARCHAR,
    title VARCHAR,
    message TEXT,
    is_read BOOLEAN,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        un.notification_id,
        un.notification_type::VARCHAR,
        un.title::VARCHAR,
        un.message,
        un.is_read,
        un.read_at,
        un.created_at
    FROM identity.user_notifications un
    WHERE un.user_id = p_user_id
      AND (NOT p_unread_only OR un.is_read = FALSE)
    ORDER BY un.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- SUMMARY: Module 01 Identity
-- 15 Views + 5 Functions = 20 Report Objects
-- 15 Reports as per reports01.html catalog
-- ============================================================