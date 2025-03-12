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

# Databases to reset
DATABASES=("postgres" "_supabase")

# List of Supabase roles to drop
SUPABASE_ROLES=(
    "anon"
    "authenticated"
    "authenticator"
    "dashboard_user"
    "pgbouncer"
    "pgsodium_keyholder"
    "pgsodium_keyiduser"
    "pgsodium_keymaker"
    "service_role"
    "supabase_admin"
    "supabase_auth_admin"
    "supabase_functions_admin"
    "supabase_read_only_user"
    "supabase_realtime_admin"
    "supabase_replication_admin"
    "supabase_storage_admin"
)

# List of Supabase schemas to drop
SUPABASE_SCHEMAS=(
    "_realtime"
    "auth"
    "extensions"
    "graphql"
    "graphql_public"
    "pgbouncer"
    "pgsodium"
    "realtime"
    "storage"
    "supabase_functions"
    "vault"
)

# List of extensions to drop
SUPABASE_EXTENSIONS=(
    "pg_net"
    "pgsodium"
    "pg_graphql"
    "pg_stat_statements"
    "pgcrypto"
    "pgjwt"
    "supabase_vault"
    "uuid-ossp"
)

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

# Display warning and get confirmation
confirm_action() {
    echo -e "${YELLOW}WARNING: 👹 This script will completely wipe Supabase from your RDS instance:${NC}"
    echo -e "  ${RED}Host:${NC} ${POSTGRES_HOST}:${POSTGRES_PORT}"
    echo -e "  ${RED}User:${NC} ${POSTGRES_USER}"
    echo -e "  ${RED}Databases:${NC} ${DATABASES[*]}"
    echo -e "${YELLOW}This action will:${NC}"
    echo -e "\n\n\n\n RUN THIS 2x \n\n\n:${NC}"
    echo "1. Drop all Supabase-related schemas (_realtime, auth, storage, etc.) across all databases"
    echo "2. Drop all Supabase-related extensions (pgsodium, pgcrypto, pg_graphql, etc.)"
    echo "3. Remove all event triggers related to Supabase" 
    echo "4. Revoke privileges from Supabase roles"
    echo "5. Drop all Supabase-related roles (supabase_realtime_admin, authenticator, anon, etc.)"
    echo "6. Reset the public schema in each database"
    echo "7. Install pgcrypto extension (only supported extension)"
    echo "8. Set up a minimal auth schema owned by ${POSTGRES_USER}"
    echo -e "${RED}THIS ACTION CANNOT BE UNDONE! ALL DATA WILL BE LOST!${NC}"
    echo -e "${YELLOW}Note: Certain roles (anon, authenticated, service_role, supabase_admin) may require superuser privileges to fully remove.${NC}"
    echo -e "${YELLOW}If this script doesn't fully clean up, you may need to connect as a PostgreSQL superuser to complete removal.${NC}"
    
    read -p "Are you absolutely sure you want to proceed? (y/N): " response
    [[ "$response" =~ ^[Yy]$ ]]
}


# Function to drop all Supabase roles on RDS
drop_all_roles() {
    echo -e "${GREEN}Starting role removal process on RDS...${NC}"

    # Check if the current user is the RDS master user (mlypg_admin)
    local check_user_sql="SELECT current_user, rolsuper, rolname FROM pg_roles WHERE rolname = 'mlypg_admin';"
    local user_check=$(run_sql "postgres" "$check_user_sql")
    if ! echo "$user_check" | grep -q "mlypg_admin"; then
        echo -e "${RED}Error: This script must be run as the RDS master user 'mlypg_admin'.${NC}"
        echo -e "${YELLOW}Current user info:${NC}"
        echo "$user_check"
        exit 1
    fi
    if ! echo "$user_check" | grep -q "rds_superuser"; then
        echo -e "${YELLOW}Warning: mlypg_admin should have rds_superuser privileges. Proceeding anyway...${NC}"
    fi

    # Revoke all memberships to eliminate dependencies
    local revoke_memberships_sql="
    DO \$\$
    DECLARE
        member_role text;
        granted_role text;
    BEGIN
        FOR member_role, granted_role IN 
            SELECT m.rolname, g.rolname
            FROM pg_auth_members am
            JOIN pg_roles m ON am.member = m.oid
            JOIN pg_roles g ON am.roleid = g.oid
            WHERE m.rolname IN ($(printf "'%s'," "${SUPABASE_ROLES[@]}" | sed 's/,$//'))
            OR g.rolname IN ($(printf "'%s'," "${SUPABASE_ROLES[@]}" | sed 's/,$//'))
        LOOP
            BEGIN
                EXECUTE format('REVOKE %I FROM %I', granted_role, member_role);
                RAISE NOTICE 'Revoked % from %', granted_role, member_role;
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Error revoking % from %: %', granted_role, member_role, SQLERRM;
            END;
        END LOOP;
    END;
    \$\$;
    "
    echo -e "${GREEN}Revoking role memberships...${NC}"
    result=$(run_sql "postgres" "$revoke_memberships_sql")
    echo "$result"

    # Revoke all privileges from Supabase roles on all databases
    local revoke_db_privs_sql="
    DO \$\$
    DECLARE
        db_name text;
        role_name text;
    BEGIN
        FOR db_name IN (SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%') LOOP
            FOR role_name IN SELECT unnest(ARRAY[$(printf "'%s'," "${SUPABASE_ROLES[@]}" | sed 's/,$//')]) LOOP
                BEGIN
                    EXECUTE format('REVOKE ALL ON DATABASE %I FROM %I CASCADE', db_name, role_name);
                    RAISE NOTICE 'Revoked privileges on database % from %', db_name, role_name;
                EXCEPTION WHEN others THEN
                    RAISE NOTICE 'Error revoking privileges on % from %: %', db_name, role_name, SQLERRM;
                END;
            END LOOP;
        END LOOP;
    END;
    \$\$;
    "
    echo -e "${GREEN}Revoking database privileges...${NC}"
    result=$(run_sql "postgres" "$revoke_db_privs_sql")
    echo "$result"

    # Reassign and drop each role
    for role in "${SUPABASE_ROLES[@]}"; do
        echo -e "${GREEN}Processing role: $role${NC}"

        # Reassign owned objects to mlypg_admin
        local reassign_sql="REASSIGN OWNED BY \"$role\" TO \"mlypg_admin\";"
        result=$(run_sql "postgres" "$reassign_sql")
        if echo "$result" | grep -q "ERROR"; then
            echo -e "${YELLOW}Warning: Could not reassign objects owned by $role:${NC}"
            echo "$result"
        else
            echo -e "${GREEN}Reassigned owned objects from $role to mlypg_admin${NC}"
        fi

        # Drop owned objects as a fallback
        local drop_owned_sql="DROP OWNED BY \"$role\" CASCADE;"
        result=$(run_sql "postgres" "$drop_owned_sql")
        if echo "$result" | grep -q "ERROR"; then
            echo -e "${YELLOW}Warning: Could not drop objects owned by $role:${NC}"
            echo "$result"
        else
            echo -e "${GREEN}Dropped objects owned by $role${NC}"
        fi

        # Drop the role
        local drop_role_sql="DROP ROLE IF EXISTS \"$role\";"
        result=$(run_sql "postgres" "$drop_role_sql")
        if echo "$result" | grep -q "ERROR"; then
            echo -e "${RED}Failed to drop role $role:${NC}"
            echo "$result"
        else
            echo -e "${GREEN}Successfully dropped role $role${NC}"
        fi
    done

    # Final check for remaining roles
    local role_check_sql="SELECT rolname FROM pg_roles WHERE rolname IN ($(printf "'%s'," "${SUPABASE_ROLES[@]}" | sed 's/,$//'));"
    result=$(run_sql "postgres" "$role_check_sql")
    if [[ -z "$result" || "$result" =~ \(0\ rows\) ]]; then
        echo -e "${GREEN}All Supabase roles successfully dropped.${NC}"
    else
        echo -e "${YELLOW}Some roles still exist:${NC}"
        echo "$result"
        echo -e "${YELLOW}You may need to manually investigate or escalate to AWS support.${NC}"
    fi

    echo -e "${GREEN}Role removal process completed.${NC}"
}

# Function to drop extensions in each database
drop_all_extensions() {
    echo -e "${GREEN}Starting extension removal process...${NC}"
    
    for db in "${DATABASES[@]}"; do
        # Check if database exists
        if run_sql "postgres" "SELECT 1 FROM pg_database WHERE datname = '$db';" | grep -q "1"; then
            echo -e "${GREEN}Dropping extensions in database: $db${NC}"
            
            # Drop event triggers first to avoid conflicts
            local drop_triggers_sql="
            DO \$\$
            DECLARE
                trigger_name text;
            BEGIN
                FOR trigger_name IN (
                    SELECT t.tgname FROM pg_trigger t
                    JOIN pg_class c ON t.tgrelid = c.oid
                    JOIN pg_namespace n ON c.relnamespace = n.oid
                    WHERE n.nspname = 'extensions'
                    UNION
                    SELECT evtname FROM pg_event_trigger
                    WHERE evtname IN ('issue_graphql_placeholder', 'issue_pg_cron_access', 
                                     'issue_pg_graphql_access', 'issue_pg_net_access',
                                     'pgrst_ddl_watch', 'pgrst_drop_watch')
                )
                LOOP
                    BEGIN
                        EXECUTE 'DROP EVENT TRIGGER IF EXISTS ' || trigger_name || ' CASCADE;';
                        RAISE NOTICE 'Dropped event trigger: %', trigger_name;
                    EXCEPTION WHEN OTHERS THEN
                        RAISE NOTICE 'Failed to drop event trigger %: %', trigger_name, SQLERRM;
                    END;
                END LOOP;
            END;
            \$\$;
            "
            
            result=$(run_sql "$db" "$drop_triggers_sql")
            if [[ $? -ne 0 ]]; then
                echo -e "${YELLOW}Warning when dropping event triggers in $db: $result${NC}"
            else
                echo -e "${GREEN}Event triggers dropped in $db${NC}"
            fi
            
            # Drop each extension
            for ext in "${SUPABASE_EXTENSIONS[@]}"; do
                local drop_ext_sql="DROP EXTENSION IF EXISTS \"$ext\" CASCADE;"
                result=$(run_sql "$db" "$drop_ext_sql")
                if echo "$result" | grep -q "ERROR"; then
                    echo -e "${YELLOW}Warning: Could not drop extension $ext in $db: $result${NC}"
                else
                    echo -e "${GREEN}Successfully dropped extension $ext in $db${NC}"
                fi
            done
        else
            echo -e "${YELLOW}Database $db does not exist, skipping extension removal...${NC}"
        fi
    done
    
    echo -e "${GREEN}Extension removal process completed.${NC}"
}

# Function to drop all Supabase schemas
drop_all_schemas() {
    echo -e "${GREEN}Starting schema removal process...${NC}"
    
    for db in "${DATABASES[@]}"; do
        # Check if database exists
        if run_sql "postgres" "SELECT 1 FROM pg_database WHERE datname = '$db';" | grep -q "1"; then
            echo -e "${GREEN}Dropping schemas in database: $db${NC}"
            
            # Drop each schema with cascade to ensure all objects are removed
            for schema in "${SUPABASE_SCHEMAS[@]}"; do
                local drop_schema_sql="DROP SCHEMA IF EXISTS \"$schema\" CASCADE;"
                result=$(run_sql "$db" "$drop_schema_sql")
                if echo "$result" | grep -q "ERROR"; then
                    echo -e "${YELLOW}Warning: Could not drop schema $schema in $db: $result${NC}"
                else
                    echo -e "${GREEN}Successfully dropped schema $schema in $db${NC}"
                fi
            done
        else
            echo -e "${YELLOW}Database $db does not exist, skipping schema removal...${NC}"
        fi
    done
    
    echo -e "${GREEN}Schema removal process completed.${NC}"
}

# Function to reset specific tables related to realtime and supabase
reset_specific_tables() {
    echo -e "${GREEN}Resetting specific tables...${NC}"
    
    for db in "${DATABASES[@]}"; do
        # Check if database exists
        if run_sql "postgres" "SELECT 1 FROM pg_database WHERE datname = '$db';" | grep -q "1"; then
            echo -e "${GREEN}Checking for remaining tables in database: $db${NC}"
            
            # Drop publication if exists
            local drop_publication_sql="DROP PUBLICATION IF EXISTS supabase_realtime;"
            result=$(run_sql "$db" "$drop_publication_sql")
            if echo "$result" | grep -q "ERROR"; then
                echo -e "${YELLOW}Warning: Could not drop publication in $db: $result${NC}"
            else
                echo -e "${GREEN}Successfully dropped publication in $db${NC}"
            fi
            
            # Drop replication slots if they exist
            local drop_replication_slots_sql="
            DO \$\$
            DECLARE
                slot_name text;
            BEGIN
                FOR slot_name IN (
                    SELECT slot_name FROM pg_replication_slots 
                    WHERE slot_name LIKE 'supabase_%'
                )
                LOOP
                    BEGIN
                        EXECUTE 'SELECT pg_drop_replication_slot(' || quote_literal(slot_name) || ');';
                        RAISE NOTICE 'Dropped replication slot: %', slot_name;
                    EXCEPTION WHEN OTHERS THEN
                        RAISE NOTICE 'Failed to drop replication slot %: %', slot_name, SQLERRM;
                    END;
                END LOOP;
            END;
            \$\$;
            "
            
            result=$(run_sql "$db" "$drop_replication_slots_sql")
            if [[ $? -ne 0 ]]; then
                echo -e "${YELLOW}Warning when dropping replication slots in $db: $result${NC}"
            else
                echo -e "${GREEN}Replication slots dropped in $db${NC}"
            fi
        else
            echo -e "${YELLOW}Database $db does not exist, skipping specific table reset...${NC}"
        fi
    done
    
    echo -e "${GREEN}Specific table reset completed.${NC}"
}

# Main reset function
reset_database() {
    echo -e "${YELLOW}Starting database reset process...${NC}"

    # Drop all extensions to avoid dependency issues
    drop_all_extensions
    
    # Drop all schemas
    drop_all_schemas
    
    # Drop specific tables, publications, and subscriptions
    reset_specific_tables
    
    # Drop all roles - this has to happen at the end, after all objects are removed
    drop_all_roles
    
    # If the role drop wasn't completely successful, recommend manual steps
    echo -e "${YELLOW}Note: If some roles couldn't be dropped, you might need superuser access${NC}"
    echo -e "${YELLOW}Try connecting as a PostgreSQL superuser (usually postgres) and run:${NC}"
    echo -e "  ${GREEN}DROP ROLE IF EXISTS anon, authenticated, service_role, supabase_admin, supabase_realtime_admin CASCADE;${NC}"

    # Reset each database
    for db in "${DATABASES[@]}"; do
        echo -e "${GREEN}Resetting database: $db${NC}"
        
        # Check if database exists
        if run_sql "postgres" "SELECT 1 FROM pg_database WHERE datname = '$db';" | grep -q "1"; then
            # Reset public schema
            echo -e "${GREEN}Resetting public schema in $db...${NC}"
            result=$(run_sql "$db" "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};")
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Failed to reset public schema in $db: $result${NC}"
                exit 1
            fi
            echo -e "${GREEN}Public schema reset successfully in $db.${NC}"

            # Install pgcrypto extension
            echo -e "${GREEN}Installing pgcrypto extension in $db...${NC}"
            result=$(run_sql "$db" "CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;")
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Failed to install pgcrypto in $db: $result${NC}"
                exit 1
            fi
            echo -e "${GREEN}pgcrypto extension installed successfully in $db.${NC}"

            # Create auth schema
            echo -e "${GREEN}Creating auth schema in $db...${NC}"
            local auth_setup_sql="
            CREATE SCHEMA IF NOT EXISTS auth;
            GRANT USAGE ON SCHEMA auth TO ${POSTGRES_USER};
            GRANT CREATE ON SCHEMA auth TO ${POSTGRES_USER};
            GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth TO ${POSTGRES_USER};
            ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${POSTGRES_USER};
            ALTER SCHEMA auth OWNER TO ${POSTGRES_USER};
            "
            result=$(run_sql "$db" "$auth_setup_sql")
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Failed to create auth schema in $db: $result${NC}"
                exit 1
            fi
            echo -e "${GREEN}Auth schema created successfully in $db.${NC}"
        else
            echo -e "${YELLOW}Database $db does not exist, skipping...${NC}"
        fi
    done

    # Final check to make sure all roles are gone
    local role_check_sql="SELECT rolname FROM pg_roles WHERE rolname IN ($(printf "'%s'," "${SUPABASE_ROLES[@]}" | sed 's/,$//'));"
    result=$(run_sql "postgres" "$role_check_sql")
    
    if [[ -z "$result" || "$result" == " rolname\n-------\n(0 rows)" ]]; then
        echo -e "${GREEN}All Supabase roles have been successfully removed.${NC}"
    else
        echo -e "${YELLOW}Some roles might still exist in the database:${NC}"
        echo -e "$result"
        echo -e "${YELLOW}You may need to manually remove them or contact your database administrator.${NC}"
    fi

    echo -e "${GREEN}Database reset completed successfully! Supabase artifacts have been removed.${NC}"
}

# Function to list all current roles, schemas, extensions, and event triggers
list_database_objects() {
    echo -e "${GREEN}Listing all roles in the database...${NC}"
    result=$(run_sql "postgres" "SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin FROM pg_roles;")
    echo -e "$result"
    
    echo -e "\n${GREEN}Listing all schemas...${NC}"
    result=$(run_sql "postgres" "SELECT nspname FROM pg_namespace WHERE nspname NOT LIKE 'pg_%' AND nspname != 'information_schema';")
    echo -e "$result"
    
    echo -e "\n${GREEN}Listing all extensions...${NC}"
    result=$(run_sql "postgres" "SELECT extname, extversion FROM pg_extension;")
    echo -e "$result"
    
    echo -e "\n${GREEN}Listing all event triggers...${NC}"
    result=$(run_sql "postgres" "SELECT evtname, evtevent FROM pg_event_trigger;")
    echo -e "$result"
}

# Execution flow
main() {
    # Validate connection parameters
    if [[ -z "$POSTGRES_HOST" || -z "$POSTGRES_PASSWORD" || -z "$POSTGRES_USER" ]]; then
        echo -e "${RED}Error: Missing required connection parameters.${NC}"
        echo "Please set POSTGRES_HOST, POSTGRES_USER, and POSTGRES_PASSWORD in .env or environment"
        exit 1
    fi

    # Check if we just want to list objects
    if [[ "$1" == "list-objects" ]]; then
        list_database_objects
        exit 0
    fi

    # Confirm before proceeding
    if confirm_action; then
        reset_database
    else
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
}

# Run the main function with any arguments
main "$@"