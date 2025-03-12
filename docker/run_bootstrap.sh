#!/bin/bash

# Exit on error
set -e

# Check if script is being run with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges."
    echo "Please run: sudo $0"
    exit 1
fi

# Ensure log directory exists with proper permissions
mkdir -p /var/log
chmod 755 /var/log
touch /var/log/bootstrap_errors.log /var/log/clone_mly_supabase.log
chmod 644 /var/log/bootstrap_errors.log /var/log/clone_mly_supabase.log
chown ec2-user:ec2-user /var/log/bootstrap_errors.log /var/log/clone_mly_supabase.log

# Source environment variables
cd /home/ec2-user/mly-supabase/docker


# Retrieve mlypg_admin password from Secrets Manager if not set
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(aws secretsmanager get-secret-value --secret-id mly_pg_database_creds --query SecretString --output text | jq -r '.password')
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo "Error: POSTGRES_PASSWORD not set and failed to retrieve from Secrets Manager" >&2 | tee -a /var/log/clone_mly_supabase.log
        exit 1
    fi
fi

# Set default values for JWT variables
JWT_SECRET="${JWT_SECRET:-your-super-secret-jwt-token-with-at-least-32-characters-long}"
JWT_EXP="${JWT_EXP:-3600}"  # Default to 3600 seconds (1 hour) if not set

# Define connection parameters
POSTGRES_DB="postgres"
PG_CONN="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT"

# Validate required variables
if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$JWT_SECRET" ]; then
    echo "Error: Missing required environment variables (POSTGRES_PASSWORD or JWT_SECRET)" >&2 | tee -a /var/log/clone_mly_supabase.log
    exit 1
fi

# Check if rds_bootstrap.sql exists
if [ ! -f "./rds_bootstrap.sql" ]; then
    echo "Error: rds_bootstrap.sql not found in the current directory" >&2 | tee -a /var/log/clone_mly_supabase.log
    exit 1
fi

# Echo the psql command (mask sensitive data for security)
# set +x
echo "Executing psql command: psql -d \"${PG_CONN}/${POSTGRES_DB}\" -v postgres_password=\"[MASKED]\" -v jwt_secret=\"[MASKED]\" -v jwt_exp=\"${JWT_EXP}\" -f \"/home/ec2-user/mly-supabase/rds_bootstrap.sql\" 2>/var/log/bootstrap_errors.log" | tee -a /var/log/clone_mly_supabase.log
# set -x

# Execute the SQL script with psql and log output
echo "Executing database bootstrap..." | tee -a /var/log/clone_mly_supabase.log
psql -d "$PG_CONN/$POSTGRES_DB" \
  -v postgres_password="your-super-secret-and-long-postgres-password" \
  -v jwt_secret="$JWT_SECRET" \
  -v jwt_exp="$JWT_EXP" \
  -v realtime_db="$POSTGRES_DB" \
  -f "./rds_bootstrap.sql" \
  2>/var/log/bootstrap_errors.log | tee /var/log/bootstrap.log

# Check the exit status and log results
if [ $? -ne 0 ]; then
    echo "❌ Database bootstrap failed. Check /var/log/bootstrap_errors.log and /var/log/bootstrap.log for details" >&2 | tee -a /var/log/clone_mly_supabase.log
    exit 1
fi
echo "✅ Database bootstrap completed successfully" | tee -a /var/log/clone_mly_supabase.log

# Test connection as supabase_realtime_admin
echo "Testing connection as supabase_realtime_admin..." | tee -a /var/log/clone_mly_supabase.log
if psql -d "postgresql://supabase_realtime_admin:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/postgres?sslmode=require" -c "\q" 2>/var/log/supabase_realtime_admin_test_errors.log; then
    echo "✅ Connection test for supabase_realtime_admin succeeded" | tee -a /var/log/clone_mly_supabase.log
else
    echo "❌  Connection test for supabase_realtime_admin failed. Check /var/log/supabase_realtime_admin_test_errors.log for details" >&2 | tee -a /var/log/clone_mly_supabase.log
    # Attempt to troubleshoot supabase_realtime_admin creation
    echo "Attempting to troubleshoot supabase_realtime_admin creation..." | tee -a /var/log/clone_mly_supabase.log
    if ! psql -d "$PG_CONN/$POSTGRES_DB" -t -c "SELECT 1 FROM pg_roles WHERE rolname = 'supabase_realtime_admin';" | grep -q 1; then
        echo "supabase_realtime_admin does not exist. Creating with LOGIN..." | tee -a /var/log/clone_mly_supabase.log
        psql -d "$PG_CONN/$POSTGRES_DB" -c "CREATE ROLE supabase_realtime_admin WITH NOINHERIT LOGIN PASSWORD '$POSTGRES_PASSWORD' NOREPLICATION;" 2>>/var/log/supabase_realtime_admin_test_errors.log
        psql -d "$PG_CONN/$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO supabase_realtime_admin;" 2>>/var/log/supabase_realtime_admin_test_errors.log
    fi
    # Re-test connection
    if psql -d "postgresql://supabase_realtime_admin:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/postgres?sslmode=require" -c "\q" 2>/var/log/supabase_realtime_admin_test_errors.log; then
        echo "✅ Manual creation and connection test for supabase_realtime_admin succeeded" | tee -a /var/log/clone_mly_supabase.log
    else
        echo "❌  Manual creation and connection test for supabase_realtime_admin failed. Check /var/log/supabase_realtime_admin_test_errors.log" >&2 | tee -a /var/log/clone_mly_supabase.log
        exit 1
    fi
fi

# Verify supabase_realtime_admin ownership in realtime schema
echo "Verifying supabase_realtime_admin ownership in realtime schema..." | tee -a /var/log/clone_mly_supabase.log

# Check schema ownership
SCHEMA_OWNER=$(psql -d "$PG_CONN/$POSTGRES_DB" -t -c "SELECT nspowner::regrole FROM pg_namespace WHERE nspname = 'realtime';" | tr -d '[:space:]')
if [ "$SCHEMA_OWNER" = "supabase_realtime_admin" ]; then
    echo "✅ Schema 'realtime' is owned by supabase_realtime_admin" | tee -a /var/log/clone_mly_supabase.log
else
    echo "Warning: Schema 'realtime' is owned by $SCHEMA_OWNER, expected supabase_realtime_admin" >&2 | tee -a /var/log/clone_mly_supabase.log
fi

# Check table ownership
TABLES="messages users broadcasts channels presences"
for TABLE in $TABLES; do
    OWNER=$(psql -d "$PG_CONN/$POSTGRES_DB" -t -c "SELECT tableowner FROM pg_tables WHERE schemaname = 'realtime' AND tablename = '$TABLE';" | tr -d '[:space:]')
    if [ "$OWNER" = "supabase_realtime_admin" ]; then
        echo "✅ Table 'realtime.$TABLE' is owned by supabase_realtime_admin" | tee -a /var/log/clone_mly_supabase.log
    elif [ -z "$OWNER" ]; then
        echo "Warning: Table 'realtime.$TABLE' does not exist" >&2 | tee -a /var/log/clone_mly_supabase.log
    else
        echo "Warning: Table 'realtime.$TABLE' is owned by $OWNER, expected supabase_realtime_admin" >&2 | tee -a /var/log/clone_mly_supabase.log
    fi
done

# Check sequence ownership
SEQUENCES="messages_id_seq users_id_seq broadcasts_id_seq channels_id_seq presences_id_seq"
for SEQ in $SEQUENCES; do
    OWNER=$(psql -d "$PG_CONN/$POSTGRES_DB" -t -c "SELECT sequenceowner FROM pg_sequences WHERE schemaname = 'realtime' AND sequencename = '$SEQ';" | tr -d '[:space:]')
    if [ "$OWNER" = "supabase_realtime_admin" ]; then
        echo "✅ Sequence 'realtime.$SEQ' is owned by supabase_realtime_admin" | tee -a /var/log/clone_mly_supabase.log
    elif [ -z "$OWNER" ]; then
        echo "Warning: Sequence 'realtime.$SEQ' does not exist" >&2 | tee -a /var/log/clone_mly_supabase.log
    else
        echo "Warning: Sequence 'realtime.$SEQ' is owned by $OWNER, expected supabase_realtime_admin" >&2 | tee -a /var/log/clone_mly_supabase.log
    fi
done

# Verify schemas in postgres database
echo "Verifying schemas in postgres database:" | tee -a /var/log/clone_mly_supabase.log
psql -d "$PG_CONN/postgres" -c "\dn" | tee -a /var/log/clone_mly_supabase.log

# Verify schemas in _supabase database if it exists
if psql -d "$PG_CONN/$POSTGRES_DB" -t -c "SELECT 1 FROM pg_database WHERE datname = '_supabase';" | grep -q 1; then
    echo "✅ Verifying schemas in _supabase database:" | tee -a /var/log/clone_mly_supabase.log
    psql -d "$PG_CONN/_supabase" -c "\dn" | tee -a /var/log/clone_mly_supabase.log
else
    echo "❌  Warning: _supabase database does not exist, skipping verification" | tee -a /var/log/clone_mly_supabase.log
fi

# Determine which user to use for analytics
HAS_SUPERUSER=$(psql -d "$PG_CONN/$POSTGRES_DB" -t -c "SELECT usesuper FROM pg_user WHERE usename = current_user;" | tr -d '[:space:]')
SUPABASE_ADMIN_EXISTS=$(psql -d "$PG_CONN/$POSTGRES_DB" -t -c "SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin';" | tr -d '[:space:]')

DB_USER_FOR_ANALYTICS="$POSTGRES_USER"
if [ "$HAS_SUPERUSER" = "t" ] && [ "$SUPABASE_ADMIN_EXISTS" = "1" ]; then
    DB_USER_FOR_ANALYTICS="supabase_admin"
    echo "Using supabase_admin for analytics container" | tee -a /var/log/clone_mly_supabase.log
else
    echo "Using $POSTGRES_USER for analytics container (current user lacks SUPERUSER or supabase_admin doesn't exist)" | tee -a /var/log/clone_mly_supabase.log
fi

echo "Bootstrap completed successfully" | tee -a /var/log/clone_mly_supabase.log

./clear_logs.sh
