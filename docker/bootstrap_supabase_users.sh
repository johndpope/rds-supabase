#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color



# Default connection parameters (can be overridden by environment variables)
POSTGRES_HOST="${POSTGRES_HOST:-your-rds-endpoint}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-your-username}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-your-password}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate required tools
if ! command_exists psql; then
    echo -e "${RED}Error: psql is not installed. Please install PostgreSQL client.${NC}"
    exit 1
fi

# Function to run SQL commands on a specific database
run_sql() {
    local db="$1"
    local sql="$2"
    PGPASSWORD="${POSTGRES_PASSWORD}" psql \
        -h "${POSTGRES_HOST}" \
        -p "${POSTGRES_PORT}" \
        -U "${POSTGRES_USER}" \
        -d "$db" \
        -c "$sql" 2>&1
}

# Function to create a role if it doesn't exist
create_role_if_not_exists() {
    local role_name=$1
    local role_options=$2
    
    echo -e "${GREEN}Creating role $role_name if it doesn't exist...${NC}"
    
    # Check if role exists
    local role_exists=$(run_sql "postgres" "SELECT 1 FROM pg_roles WHERE rolname='$role_name';")
    
    if [[ $role_exists == *"(1 row)"* ]]; then
        echo -e "${YELLOW}Role $role_name already exists.${NC}"
    else
        local create_sql="CREATE ROLE $role_name $role_options;"
        result=$(run_sql "postgres" "$create_sql")
        if echo "$result" | grep -q "ERROR"; then
            echo -e "${RED}Failed to create role $role_name: $result${NC}"
        else
            echo -e "${GREEN}Successfully created role $role_name${NC}"
        fi
    fi
}

# Create Supabase roles without depending on superuser privileges
create_supabase_roles() {
    echo -e "${GREEN}Creating necessary Supabase roles...${NC}"
    
    # Create roles with LOGIN option first (these can be created more easily)
    create_role_if_not_exists "authenticator" "WITH NOINHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'authenticator_password'"
    create_role_if_not_exists "pgbouncer" "WITH INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'pgbouncer_password'"
    create_role_if_not_exists "supabase_auth_admin" "WITH NOINHERIT CREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'supabase_auth_admin_password'"
    create_role_if_not_exists "supabase_functions_admin" "WITH NOINHERIT CREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'supabase_functions_admin_password'"
    create_role_if_not_exists "supabase_read_only_user" "WITH INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION"
    create_role_if_not_exists "supabase_replication_admin" "WITH INHERIT NOCREATEROLE NOCREATEDB LOGIN REPLICATION"
    create_role_if_not_exists "supabase_storage_admin" "WITH NOINHERIT CREATEROLE NOCREATEDB LOGIN NOREPLICATION PASSWORD 'supabase_storage_admin_password'"

    # Create NOLOGIN roles
    create_role_if_not_exists "anon" "WITH INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION"
    create_role_if_not_exists "authenticated" "WITH INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION"
    create_role_if_not_exists "dashboard_user" "WITH INHERIT CREATEROLE CREATEDB NOLOGIN REPLICATION"
    create_role_if_not_exists "pgsodium_keyholder" "WITH INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION"
    create_role_if_not_exists "pgsodium_keyiduser" "WITH INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION"
    create_role_if_not_exists "pgsodium_keymaker" "WITH INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION"
    create_role_if_not_exists "service_role" "WITH INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION"
    create_role_if_not_exists "supabase_realtime_admin" "WITH NOINHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION"
    
    # For supabase_admin, check if we have permissions to create it with SUPERUSER
    echo -e "${YELLOW}Attempting to create supabase_admin with SUPERUSER privileges...${NC}"
    create_role_if_not_exists "supabase_admin" "WITH INHERIT CREATEROLE CREATEDB LOGIN REPLICATION PASSWORD 'supabase_admin_password'"
    
    echo -e "${YELLOW}Note: You may need to manually alter the supabase_admin role to add SUPERUSER and BYPASSRLS privileges.${NC}"
    echo -e "${YELLOW}Connect as a superuser and run: ALTER ROLE supabase_admin WITH SUPERUSER BYPASSRLS;${NC}"
}

# Set role configuration parameters
configure_roles() {
    echo -e "${GREEN}Configuring role parameters...${NC}"
    
    # Try to set role parameters (some may fail without superuser)
    run_sql "postgres" "ALTER ROLE anon SET statement_timeout TO '3s';"
    run_sql "postgres" "ALTER ROLE authenticated SET statement_timeout TO '8s';"
    
    run_sql "postgres" "ALTER ROLE authenticator SET statement_timeout TO '8s';"
    run_sql "postgres" "ALTER ROLE authenticator SET lock_timeout TO '8s';"
    # Skip this one as it often needs superuser: ALTER ROLE authenticator SET session_preload_libraries TO 'safeupdate';
    
    run_sql "postgres" "ALTER ROLE supabase_admin SET search_path TO '$user', 'public', 'auth', 'extensions';"
    run_sql "postgres" "ALTER ROLE supabase_admin SET log_statement TO 'none';"
    
    run_sql "postgres" "ALTER ROLE supabase_auth_admin SET search_path TO 'auth';"
    run_sql "postgres" "ALTER ROLE supabase_auth_admin SET idle_in_transaction_session_timeout TO '60000';"
    run_sql "postgres" "ALTER ROLE supabase_auth_admin SET log_statement TO 'none';"
    
    run_sql "postgres" "ALTER ROLE supabase_functions_admin SET search_path TO 'supabase_functions';"
    
    run_sql "postgres" "ALTER ROLE supabase_storage_admin SET search_path TO 'storage';"
    run_sql "postgres" "ALTER ROLE supabase_storage_admin SET log_statement TO 'none';"
    
    echo -e "${GREEN}Role configuration completed.${NC}"
}

# Set up role memberships (grant roles)
setup_role_memberships() {
    echo -e "${GREEN}Setting up role memberships...${NC}"
    
    # We'll try these, but many may fail without superuser privileges
    run_sql "postgres" "GRANT anon TO authenticator;"
    run_sql "postgres" "GRANT authenticated TO authenticator;"
    
    # Service role grants
    run_sql "postgres" "GRANT service_role TO authenticator;"
    
    # Try to grant pgsodium roles
    run_sql "postgres" "GRANT pgsodium_keyholder TO pgsodium_keymaker;"
    run_sql "postgres" "GRANT pgsodium_keyholder TO service_role;"
    run_sql "postgres" "GRANT pgsodium_keyiduser TO pgsodium_keyholder;"
    run_sql "postgres" "GRANT pgsodium_keyiduser TO pgsodium_keymaker;"
    
    echo -e "${YELLOW}Note: You may need superuser privileges to set up all role memberships correctly.${NC}"
    echo -e "${YELLOW}Please refer to the original postgres_users.sql file for the complete list of role memberships.${NC}"
}

# Function to create schemas if they don't exist
create_schemas() {
    echo -e "${GREEN}Creating necessary schemas...${NC}"
    
    local schemas=("auth" "extensions" "storage" "supabase_functions" "realtime" "graphql" "graphql_public" "_realtime" "pgbouncer" "vault")
    
    for schema in "${schemas[@]}"; do
        run_sql "postgres" "CREATE SCHEMA IF NOT EXISTS $schema;"
        echo -e "${GREEN}Created schema $schema if it didn't exist${NC}"
    done
}

# Main function
main() {
    # Validate connection parameters
    if [[ -z "$POSTGRES_HOST" || -z "$POSTGRES_PASSWORD" || -z "$POSTGRES_USER" ]]; then
        echo -e "${RED}Error: Missing required connection parameters.${NC}"
        echo "Please set POSTGRES_HOST, POSTGRES_USER, and POSTGRES_PASSWORD in .env or environment"
        exit 1
    fi
    
    echo -e "${YELLOW}Starting Supabase user import process...${NC}"
    echo -e "${YELLOW}WARNING: This script will attempt to create Supabase roles and set their configurations.${NC}"
    echo -e "${YELLOW}Some operations may require superuser privileges and might fail.${NC}"
    echo -e "${RED}This script uses placeholder passwords. Please update them for production use!${NC}"
    
    # Confirm before proceeding
    read -p "Are you sure you want to proceed? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
    
    # Create the roles
    create_supabase_roles
    
    # Configure the roles
    configure_roles
    
    # Create necessary schemas
    create_schemas
    
    # Set up role memberships
    setup_role_memberships
    
    echo -e "${GREEN}Import process completed.${NC}"
    echo -e "${YELLOW}Important post-import steps:${NC}"
    echo -e "1. ${YELLOW}Update role passwords to secure values${NC}"
    echo -e "2. ${YELLOW}If you have superuser access, add SUPERUSER and BYPASSRLS attributes to supabase_admin:${NC}"
    echo -e "   ${GREEN}ALTER ROLE supabase_admin WITH SUPERUSER BYPASSRLS;${NC}"
    echo -e "3. ${YELLOW}If you have superuser access, complete role memberships from postgres_users.sql${NC}"
}

# Run the main function
main