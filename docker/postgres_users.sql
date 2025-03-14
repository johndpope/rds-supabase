--
-- PostgreSQL database cluster dump (RDS-compatible)
--


DO $$ 
BEGIN
    EXECUTE 'GRANT rds_replication TO ' || quote_ident(CURRENT_USER);
END $$;


SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles (Create only if not exists, avoid SUPERUSER where possible)
--

-- Core Supabase roles adjusted for RDS compatibility

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOBYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOBYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator WITH NOSUPERUSER NOINHERIT NOCREATEROLE NOCREATEDB LOGIN NOBYPASSRLS PASSWORD 'your-super-secret-and-long-postgres-password';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dashboard_user') THEN
        CREATE ROLE dashboard_user WITH NOSUPERUSER INHERIT CREATEROLE CREATEDB NOLOGIN NOBYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgbouncer') THEN
        CREATE ROLE pgbouncer WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOBYPASSRLS PASSWORD 'your-super-secret-and-long-postgres-password';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgsodium_keyholder') THEN
        CREATE ROLE pgsodium_keyholder WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOBYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgsodium_keyiduser') THEN
        CREATE ROLE pgsodium_keyiduser WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOBYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgsodium_keymaker') THEN
        CREATE ROLE pgsodium_keymaker WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOBYPASSRLS;
    END IF;
END $$;

-- Skip 'postgres' creation as it exists in RDS
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN BYPASSRLS;
    END IF;
END $$;

-- supabase_admin: Create without REPLICATION, add it later
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
        CREATE ROLE supabase_admin WITH NOSUPERUSER INHERIT CREATEROLE CREATEDB LOGIN BYPASSRLS PASSWORD 'your-super-secret-and-long-postgres-password';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        CREATE ROLE supabase_auth_admin WITH NOSUPERUSER NOINHERIT CREATEROLE NOCREATEDB LOGIN NOBYPASSRLS PASSWORD 'your-super-secret-and-long-postgres-password';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_functions_admin') THEN
        CREATE ROLE supabase_functions_admin WITH NOSUPERUSER NOINHERIT CREATEROLE NOCREATEDB LOGIN NOBYPASSRLS PASSWORD 'your-super-secret-and-long-postgres-password';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_read_only_user') THEN
        CREATE ROLE supabase_read_only_user WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN BYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_realtime_admin') THEN
        CREATE ROLE supabase_realtime_admin WITH NOSUPERUSER NOINHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOBYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_replication_admin') THEN
        CREATE ROLE supabase_replication_admin WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOBYPASSRLS;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
        CREATE ROLE supabase_storage_admin WITH NOSUPERUSER NOINHERIT CREATEROLE NOCREATEDB LOGIN NOBYPASSRLS PASSWORD 'your-super-secret-and-long-postgres-password';
    END IF;
END $$;

-- Grant rds_replication to roles that need replication privileges
-- Note: mlypg_admin must already have rds_replication granted
GRANT rds_replication TO dashboard_user;
GRANT rds_replication TO supabase_admin;
GRANT rds_replication TO supabase_replication_admin;

-- Optional: Verify roles
SELECT rolname, rolsuper, rolcreaterole, rolreplication 
FROM pg_roles 
WHERE rolname LIKE 'supabase%' OR rolname IN ('anon', 'authenticated', 'authenticator', 'dashboard_user', 'pgbouncer', 'service_role');

-- Optional: Check memberships
SELECT m.rolname AS member, r.rolname AS role 
FROM pg_auth_members am 
JOIN pg_roles m ON am.member = m.oid 
JOIN pg_roles r ON am.roleid = r.oid 
WHERE m.rolname IN ('dashboard_user', 'supabase_admin', 'supabase_replication_admin');


--
-- User Configurations (Skip ones requiring superuser)
--

ALTER ROLE anon SET statement_timeout TO '3s';
ALTER ROLE authenticated SET statement_timeout TO '8s';
ALTER ROLE authenticator SET statement_timeout TO '8s';
ALTER ROLE authenticator SET lock_timeout TO '8s';
ALTER ROLE supabase_auth_admin SET search_path TO 'auth';
ALTER ROLE supabase_auth_admin SET idle_in_transaction_session_timeout TO '60000';
ALTER ROLE supabase_functions_admin SET search_path TO 'supabase_functions';
ALTER ROLE supabase_storage_admin SET search_path TO 'storage';

--
-- Role Memberships (Execute as mlypg_admin, skip GRANTED BY)
--

GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;
GRANT pg_read_all_data TO supabase_read_only_user;


-- Check current roles
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication, rolbypassrls 
FROM pg_roles 
WHERE rolname LIKE 'supabase%' OR rolname IN ('anon', 'authenticated', 'authenticator', 'service_role', 'pgbouncer', 'postgres');

-- Grant missing memberships (if needed)
GRANT anon TO postgres;
GRANT authenticated TO postgres;
GRANT service_role TO postgres;
GRANT supabase_auth_admin TO postgres;
GRANT supabase_functions_admin TO postgres;
GRANT supabase_realtime_admin TO postgres;
GRANT supabase_storage_admin TO postgres;
GRANT pgsodium_keyholder TO postgres WITH ADMIN OPTION;
GRANT pgsodium_keyiduser TO postgres WITH ADMIN OPTION;
GRANT pgsodium_keymaker TO postgres WITH ADMIN OPTION;
GRANT pg_monitor TO postgres;
GRANT pg_signal_backend TO postgres;
GRANT pg_read_all_data TO postgres;



GRANT rds_replication TO supabase_realtime_admin;
GRANT rds_replication TO supabase_admin;
GRANT rds_replication TO supabase_storage_admin;
GRANT rds_replication TO supabase_functions_admin;
GRANT rds_replication TO supabase_auth_admin;
GRANT rds_replication TO pgbouncer;
-- GRANT rds_replication TO dashboard_user;
GRANT rds_replication TO supabase_read_only_user;


-- Check memberships
SELECT m.rolname AS member, r.rolname AS role 
FROM pg_auth_members am 
JOIN pg_roles m ON am.member = m.oid 
JOIN pg_roles r ON am.roleid = r.oid;
