

docker stop supabase-realtime
docker rm supabase-realtime

docker images | grep realtime | awk '{print $3}' | xargs docker rmi 2>/dev/null || true


# Function to check AWS account
check_aws_account() {
    # Get current AWS account ID
    CURRENT_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Unable to get AWS account. Please ensure you're logged in to AWS CLI (aws configure sso) "
        exit 1
    fi
    echo "$CURRENT_ACCOUNT"
}


# Check AWS account
ACCOUNT_ID=$(check_aws_account)

aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.ap-southeast-2.amazonaws.com
docker-compose build --no-cache --memory=4g realtime
docker-compose up -d realtime


# DOCKER_BUILDKIT=1 docker build \
#   --memory=4g \
#   --memory-swap=8g \
#   --build-arg DOCKER_BUILDKIT_MEMORY=4g \
#   -t "supabase/realtime" /home/ec2-user/mly-supabase/docker/realtime/Dockerfile