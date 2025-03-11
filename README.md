# Supabase Docker
WARNING - DO NOT USE THIS ON PRODUCTION DATABASE 
there are scripts here that may break EVERYTHING


the gist
I boot up the supabase docker containers - this runs all the migration scripts succesfully across containers. I run an export 

```shell
docker exec -t supabase-db pg_dump -U postgres --schema-only --no-owner --no-privileges postgres > schema.sql


docker exec -t supabase-db pg_dump -U postgres --data-only --no-owner --no-privileges postgres > data.sql

docker exec supabase-db pg_dumpall -U postgres --roles-only > roles.sql
```

N.B. - the vanilla postgres db schema is 170kb
I do some processing and end up with updated rds_schema.sql ~ 20kb
so we lost a bunch of extensions / webhooks (pg_net dependent)  and stuff..

# we import this diluted dump
```shell
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -f postgres_users.sql
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -f rds_schema.sql
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/postgres" -f data.sql

```


clone these into this folder 

```shell
gh repo clone johndpope/auth
gh repo clone johndpope/realtime


docker-compose up
```



