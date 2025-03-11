-- Ensure we are in the postgres database initially
\connect postgres

-- Define variables (passed via psql -v)
\set postgres_password :'postgres_password'
\set jwt_secret :'jwt_secret'
\set jwt_exp :'jwt_exp'
\set realtime_db :'realtime_db'

-- Log the postgres_password variable for debugging
DO $$
BEGIN
    RAISE NOTICE 'postgres_password value: %', :'postgres_password';
END $$;

-- Create essential schemas first
CREATE SCHEMA IF NOT EXISTS public;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS graphql_public;
CREATE SCHEMA IF NOT EXISTS _realtime;
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE SCHEMA IF NOT EXISTS supabase_functions;
CREATE SCHEMA IF NOT EXISTS realtime;

-- Create roles with proper attributes, ensuring LOGIN for all login-capable roles
DO $$ 
BEGIN
    -- Create login roles if they don't exist
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Created authenticator with LOGIN and password.';
    ELSE
        ALTER ROLE authenticator WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Updated authenticator with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
        CREATE ROLE supabase_admin WITH LOGIN PASSWORD :'postgres_password' CREATEDB CREATEROLE;
        RAISE NOTICE 'Created supabase_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_admin WITH LOGIN PASSWORD :'postgres_password' CREATEDB CREATEROLE;
        RAISE NOTICE 'Updated supabase_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        CREATE ROLE supabase_auth_admin WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Created supabase_auth_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_auth_admin WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Updated supabase_auth_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_functions_admin') THEN
        CREATE ROLE supabase_functions_admin WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Created supabase_functions_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_functions_admin WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Updated supabase_functions_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
        CREATE ROLE supabase_storage_admin WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Created supabase_storage_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_storage_admin WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Updated supabase_storage_admin with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgbouncer') THEN
        CREATE ROLE pgbouncer WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Created pgbouncer with LOGIN and password.';
    ELSE
        ALTER ROLE pgbouncer WITH LOGIN PASSWORD :'postgres_password' NOINHERIT;
        RAISE NOTICE 'Updated pgbouncer with LOGIN and password.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_realtime_admin') THEN
        CREATE ROLE supabase_realtime_admin WITH LOGIN PASSWORD :'postgres_password' NOREPLICATION;
        RAISE NOTICE 'Created supabase_realtime_admin with LOGIN and password.';
    ELSE
        ALTER ROLE supabase_realtime_admin WITH LOGIN PASSWORD :'postgres_password' NOREPLICATION;
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

-- Set up role inheritance
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;

-- Grant database access
GRANT CONNECT ON DATABASE postgres TO authenticator, supabase_admin,
  supabase_auth_admin, supabase_functions_admin, supabase_storage_admin, supabase_realtime_admin;

-- Grant CREATE privileges on realtime schema to supabase_realtime_admin
GRANT CREATE ON SCHEMA realtime TO supabase_realtime_admin;

-- Set JWT parameters
DO $$ 
BEGIN
    BEGIN
        ALTER DATABASE postgres SET "app.settings.jwt_secret" TO :'jwt_secret';
        ALTER DATABASE postgres SET "app.settings.jwt_exp" TO :'jwt_exp';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not set JWT parameters: %', SQLERRM;
    END;
END $$;

-- Set schema ownership
DO $$
BEGIN
    BEGIN
        ALTER SCHEMA auth OWNER TO supabase_auth_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not change auth schema owner: %', SQLERRM;
    END;
    
    BEGIN
        ALTER SCHEMA storage OWNER TO supabase_storage_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not change storage schema owner: %', SQLERRM;
    END;
    
    BEGIN
        ALTER SCHEMA _realtime OWNER TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not change _realtime schema owner: %', SQLERRM;
    END;
    
    BEGIN
        ALTER SCHEMA graphql_public OWNER TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not change graphql_public schema owner: %', SQLERRM;
    END;
    
    BEGIN
        ALTER SCHEMA supabase_functions OWNER TO supabase_functions_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not change supabase_functions schema owner: %', SQLERRM;
    END;

    BEGIN
        ALTER SCHEMA realtime OWNER TO supabase_realtime_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not change realtime schema owner: %', SQLERRM;
    END;
END $$;

-- Grant schema privileges to the appropriate roles
-- Auth schema privileges
GRANT USAGE ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON SCHEMA auth TO supabase_auth_admin;
GRANT USAGE ON SCHEMA auth TO authenticator;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

-- Grant full privileges to supabase_admin on auth schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA auth TO supabase_admin;
        GRANT CREATE ON SCHEMA auth TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA auth TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant auth schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Set default privileges for the auth schema
ALTER DEFAULT PRIVILEGES IN SCHEMA auth 
GRANT ALL ON TABLES TO supabase_auth_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA auth 
GRANT SELECT ON TABLES TO authenticator, anon, authenticated, service_role;

-- Storage schema privileges
GRANT USAGE ON SCHEMA storage TO supabase_storage_admin;
GRANT ALL PRIVILEGES ON SCHEMA storage TO supabase_storage_admin;
GRANT USAGE ON SCHEMA storage TO authenticator;
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;

-- Grant full privileges to supabase_admin on storage schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA storage TO supabase_admin;
        GRANT CREATE ON SCHEMA storage TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA storage TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant storage schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Realtime schema privileges
GRANT USAGE ON SCHEMA _realtime TO authenticator, anon, authenticated, service_role;

-- Grant full privileges to supabase_admin on _realtime schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA _realtime TO supabase_admin;
        GRANT CREATE ON SCHEMA _realtime TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _realtime TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA _realtime TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant _realtime schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Grant full privileges to supabase_realtime_admin on realtime schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA realtime TO supabase_realtime_admin;
        GRANT CREATE ON SCHEMA realtime TO supabase_realtime_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA realtime TO supabase_realtime_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA realtime TO supabase_realtime_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA realtime GRANT ALL PRIVILEGES ON TABLES TO supabase_realtime_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA realtime GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_realtime_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant realtime schema permissions to supabase_realtime_admin: %', SQLERRM;
    END;
END $$;

-- graphql_public schema privileges
GRANT USAGE ON SCHEMA graphql_public TO anon, authenticated, service_role;

-- Grant full privileges to supabase_admin on graphql_public schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA graphql_public TO supabase_admin;
        GRANT CREATE ON SCHEMA graphql_public TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA graphql_public TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA graphql_public TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA graphql_public GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA graphql_public GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant graphql_public schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Public schema privileges
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON SCHEMA public TO supabase_auth_admin;
GRANT CREATE ON SCHEMA public TO supabase_auth_admin;
GRANT CREATE ON SCHEMA public TO service_role;
GRANT CREATE ON SCHEMA public TO anon;

-- Grant full privileges to supabase_admin on public schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA public TO supabase_admin;
        GRANT CREATE ON SCHEMA public TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant public schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Set default privileges for public schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;

-- Extensions schema privileges
GRANT USAGE ON SCHEMA extensions TO public;

-- Grant full privileges to supabase_admin on extensions schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA extensions TO supabase_admin;
        GRANT CREATE ON SCHEMA extensions TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA extensions TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA extensions TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA extensions GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA extensions GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant extensions schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Grant privileges on supabase_functions schema
GRANT USAGE ON SCHEMA supabase_functions TO postgres, anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON SCHEMA supabase_functions TO supabase_functions_admin;

-- Grant full privileges to supabase_admin on supabase_functions schema
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA supabase_functions TO supabase_admin;
        GRANT CREATE ON SCHEMA supabase_functions TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA supabase_functions TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA supabase_functions TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant supabase_functions schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions 
GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions 
GRANT ALL ON FUNCTIONS TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions 
GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;

-- Check if _supabase database exists and create it if it doesn't
SELECT 'CREATE DATABASE _supabase WITH OWNER supabase_admin;' 
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '_supabase')
\gexec

-- Set up database connection privileges
DO $$
BEGIN
    -- Grant _supabase database connection privileges
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = '_supabase') THEN
        EXECUTE 'GRANT CONNECT ON DATABASE _supabase TO authenticator, supabase_admin, supabase_auth_admin, supabase_functions_admin, supabase_storage_admin, supabase_realtime_admin';
    END IF;
END $$;

-- Connect to _supabase database and set up schemas
\if :'supabase_exists' = 't'
    \echo '_supabase database exists, connecting...'
    \connect _supabase
    
    -- Create schemas in _supabase
    CREATE SCHEMA IF NOT EXISTS _analytics;
    CREATE SCHEMA IF NOT EXISTS _supavisor;
    
    -- Try to set ownership, handling potential errors
    DO $$
    BEGIN
        BEGIN
            ALTER SCHEMA _analytics OWNER TO supabase_admin;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not change _analytics schema owner: %', SQLERRM;
        END;
        
        BEGIN
            ALTER SCHEMA _supavisor OWNER TO supabase_admin;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not change _supavisor schema owner: %', SQLERRM;
        END;
    END $$;
    
    -- Grant permissions to supabase_admin regardless of ownership
    GRANT ALL PRIVILEGES ON SCHEMA _analytics TO supabase_admin;
    GRANT ALL PRIVILEGES ON SCHEMA _supavisor TO supabase_admin;
    
    -- Create tables for analytics if they don't exist
    CREATE TABLE IF NOT EXISTS _analytics.sources (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    CREATE TABLE IF NOT EXISTS _analytics.events (
        id SERIAL PRIMARY KEY,
        source_id INTEGER REFERENCES _analytics.sources(id),
        timestamp TIMESTAMPTZ DEFAULT NOW(),
        event_type TEXT,
        payload JSONB
    );
    
    -- Grant permissions to tables
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _analytics TO supabase_admin;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA _analytics TO supabase_admin;
    
    -- Return to postgres database
    \connect postgres
\else
    \echo '_supabase database does not exist, skipping _supabase setup'
\endif

-- Create the pglogical extension for replication if possible
DO $$
BEGIN
    BEGIN
        CREATE EXTENSION IF NOT EXISTS pglogical;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not create pglogical extension: %', SQLERRM;
    END;
END $$;

-- Create schema with the database name passed as parameter if it doesn't exist already
DO $$
BEGIN
    IF :'realtime_db' IS NOT NULL THEN
        EXECUTE 'CREATE SCHEMA IF NOT EXISTS ' || quote_ident(:'realtime_db');
    END IF;
END $$;

-- Create schema for realtime table-level replication if needed
CREATE SCHEMA IF NOT EXISTS _realtime;
GRANT USAGE ON SCHEMA _realtime TO authenticator, anon, authenticated, service_role;

-- Create table needed by RLS-managed realtime subscriptions
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = '_realtime' AND tablename = 'schema_migrations') THEN
    CREATE TABLE _realtime.schema_migrations (
      version bigint PRIMARY KEY,
      inserted_at timestamptz NOT NULL DEFAULT NOW()
    );
  END IF;
END $$;

-- Make sure tables in _realtime schema are accessible
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _realtime TO supabase_admin;



-- Create schema for realtime table-level replication if needed
CREATE SCHEMA IF NOT EXISTS realtime;
GRANT USAGE ON SCHEMA realtime TO authenticator, anon, authenticated, service_role;

-- Create table needed by RLS-managed realtime subscriptions
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'schema_migrations') THEN
    CREATE TABLE realtime.schema_migrations (
      version bigint PRIMARY KEY,
      inserted_at timestamptz NOT NULL DEFAULT NOW()
    );
  END IF;
END $$;

-- Make sure tables in _realtime schema are accessible
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA realtime TO supabase_admin;

-- Grant pglogical schema permissions to supabase_admin
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA pglogical TO supabase_admin;
        GRANT CREATE ON SCHEMA pglogical TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pglogical TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pglogical TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA pglogical GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA pglogical GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant pglogical schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Grant _realtime schema permissions to supabase_admin
DO $$
BEGIN
    BEGIN
        GRANT USAGE ON SCHEMA _realtime TO supabase_admin;
        GRANT CREATE ON SCHEMA _realtime TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _realtime TO supabase_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA _realtime TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON TABLES TO supabase_admin;
        ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_admin;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Warning: Could not grant _realtime schema permissions to supabase_admin: %', SQLERRM;
    END;
END $$;

-- Hack to get auth to boot up on external RDS
DO $$
BEGIN
    -- Create the enum type only if it doesn't already exist.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON t.typnamespace = n.oid
        WHERE t.typname = 'factor_type'
          AND n.nspname = 'auth'
    ) THEN
        CREATE TYPE auth.factor_type AS ENUM ('totp');
    END IF;
END $$;

ALTER TABLE auth.mfa_factors
    ADD COLUMN IF NOT EXISTS factor_type auth.factor_type;

UPDATE auth.mfa_factors
    SET factor_type = 'totp'
    WHERE factor_type IS NULL;

ALTER TABLE auth.mfa_factors
    ALTER COLUMN factor_type SET NOT NULL;

DO $$
BEGIN
    -- Attempt to add the new enum value; ignore if it already exists.
    BEGIN
        ALTER TYPE auth.factor_type ADD VALUE 'phone';
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;
END $$;

ALTER TABLE auth.mfa_factors
    ADD COLUMN IF NOT EXISTS phone TEXT UNIQUE DEFAULT NULL;

ALTER TABLE auth.mfa_challenges
    ADD COLUMN IF NOT EXISTS otp_code TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS unique_verified_phone_factor
    ON auth.mfa_factors (user_id, phone);

ALTER TYPE auth.factor_type
    OWNER TO supabase_auth_admin;

-- Grant database privileges
GRANT ALL PRIVILEGES ON DATABASE postgres TO supabase_admin;
GRANT ALL PRIVILEGES ON DATABASE mailopolyapp TO supabase_auth_admin;

-- Set search path for roles
ALTER ROLE supabase_auth_admin SET search_path TO public;

-- Create the realtime schema if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_namespace WHERE nspname = 'realtime'
    ) THEN
        CREATE SCHEMA realtime;
        RAISE NOTICE 'Schema "realtime" created.';
    ELSE
        RAISE NOTICE 'Schema "realtime" already exists. Skipping creation.';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create schema "realtime"; skipping.';
END;
$$;

-- Create or update the supabase_realtime_admin role with the passed postgres_password
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'supabase_realtime_admin'
    ) THEN
        EXECUTE format('CREATE ROLE supabase_realtime_admin WITH LOGIN PASSWORD %L NOREPLICATION', :'postgres_password');
        RAISE NOTICE 'Role "supabase_realtime_admin" created with provided password.';
    ELSE
        EXECUTE format('ALTER ROLE supabase_realtime_admin WITH LOGIN PASSWORD %L', :'postgres_password');
        RAISE NOTICE 'Role "supabase_realtime_admin" password updated to provided password.';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create or alter role "supabase_realtime_admin"; skipping.';
        RAISE EXCEPTION 'Role creation/alteration failed due to insufficient privileges.';
    WHEN others THEN
        RAISE NOTICE 'Error creating/altering supabase_realtime_admin: %', SQLERRM;
        RAISE EXCEPTION 'Role creation/alteration failed: %', SQLERRM;
END;
$$;

-- Create or update the authenticator role with the passed postgres_password
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'authenticator'
    ) THEN
        EXECUTE format('CREATE ROLE authenticator WITH LOGIN PASSWORD %L NOINHERIT', :'postgres_password');
        RAISE NOTICE 'Role "authenticator" created with provided password.';
    ELSE
        EXECUTE format('ALTER ROLE authenticator WITH LOGIN PASSWORD %L NOINHERIT', :'postgres_password');
        RAISE NOTICE 'Role "authenticator" password updated to provided password.';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create or alter role "authenticator"; skipping.';
        RAISE EXCEPTION 'Role creation/alteration failed due to insufficient privileges.';
    WHEN others THEN
        RAISE NOTICE 'Error creating/altering authenticator: %', SQLERRM;
        RAISE EXCEPTION 'Role creation/alteration failed: %', SQLERRM;
END;
$$;

-- Grant supabase_realtime_admin to the current user (e.g., POSTGRES_USER) to allow SET ROLE
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_auth_members 
        WHERE roleid = (SELECT oid FROM pg_roles WHERE rolname = 'supabase_realtime_admin')
        AND member = (SELECT oid FROM pg_roles WHERE rolname = current_user)
    ) THEN
        EXECUTE format('GRANT supabase_realtime_admin TO %I;', current_user);
        RAISE NOTICE 'Granted supabase_realtime_admin to current user (%s).', current_user;
    ELSE
        RAISE NOTICE 'Current user (%s) already has supabase_realtime_admin role. Skipping grant.', current_user;
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to grant supabase_realtime_admin to %s; skipping.', current_user;
END;
$$;

-- Grant replication permissions to supabase_realtime_admin (RDS-specific)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'rds_replication'
    ) THEN
        GRANT rds_replication TO supabase_realtime_admin;
        RAISE NOTICE 'Granted rds_replication to supabase_realtime_admin.';
    ELSE
        RAISE NOTICE 'rds_replication role not found; skipping replication grant (may not be RDS or already granted).';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to grant rds_replication; skipping (manual intervention may be required).';
END;
$$;

-- Create tables and sequences in the realtime schema with supabase_realtime_admin as owner
DO $$
BEGIN
    -- Set role to supabase_realtime_admin to ensure ownership
    SET ROLE supabase_realtime_admin;

    -- Create messages table
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'messages'
    ) THEN
        CREATE TABLE realtime.messages (
            id SERIAL PRIMARY KEY,
            payload JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        RAISE NOTICE 'Table "realtime.messages" created.';
    ELSE
        ALTER TABLE realtime.messages OWNER TO supabase_realtime_admin;
        RAISE NOTICE 'Table "realtime.messages" ownership set to supabase_realtime_admin.';
    END IF;

    -- Create users table
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'users'
    ) THEN
        CREATE TABLE realtime.users (
            id SERIAL PRIMARY KEY,
            username TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        RAISE NOTICE 'Table "realtime.users" created.';
    ELSE
        ALTER TABLE realtime.users OWNER TO supabase_realtime_admin;
        RAISE NOTICE 'Table "realtime.users" ownership set to supabase_realtime_admin.';
    END IF;

    -- Create broadcasts table
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'broadcasts'
    ) THEN
        CREATE TABLE realtime.broadcasts (
            id SERIAL PRIMARY KEY,
            payload JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        RAISE NOTICE 'Table "realtime.broadcasts" created.';
    ELSE
        ALTER TABLE realtime.broadcasts OWNER TO supabase_realtime_admin;
        RAISE NOTICE 'Table "realtime.broadcasts" ownership set to supabase_realtime_admin.';
    END IF;

    -- Create channels table
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'channels'
    ) THEN
        CREATE TABLE realtime.channels (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        RAISE NOTICE 'Table "realtime.channels" created.';
    ELSE
        ALTER TABLE realtime.channels OWNER TO supabase_realtime_admin;
        RAISE NOTICE 'Table "realtime.channels" ownership set to supabase_realtime_admin.';
    END IF;

    -- Create presences table
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'presences'
    ) THEN
        CREATE TABLE realtime.presences (
            id SERIAL PRIMARY KEY,
            user_id INT NOT NULL,
            status TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        RAISE NOTICE 'Table "realtime.presences" created.';
    ELSE
        ALTER TABLE realtime.presences OWNER TO supabase_realtime_admin;
        RAISE NOTICE 'Table "realtime.presences" ownership set to supabase_realtime_admin.';
    END IF;

    -- Ensure sequence ownership
    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'realtime' AND sequencename = 'messages_id_seq') THEN
            ALTER SEQUENCE realtime.messages_id_seq OWNER TO supabase_realtime_admin;
            RAISE NOTICE 'Sequence "realtime.messages_id_seq" ownership set to supabase_realtime_admin.';
        ELSE
            RAISE NOTICE 'Sequence "realtime.messages_id_seq" does not exist.';
        END IF;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE 'Sequence "realtime.messages_id_seq" does not exist.';
    END;
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'realtime' AND sequencename = 'users_id_seq') THEN
            ALTER SEQUENCE realtime.users_id_seq OWNER TO supabase_realtime_admin;
            RAISE NOTICE 'Sequence "realtime.users_id_seq" ownership set to supabase_realtime_admin.';
        ELSE
            RAISE NOTICE 'Sequence "realtime.users_id_seq" does not exist.';
        END IF;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE 'Sequence "realtime.users_id_seq" does not exist.';
    END;
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'realtime' AND sequencename = 'broadcasts_id_seq') THEN
            ALTER SEQUENCE realtime.broadcasts_id_seq OWNER TO supabase_realtime_admin;
            RAISE NOTICE 'Sequence "realtime.broadcasts_id_seq" ownership set to supabase_realtime_admin.';
        ELSE
            RAISE NOTICE 'Sequence "realtime.broadcasts_id_seq" does not exist.';
        END IF;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE 'Sequence "realtime.broadcasts_id_seq" does not exist.';
    END;
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'realtime' AND sequencename = 'channels_id_seq') THEN
            ALTER SEQUENCE realtime.channels_id_seq OWNER TO supabase_realtime_admin;
            RAISE NOTICE 'Sequence "realtime.channels_id_seq" ownership set to supabase_realtime_admin.';
        ELSE
            RAISE NOTICE 'Sequence "realtime.channels_id_seq" does not exist.';
        END IF;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE 'Sequence "realtime.channels_id_seq" does not exist.';
    END;
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'realtime' AND sequencename = 'presences_id_seq') THEN
            ALTER SEQUENCE realtime.presences_id_seq OWNER TO supabase_realtime_admin;
            RAISE NOTICE 'Sequence "realtime.presences_id_seq" ownership set to supabase_realtime_admin.';
        ELSE
            RAISE NOTICE 'Sequence "realtime.presences_id_seq" does not exist.';
        END IF;
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE 'Sequence "realtime.presences_id_seq" does not exist.';
    END;
    $$;

    RESET ROLE;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Failed to SET ROLE or create/alter tables/sequences; ensure supabase_realtime_admin has CREATE privileges on realtime schema.';
        RAISE EXCEPTION 'Table/sequence creation failed due to insufficient privileges.';
END;
$$;

-- Grant privileges to supabase_realtime_admin on the realtime schema and objects
DO $$
BEGIN
    GRANT ALL ON SCHEMA realtime TO supabase_realtime_admin;
    GRANT ALL ON ALL TABLES IN SCHEMA realtime TO supabase_realtime_admin;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA realtime TO supabase_realtime_admin;
    GRANT ALL ON ALL ROUTINES IN SCHEMA realtime TO supabase_realtime_admin;
    RAISE NOTICE 'Granted ALL privileges to supabase_realtime_admin on realtime schema and objects.';
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to grant privileges to supabase_realtime_admin; manual intervention required.';
END;
$$;

-- Create the supabase_realtime publication if it doesn’t exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        CREATE PUBLICATION supabase_realtime WITH (PUBLISH = 'insert, update, delete');
        RAISE NOTICE 'Publication "supabase_realtime" created.';
    ELSE
        RAISE NOTICE 'Publication "supabase_realtime" already exists. Skipping creation.';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create publication "supabase_realtime"; skipping.';
END;
$$;

-- Add tables to the supabase_realtime publication
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'messages') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'messages' AND schemaname = 'realtime'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE realtime.messages;
            RAISE NOTICE 'Table "realtime.messages" added to supabase_realtime publication.';
        ELSE
            RAISE NOTICE 'Table "realtime.messages" already in supabase_realtime publication.';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'users') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'users' AND schemaname = 'realtime'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE realtime.users;
            RAISE NOTICE 'Table "realtime.users" added to supabase_realtime publication.';
        ELSE
            RAISE NOTICE 'Table "realtime.users" already in supabase_realtime publication.';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'broadcasts') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'broadcasts' AND schemaname = 'realtime'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE realtime.broadcasts;
            RAISE NOTICE 'Table "realtime.broadcasts" added to supabase_realtime publication.';
        ELSE
            RAISE NOTICE 'Table "realtime.broadcasts" already in supabase_realtime publication.';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'channels') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'channels' AND schemaname = 'realtime'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE realtime.channels;
            RAISE NOTICE 'Table "realtime.channels" added to supabase_realtime publication.';
        ELSE
            RAISE NOTICE 'Table "realtime.channels" already in supabase_realtime publication.';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'presences') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'presences' AND schemaname = 'realtime'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE realtime.presences;
            RAISE NOTICE 'Table "realtime.presences" added to supabase_realtime publication.';
        ELSE
            RAISE NOTICE 'Table "realtime.presences" already in supabase_realtime publication.';
        END IF;
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to alter publication "supabase_realtime"; skipping.';
END;
$$;

-- Grant SELECT on messages to anon role (for authorization handling)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'anon'
    ) THEN
        CREATE ROLE anon NOLOGIN noinherit;
        RAISE NOTICE 'Role "anon" created.';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'realtime' AND tablename = 'messages') THEN
        GRANT SELECT ON TABLE realtime.messages TO anon;
        RAISE NOTICE 'Granted SELECT on realtime.messages to anon.';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create anon role or grant SELECT on realtime.messages; skipping.';
END;
$$;

-- Create authenticated role if it doesn’t exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'authenticated'
    ) THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
        RAISE NOTICE 'Role "authenticated" created.';
    ELSE
        RAISE NOTICE 'Role "authenticated" already exists. Skipping creation.';
    END IF;
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create authenticated role; skipping.';
END;
$$;




-- Verify completion
DO $$
BEGIN
    RAISE NOTICE '✅ Database bootstrap completed successfully';
END $$;