


docker stop $(docker ps -q)
docker rm $(docker ps -a -q)
docker rmi $(docker images -q) 2>/dev/null || true
docker system prune -a --volumes
docker volume rm supabase_pg-data
docker volume rm logflare_pg-data

docker-compose build --no-cache auth
docker-compose up -d --force-recreate auth


