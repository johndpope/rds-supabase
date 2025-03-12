-- use rds bootstrap script instead of this file

-- Ensure auth schema exists
CREATE SCHEMA IF NOT EXISTS auth;

-- Set the search path to include auth schema
SET search_path TO auth, public;

-- Ensure the schema migrations table exists in the auth schema
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(14) NOT NULL,
    PRIMARY KEY(version)
);

CREATE UNIQUE INDEX IF NOT EXISTS schema_migrations_version_idx ON schema_migrations (version);

-- Grant necessary privileges
GRANT ALL PRIVILEGES ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON TABLE schema_migrations TO supabase_auth_admin;


-- Ensure the supabase_auth_admin role exists and has correct permissions
DO $$
BEGIN
    -- Create or modify supabase_auth_admin role
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        CREATE ROLE supabase_auth_admin WITH LOGIN NOINHERIT PASSWORD 'your-super-secret-and-long-postgres-password';
    ELSE
        ALTER ROLE supabase_auth_admin WITH LOGIN NOINHERIT PASSWORD 'your-super-secret-and-long-postgres-password';
    END IF;

    -- Grant connect privileges
    GRANT CONNECT ON DATABASE mailopolyapp TO supabase_auth_admin;

    -- Set search path
    ALTER ROLE supabase_auth_admin SET search_path TO auth, public;
END $$;

-- Create auth schema if not exists
CREATE SCHEMA IF NOT EXISTS auth;

-- Grant schema privileges
GRANT USAGE ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON SCHEMA auth TO supabase_auth_admin;

-- Ensure schema migrations table exists in the auth schema
CREATE TABLE IF NOT EXISTS auth.schema_migrations (
    version VARCHAR(14) NOT NULL,
    PRIMARY KEY(version)
);

CREATE UNIQUE INDEX IF NOT EXISTS schema_migrations_version_idx 
ON auth.schema_migrations (version);

-- Grant privileges on schema migrations table
GRANT ALL PRIVILEGES ON TABLE auth.schema_migrations TO supabase_auth_admin;

-- Additional authentication-related setup
DO $$
BEGIN
    -- Create the enum type only if it doesn't already exist
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

-- Ensure the auth user can create tables and perform necessary operations
GRANT CREATE ON SCHEMA auth TO supabase_auth_admin;
GRANT CREATE ON SCHEMA public TO supabase_auth_admin;


-- Create AAL (Authentication Assurance Level) Type and Modifications

-- Ensure we're in the auth schema
SET search_path TO auth, public;

-- Create the aal_level enum type if it doesn't exist
DO $$
BEGIN
    -- Check if the type already exists before creating
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_type t
        JOIN pg_namespace n ON t.typnamespace = n.oid
        WHERE t.typname = 'aal_level' AND n.nspname = 'auth'
    ) THEN
        CREATE TYPE aal_level AS ENUM (
            'aal1',   -- Lowest assurance level
            'aal2',   -- Medium assurance level
            'aal3'    -- Highest assurance level
        );
    END IF;
END $$;

-- Alter sessions table to add factor_id and aal columns
DO $$
BEGIN
    -- Add factor_id column if not exists
    BEGIN
        ALTER TABLE auth.sessions 
        ADD COLUMN IF NOT EXISTS factor_id UUID NULL;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not add factor_id column to sessions: %', SQLERRM;
    END;

    -- Add aal column if not exists
    BEGIN
        ALTER TABLE auth.sessions 
        ADD COLUMN IF NOT EXISTS aal aal_level NULL;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not add aal column to sessions: %', SQLERRM;
    END;
END $$;

-- Ensure the type is owned by supabase_auth_admin
ALTER TYPE aal_level OWNER TO supabase_auth_admin;


-- Backfill last_sign_in_at for email identities
DO $$
BEGIN
    UPDATE auth.identities
    SET last_sign_in_at = '2022-11-25'
    WHERE 
        last_sign_in_at IS NULL AND
        created_at = '2022-11-25' AND
        updated_at = '2022-11-25' AND
        provider = 'email' AND
        id::text = user_id::text;
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in backfill migration: %', SQLERRM;
END $$;