#!/bin/bash

# Exit on error
set -e



# Validate required variables
if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_PORT" ] || [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: Missing required environment variables (POSTGRES_HOST, POSTGRES_PORT, or POSTGRES_PASSWORD)" >&2 
    exit 1
fi

# Prompt user for RDS user
echo "Select RDS user:"
echo "1) $POSTGRES_USER (e.g., rds root admin)"
echo "2) supabase_admin"
read -p "Enter choice (1 or 2): " user_choice

case $user_choice in
    1)
        RDS_USER="$POSTGRES_USER"
        RDS_PASSWORD="$POSTGRES_PASSWORD"
        echo "Using RDS user: $RDS_USER" 
        ;;
    2)
        RDS_USER="supabase_admin"
        RDS_PASSWORD="your-super-secret-and-long-postgres-password"
        echo "Using RDS user: $RDS_USER" 
        ;;
    *)
        echo "Invalid choice. Defaulting to $POSTGRES_USER" >&2 
        RDS_USER="$POSTGRES_USER"
        RDS_PASSWORD="$POSTGRES_PASSWORD"
        ;;
esac

# Prompt user for database
echo "Select database:"
echo "1) ${POSTGRES_DB} (e.g., mailopoly)"
echo "2) postgres"
read -p "Enter choice (1 or 2): " db_choice

case $db_choice in
    1)
        DB_NAME="${POSTGRES_DB}"
        echo "Using database: $DB_NAME" 
        ;;
    2)
        DB_NAME="postgres"
        echo "Using database: $DB_NAME" 
        ;;
    *)
        echo "Invalid choice. Defaulting to ${POSTGRES_DB}" >&2 
        DB_NAME="${POSTGRES_DB}"
        ;;
esac

# Construct connection string
PG_CONN="postgres://$RDS_USER:$RDS_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$DB_NAME"

# Execute psql command
echo "Executing psql command: psql -d \"$PG_CONN\"..." 
psql -d "$PG_CONN" 

# Verify completion
if [ $? -eq 0 ]; then
    echo "✅ psql command executed successfully for $RDS_USER on $DB_NAME" 
else
    echo "❌ Failed to execute psql command. Check /var/log/psql_commands.log for details" >&2 
    exit 1
fi