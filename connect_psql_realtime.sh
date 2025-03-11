
psql -d "postgresql://supabase_admin:your-super-secret-and-long-postgres-password@$POSTGRES_HOST:$POSTGRES_PORT/postgres" -c "\dn+ realtime"