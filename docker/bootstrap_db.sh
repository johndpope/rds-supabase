#!/bin/bash

# source /home/ec2-user/mly-supabase/docker/.env
# source /etc/profile.d/mly_env.sh # get the Postgres credentials

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# RDS Connection Details
POSTGRES_HOST="${POSTGRES_HOST:-your-rds-endpoint}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-mailopolyapp}"
POSTGRES_USER="${POSTGRES_USER:-your-username}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-your-password}"

# Connection string
CONN_STRING="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

# Array of required extensions
EXTENSIONS=(
    "pg_net"
    "pgcrypto"
    "uuid-ossp"
)

# Array of initial setup scripts
SETUP_SCRIPTS=(
    "./volumes/db/auth_schema_setup.sql" 
    "./volumes/db/_aws_pgjwt.sql"
    "./volumes/db/_supabase.sql"
    "./volumes/db/realtime.sql"
    "./volumes/db/webhooks.sql"
    "./volumes/db/roles.sql"
    "./volumes/db/jwt.sql"
    "./volumes/db/logs.sql"
    "./volumes/db/pooler.sql"
)

# Array of Supabase Auth migration scripts (sorted by version)

# Function to install extensions
install_extensions() {
    echo -e "${YELLOW}Installing required PostgreSQL extensions...${NC}"
    
    for ext in "${EXTENSIONS[@]}"; do
        echo -e "${GREEN}Attempting to install extension: ${ext}${NC}"
        
        # Try to create extension
        output=$(psql "$CONN_STRING" -c "CREATE EXTENSION IF NOT EXISTS \"$ext\"" 2>&1)
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Extension ${ext} installed successfully${NC}"
        else
            echo -e "${RED}× Error installing extension ${ext}:${NC}"
            echo "$output"
            
            # Special handling for pg_net which might require more steps
            if [ "$ext" == "pg_net" ]; then
                echo -e "${YELLOW}WARNING: pg_net extension may require special handling on RDS${NC}"
                echo "You might need to contact AWS RDS support to install this extension."
            fi
        fi
    done
}

# Function to run each script
run_script() {
    local script="$1"
    echo -e "${GREEN}Executing $script...${NC}"
    
    # Capture both stdout and stderr
    output=$(psql "$CONN_STRING" -f "$script" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $script executed successfully${NC}"
        return 0
    else
        echo -e "${RED}× Error executing $script:${NC}"
        echo "$output"
        return 1
    fi
}

# Function to run all scripts in an array
run_scripts() {
    local scripts=("${!1}")
    local error_occurred=false

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if ! run_script "$script"; then
                error_occurred=true
                # Uncomment next line to stop on first error
                # break
            fi
        else
            echo -e "${YELLOW}Warning: Script $script not found${NC}"
        fi
    done

    if [ "$error_occurred" = true ]; then
        echo -e "${RED}Some scripts failed to execute${NC}"
        return 1
    fi
}

# Main function
main() {
    # Validate connection parameters
    if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_USER" ]; then
        echo -e "${RED}Error: Missing required connection parameters.${NC}"
        echo "Please set POSTGRES_HOST, POSTGRES_USER, and POSTGRES_PASSWORD"
        exit 1
    fi

    # Install extensions first
    install_extensions

    # Run initial setup scripts
    echo -e "${YELLOW}Running initial setup scripts...${NC}"
    run_scripts SETUP_SCRIPTS[@] || exit 1


    echo -e "${GREEN}All initialization and migration scripts completed successfully!${NC}"
}

# Call the main function
main


echo "Skipping migration skips that break stuff with missing extentions" | tee -a /var/log/clone_mly_supabase.log
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -f postgres_users.sql | tee -a /var/log/clone_mly_supabase.log
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -f rds_schema.sql  | tee -a /var/log/clone_mly_supabase.log
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -f data.sql  | tee -a /var/log/clone_mly_supabase.log


# HOTFIX
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -c "GRANT USAGE, CREATE ON SCHEMA public TO supabase_admin;"
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres"  -c "ALTER PUBLICATION supabase_realtime OWNER TO supabase_admin;"
