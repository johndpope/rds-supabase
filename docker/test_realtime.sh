#!/bin/bash

source /home/ec2-user/mly-supabase/docker/.env
source /etc/profile.d/mly_env.sh # get the Postgres credentials

TENANT_ID="realtime-dev2"
REALTIME_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' supabase-realtime)
JWT_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc0MTgyOTg4OCwiZXhwIjoxNzczMzY1ODg4LCJhdWQiOiJyZWFsdGltZSIsInN1YiI6ImFkbWluIn0.lIFw2uY2qh5eixaXgF2VdcT_HvfHehRnocLexznw7q0"

echo "========== Checking Realtime Container Status =========="
docker ps -a | grep supabase-realtime || echo "Realtime container not found"

echo "========== Recent Realtime Container Logs =========="
docker logs supabase-realtime --tail 20 2>/dev/null || echo "No logs available"

echo "========== Testing Tenant Database Configuration =========="
psql "postgres://supabase_admin:your-super-secret-and-long-postgres-password@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" << EOF
-- Check if _realtime schema exists
SELECT schema_name FROM information_schema.schemata WHERE schema_name = '_realtime';

-- Check if tenant exists
SELECT id, name, external_id, postgres_cdc_default FROM _realtime.tenants WHERE external_id = '${TENANT_ID}';

-- Check if extension exists for tenant
SELECT id, type, tenant_external_id FROM _realtime.extensions WHERE tenant_external_id = '${TENANT_ID}';

-- Check PostgreSQL replication settings
SHOW wal_level;
SHOW max_replication_slots;
SHOW max_wal_senders;

-- Check all publications and their owners
SELECT pubname, pg_roles.rolname AS owner, puballtables
FROM pg_publication
JOIN pg_roles ON pg_publication.pubowner = pg_roles.oid;

-- Check tables in publications
SELECT pubname, schemaname, tablename, attnames, rowfilter
FROM pg_publication_tables;

-- Check replication slots
SELECT slot_name, plugin, slot_type, active, restart_lsn, confirmed_flush_lsn
FROM pg_replication_slots;

-- Test basic connectivity
SELECT current_user, current_database(), now();
EOF

echo "========== Testing Tenant API Health =========="
curl -v -H "Authorization: Bearer ${JWT_TOKEN}" \
  http://${REALTIME_IP}:4000/api/tenants/${TENANT_ID}/health

echo -e "\n========== Testing WebSocket Communication =========="
psql "postgres://supabase_admin:your-super-secret-and-long-postgres-password@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" << EOF
CREATE TABLE IF NOT EXISTS public.realtime_test (
  id SERIAL PRIMARY KEY,
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'realtime_test'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.realtime_test;
  END IF;
END;
\$\$;
EOF

echo "Testing WebSocket connection (requires websocat)..."
if ! command -v websocat &> /dev/null; then
    echo "websocat not found. Install with:"
    echo "  sudo curl -L -o /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl"
    echo "  sudo chmod +x /usr/local/bin/websocat"
    echo "Skipping WebSocket test."
else
    # Use a JWT token matching your tenant's jwt_secret
    TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NzMzNjU4ODgsInJvbGUiOiJwb3N0Z3JlcyJ9.tz_XJ89gd6bN8MBpCl7afvPrZiBH6RB65iA1FadPT3Y"
    
    echo "Connecting to WebSocket and subscribing to test table changes..."
    timeout 10s websocat "ws://${TENANT_ID}.${REALTIME_IP}:4000/socket/websocket?token=${TOKEN}" -n 2>&1 | tee /tmp/ws_output.log &
    WS_PID=$!
    sleep 2
    
    echo "Inserting test data into realtime_test table..."
    psql "postgres://supabase_admin:your-super-secret-and-long-postgres-password@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -c "INSERT INTO public.realtime_test (message) VALUES ('Testing realtime at $(date)');"
    
    sleep 5
    
    if grep -q "INSERT" /tmp/ws_output.log; then
        echo "SUCCESS: Received INSERT event over WebSocket"
    else
        echo "WARNING: No INSERT event detected in WebSocket output"
        echo "WebSocket log contents:"
        cat /tmp/ws_output.log
    fi
    
    kill $WS_PID 2>/dev/null || true
    rm -f /tmp/ws_output.log
fi

echo "========== Test Complete =========="