#!/bin/bash

# Set tenant variables
TENANT_NAME="realtime-dev2"
TENANT_EXTERNAL_ID="realtime-dev2"
DB_PORT="5432"
REGION="ap-southeast-2"
POSTGRES_CDC_DEFAULT="postgres_cdc_rls"

# Use the correct PostgreSQL endpoint and database
DB_HOST="BLABLABLA.rds.amazonaws.com"
DB_NAME="postgres"
DB_USER="supabase_admin"
DB_PASS="your-super-secret-and-long-postgres-password"

JWT_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc0MTgyOTg4OCwiZXhwIjoxNzczMzY1ODg4LCJhdWQiOiJyZWFsdGltZSIsInN1YiI6ImFkbWluIn0.lIFw2uY2qh5eixaXgF2VdcT_HvfHehRnocLexznw7q0"

# Get the IP address of the supabase-realtime container
REALTIME_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' supabase-realtime)

# Check if we got an IP address
if [ -z "$REALTIME_IP" ]; then
  echo "Error: Could not determine IP address of supabase-realtime container"
  exit 1
fi

echo "Using Realtime container IP: $REALTIME_IP"
echo "Registering tenant: $TENANT_NAME (external_id: $TENANT_EXTERNAL_ID)"
echo "Using database: $DB_NAME on $DB_HOST"

# Make the API request with corrected database settings
curl -v -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -d "{
    \"tenant\": {
      \"name\": \"$TENANT_NAME\",
      \"external_id\": \"$TENANT_EXTERNAL_ID\",
      \"jwt_secret\": \"your-super-secret-jwt-token-with-at-least-32-characters-long\",
      \"postgres_cdc_default\": \"$POSTGRES_CDC_DEFAULT\",
      \"extensions\": [
        {
          \"type\": \"postgres_cdc_rls\",
          \"settings\": {
            \"db_name\": \"$DB_NAME\",
            \"db_host\": \"$DB_HOST\",
            \"db_user\": \"$DB_USER\",
            \"db_password\": \"$DB_PASS\",
            \"db_port\": \"$DB_PORT\",
            \"region\": \"$REGION\",
            \"poll_interval_ms\": 100,
            \"poll_max_record_bytes\": 1048576,
            \"publication\": \"supabase_realtime\",
            \"slot_name\": \"supabase_realtime_replication_slot\"
          }
        }
      ]
    }
  }" \
  http://$REALTIME_IP:4000/api/tenants

# Check the response status
if [ $? -eq 0 ]; then
  echo "Tenant registration request completed successfully."
else
  echo "Error: Tenant registration request failed."
  exit 1
fi