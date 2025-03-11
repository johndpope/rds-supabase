-- Stripped pg_dump comments
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- Create schemas if not exists
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = '_realtime') THEN
        CREATE SCHEMA _realtime;
        ALTER SCHEMA _realtime OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth') THEN
        CREATE SCHEMA auth;
        ALTER SCHEMA auth OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'extensions') THEN
        CREATE SCHEMA extensions;
        ALTER SCHEMA extensions OWNER TO postgres;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'graphql') THEN
        CREATE SCHEMA graphql;
        ALTER SCHEMA graphql OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'graphql_public') THEN
        CREATE SCHEMA graphql_public;
        ALTER SCHEMA graphql_public OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'pgbouncer') THEN
        CREATE SCHEMA pgbouncer;
        ALTER SCHEMA pgbouncer OWNER TO pgbouncer;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'realtime') THEN
        CREATE SCHEMA realtime;
        ALTER SCHEMA realtime OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'storage') THEN
        CREATE SCHEMA storage;
        ALTER SCHEMA storage OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'supabase_functions') THEN
        CREATE SCHEMA supabase_functions;
        ALTER SCHEMA supabase_functions OWNER TO supabase_admin;
    END IF;
END $$;

-- Extensions supported by RDS
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;
COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';

-- Skip unavailable extensions (pg_net, pgsodium, pg_graphql, pgjwt, supabase_vault) for now


-- Create tables for _realtime schema
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = '_realtime' AND tablename = 'tenants') THEN
        CREATE TABLE _realtime.tenants (
            id uuid PRIMARY KEY,
            name text NOT NULL,
            external_id text NOT NULL UNIQUE,
            jwt_secret text NOT NULL,
            max_concurrent_users integer NOT NULL,
            inserted_at timestamp without time zone NOT NULL,
            updated_at timestamp without time zone NOT NULL,
            max_events_per_second integer NOT NULL,
            postgres_cdc_default text NOT NULL,
            max_bytes_per_second integer NOT NULL,
            max_channels_per_client integer NOT NULL,
            max_joins_per_second integer NOT NULL,
            suspend boolean NOT NULL,
            jwt_jwks jsonb,
            notify_private_alpha boolean NOT NULL DEFAULT false,
            private_only boolean NOT NULL DEFAULT false
        );
        ALTER TABLE _realtime.tenants OWNER TO mlypg_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = '_realtime' AND tablename = 'extensions') THEN
        CREATE TABLE _realtime.extensions (
            id uuid PRIMARY KEY,
            type text NOT NULL,
            settings jsonb NOT NULL,
            tenant_external_id text NOT NULL REFERENCES _realtime.tenants(external_id),
            inserted_at timestamp without time zone NOT NULL,
            updated_at timestamp without time zone NOT NULL
        );
        ALTER TABLE _realtime.extensions OWNER TO mlypg_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = '_realtime' AND tablename = 'schema_migrations') THEN
        CREATE TABLE _realtime.schema_migrations (
            version bigint PRIMARY KEY,
            inserted_at timestamp without time zone NOT NULL
        );
        ALTER TABLE _realtime.schema_migrations OWNER TO mlypg_admin;
    END IF;
END $$;

-- Create tables for auth schema
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'auth' AND tablename = 'schema_migrations') THEN
        CREATE TABLE auth.schema_migrations (
            version text PRIMARY KEY
        );
        ALTER TABLE auth.schema_migrations OWNER TO mlypg_admin;
    END IF;
END $$;

-- Create tables for realtime schema
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'schema_migrations') THEN
        CREATE TABLE realtime.schema_migrations (
            version bigint PRIMARY KEY,
            inserted_at timestamp without time zone NOT NULL
        );
        ALTER TABLE realtime.schema_migrations OWNER TO mlypg_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'subscription') THEN
        CREATE TABLE realtime.subscription (
            id bigint NOT NULL,
            subscription_id uuid NOT NULL,
            entity regclass NOT NULL,
            filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[],
            claims jsonb NOT NULL,
            created_at timestamp without time zone NOT NULL
        );
        ALTER TABLE realtime.subscription OWNER TO mlypg_admin;
        CREATE SEQUENCE realtime.subscription_id_seq
            START WITH 1
            INCREMENT BY 1
            NO MINVALUE
            NO MAXVALUE
            CACHE 1;
        ALTER SEQUENCE realtime.subscription_id_seq OWNER TO mlypg_admin;
        ALTER TABLE realtime.subscription ALTER COLUMN id SET DEFAULT nextval('realtime.subscription_id_seq'::regclass);
        ALTER TABLE realtime.subscription ADD CONSTRAINT subscription_pkey PRIMARY KEY (id);
    END IF;
END $$;

-- Types
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'aal_level' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.aal_level AS ENUM ('aal1', 'aal2', 'aal3');
        ALTER TYPE auth.aal_level OWNER TO supabase_auth_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'code_challenge_method' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');
        ALTER TYPE auth.code_challenge_method OWNER TO supabase_auth_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
        ALTER TYPE auth.factor_status OWNER TO supabase_auth_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
        ALTER TYPE auth.factor_type OWNER TO supabase_auth_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'one_time_token_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.one_time_token_type AS ENUM (
            'confirmation_token', 'reauthentication_token', 'recovery_token',
            'email_change_token_new', 'email_change_token_current', 'phone_change_token'
        );
        ALTER TYPE auth.one_time_token_type OWNER TO supabase_auth_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'action' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'realtime')) THEN
        CREATE TYPE realtime.action AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'ERROR');
        ALTER TYPE realtime.action OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'equality_op' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'realtime')) THEN
        CREATE TYPE realtime.equality_op AS ENUM ('eq', 'neq', 'lt', 'lte', 'gt', 'gte', 'in');
        ALTER TYPE realtime.equality_op OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_defined_filter' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'realtime')) THEN
        CREATE TYPE realtime.user_defined_filter AS (column_name text, op realtime.equality_op, value text);
        ALTER TYPE realtime.user_defined_filter OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wal_column' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'realtime')) THEN
        CREATE TYPE realtime.wal_column AS (name text, type_name text, type_oid oid, value jsonb, is_pkey boolean, is_selectable boolean);
        ALTER TYPE realtime.wal_column OWNER TO supabase_admin;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wal_rls' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'realtime')) THEN
        CREATE TYPE realtime.wal_rls AS (wal jsonb, is_rls_enabled boolean, subscription_ids uuid[], errors text[]);
        ALTER TYPE realtime.wal_rls OWNER TO supabase_admin;
    END IF;
END $$;

-- Functions (only those not dependent on missing extensions)
CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT 
        COALESCE(
            NULLIF(current_setting('request.jwt.claim.email', true), ''),
            (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
        )::text
    $$;
ALTER FUNCTION auth.email() OWNER TO supabase_auth_admin;
COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
    SELECT 
        COALESCE(
            NULLIF(current_setting('request.jwt.claim', true), ''),
            NULLIF(current_setting('request.jwt.claims', true), '')
        )::jsonb
    $$;
ALTER FUNCTION auth.jwt() OWNER TO supabase_auth_admin;

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT 
        COALESCE(
            NULLIF(current_setting('request.jwt.claim.role', true), ''),
            (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
        )::text
    $$;
ALTER FUNCTION auth.role() OWNER TO supabase_auth_admin;
COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    SELECT 
        COALESCE(
            NULLIF(current_setting('request.jwt.claim.sub', true), ''),
            (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
        )::uuid
    $$;
ALTER FUNCTION auth.uid() OWNER TO supabase_auth_admin;
COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
    BEGIN
        RAISE WARNING 'PgBouncer auth request: %', p_usename;
        RETURN QUERY
        SELECT usename::TEXT, passwd::TEXT FROM pg_catalog.pg_shadow
        WHERE usename = p_usename;
    END;
    $$;
ALTER FUNCTION pgbouncer.get_auth(p_usename text) OWNER TO postgres;

-- Add other functions as needed, skipping those dependent on unavailable extensions

-- Tables and other objects can be added similarly with IF NOT EXISTS checks
-- Example for auth.users
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'auth' AND tablename = 'users') THEN
        CREATE TABLE auth.users (
            id uuid PRIMARY KEY,
            -- Add other columns as per original schema
            email text
        );
        ALTER TABLE auth.users OWNER TO supabase_auth_admin;
    END IF;
END $$;

-- Publication (skip if exists)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- Permissions (adjust for RDS limitations)
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
GRANT ALL ON FUNCTION auth.email() TO postgres, anon, authenticated, service_role;
GRANT ALL ON FUNCTION auth.jwt() TO postgres, anon, authenticated, service_role;
GRANT ALL ON FUNCTION auth.role() TO postgres, anon, authenticated, service_role;
GRANT ALL ON FUNCTION auth.uid() TO postgres, anon, authenticated, service_role;
GRANT ALL ON FUNCTION pgbouncer.get_auth(text) TO pgbouncer;

-- Skip ALTER DEFAULT PRIVILEGES and event triggers for now (RDS restrictions)


-- Grant USAGE on the _realtime schema (if not already granted)
GRANT USAGE ON SCHEMA _realtime TO supabase_admin;

-- Grant SELECT on _realtime.tenants (minimum required for Realtime to read tenant data)
GRANT SELECT ON _realtime.tenants TO supabase_admin;

-- Optionally, grant broader privileges if Realtime needs to modify the table
GRANT SELECT, INSERT, UPDATE, DELETE ON _realtime.tenants TO supabase_admin;

-- Grant SELECT on other _realtime tables if needed
GRANT SELECT ON _realtime.extensions, _realtime.schema_migrations TO supabase_admin;



-- Grant USAGE on the _realtime schema (if not already granted)
GRANT USAGE ON SCHEMA _realtime TO supabase_admin;

-- Grant SELECT on _realtime.tenants (minimum required for Realtime to read tenant data)
GRANT SELECT ON _realtime.tenants TO supabase_admin;

-- Optionally, grant broader privileges if Realtime needs to modify the table
GRANT SELECT, INSERT, UPDATE, DELETE ON _realtime.tenants TO supabase_admin;

-- Grant SELECT on other _realtime tables if needed
GRANT SELECT ON _realtime.extensions, _realtime.schema_migrations TO supabase_admin;



DO $$ 
BEGIN
    -- Create login roles if they don't exist
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Created authenticator with LOGIN and password.';
    ELSE
        ALTER ROLE authenticator WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Updated authenticator with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
        CREATE ROLE supabase_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' CREATEDB CREATEROLE;
        RAISE NOTICE 'Created supabase_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' CREATEDB CREATEROLE;
        RAISE NOTICE 'Updated supabase_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        CREATE ROLE supabase_auth_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Created supabase_auth_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_auth_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Updated supabase_auth_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_functions_admin') THEN
        CREATE ROLE supabase_functions_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Created supabase_functions_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_functions_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Updated supabase_functions_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
        CREATE ROLE supabase_storage_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Created supabase_storage_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_storage_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Updated supabase_storage_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgbouncer') THEN
        CREATE ROLE pgbouncer WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Created pgbouncer with LOGIN and password.';
    ELSE
        ALTER ROLE pgbouncer WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOINHERIT;
        RAISE NOTICE 'Updated pgbouncer with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_realtime_admin') THEN
        CREATE ROLE supabase_realtime_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOREPLICATION;
        RAISE NOTICE 'Created supabase_realtime_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_realtime_admin WITH LOGIN PASSWORD'your-super-secret-and-long-postgres-password' NOREPLICATION;
        RAISE NOTICE 'Updated supabase_realtime_admin with LOGIN and password.';
    END IF;
    
    -- Create non-login roles
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
        RAISE NOTICE 'Created anon role (NOLOGIN).';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
        RAISE NOTICE 'Created authenticated role (NOLOGIN).';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT bypassrls;
        RAISE NOTICE 'Created service_role (NOLOGIN).';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create/alter roles; ensure the executing user has sufficient privileges.';
        RAISE EXCEPTION 'Role creation/alteration failed due to insufficient privileges.';
    WHEN others THEN
        RAISE NOTICE 'Error creating/altering roles: %', SQLERRM;
        RAISE EXCEPTION 'Role creation/alteration failed: %', SQLERRM;
END $$;



SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE schemaname = '_realtime' AND tablename = 'schema_migrations';

-- Check current privileges
    
GRANT ALL ON SCHEMA _realtime TO supabase_admin;
GRANT ALL ON ALL TABLES IN SCHEMA _realtime TO supabase_admin;


ALTER ROLE supabase_admin WITH REPLICATION;


 -- Grant USAGE on the _realtime schema (if not already done)
-- GRANT USAGE ON SCHEMA _realtime TO supabase_admin;

-- Grant required privileges on schema_migrations
GRANT SELECT, INSERT, UPDATE ON _realtime.schema_migrations TO supabase_admin;

-- Optionally, grant DELETE if migrations might need to roll back or clean up
GRANT DELETE ON _realtime.schema_migrations TO supabase_admin;

-- Confirm privileges
\dp _realtime.schema_migrations

\dp _realtime.schema_migrations

