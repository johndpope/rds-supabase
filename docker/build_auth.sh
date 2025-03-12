


echo "👹  Have to stop docker and all the containers to free up RAM"

docker-compose stop

docker stop supabase-auth
docker rm supabase-auth

docker images | grep auth | awk '{print $3}' | xargs docker rmi 2>/dev/null || true


docker-compose build --no-cache auth
docker-compose up -d auth