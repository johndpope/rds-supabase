#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source environment variables if available
if [ -f /home/ec2-user/mly-supabase/docker/.env ]; then
    source /home/ec2-user/mly-supabase/docker/.env
fi

if [ -f /etc/profile.d/mly_env.sh ]; then
    source /etc/profile.d/mly_env.sh
fi

# Define RDS instance identifier from POSTGRES_HOST
# Extract the first part of the hostname (before the first dot)
if [ -n "$POSTGRES_HOST" ]; then
    DB_INSTANCE_IDENTIFIER=$(echo "$POSTGRES_HOST" | cut -d'.' -f1)
else
    DB_INSTANCE_IDENTIFIER="mly-pg-live-prod"
fi

# Default values (using your system variables)
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
SNAPSHOT_PREFIX="${SNAPSHOT_PREFIX:-mly-pg-$(date +%Y%m%d)}"

# Function to check if AWS CLI is installed and AWS connectivity
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI is not installed.${NC}"
        echo -e "Please install it using: pip install awscli"
        exit 1
    fi
    
    # Test AWS connectivity
    echo -e "${BLUE}Testing connectivity to AWS...${NC}"
    
    # Try a simple AWS command with a short timeout
    if ! timeout 5 aws sts get-caller-identity --region "${AWS_REGION}" &>/dev/null; then
        echo -e "${RED}Error: Cannot connect to AWS. Connectivity issues detected.${NC}"
        echo -e "Possible causes:"
        echo -e " - Network connectivity issues"
        echo -e " - AWS credentials not configured or expired"
        echo -e " - VPC/security group restrictions"
        echo -e " - AWS region '${AWS_REGION}' may be incorrect"
        
        # Check AWS credentials
        if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            echo -e "${YELLOW}No AWS credentials found in environment variables.${NC}"
            
            # Check for credentials file
            if [ ! -f ~/.aws/credentials ] && [ ! -f ~/.aws/config ]; then
                echo -e "${YELLOW}No AWS credentials file found.${NC}"
                echo -e "Run 'aws configure' to set up your credentials."
            else
                echo -e "${YELLOW}AWS credentials file exists, but may be invalid or expired.${NC}"
                echo -e "Check your credentials with 'aws sts get-caller-identity'"
            fi
        fi
        
        echo -e "${YELLOW}Would you like to continue anyway? (y/N):${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}AWS connectivity test successful.${NC}"
    fi
}

# Function to create a snapshot with progress monitoring
create_snapshot() {
    local snapshot_name="$1"
    local async="$2"
    
    if [ -z "$snapshot_name" ]; then
        # Generate a name with timestamp if none provided
        snapshot_name="${SNAPSHOT_PREFIX}-$(date +%Y-%m-%d-%H-%M-%S)"
    fi
    
    echo -e "${YELLOW}Creating snapshot '${snapshot_name}' for RDS instance '${DB_INSTANCE_IDENTIFIER}'...${NC}"
    echo -e "${BLUE}Executing AWS RDS command with timeout of 20 seconds...${NC}"
    
    # Use timeout to prevent hanging indefinitely
    timeout 20 aws rds create-db-snapshot \
        --region "${AWS_REGION}" \
        --db-instance-identifier "${DB_INSTANCE_IDENTIFIER}" \
        --db-snapshot-identifier "${snapshot_name}" \
        --tags Key=Creator,Value=CLI Key=Environment,Value=prod Key=Stack,Value="${stack_name}"
    
    # Check the exit code
    error_code=$?
    if [ $error_code -eq 0 ]; then
        echo -e "${GREEN}Successfully initiated snapshot creation.${NC}"
        echo -e "${BLUE}Snapshot name: ${snapshot_name}${NC}"
        
        # If async flag is not set, monitor the progress
        if [ "$async" != "async" ]; then
            echo -e "${YELLOW}Monitoring snapshot progress (Press Ctrl+C to stop monitoring)...${NC}"
            monitor_snapshot_progress "$snapshot_name"
        else
            echo -e "${YELLOW}Snapshot creation is running in the background. Use the following command to check status:${NC}"
            echo -e "${BLUE}$0 status ${snapshot_name}${NC}"
        fi
    else
        if [ $error_code -eq 124 ]; then
            echo -e "${RED}Error: Command timed out after 20 seconds.${NC}"
            echo -e "${YELLOW}This usually indicates network connectivity issues.${NC}"
            echo -e "Try running with a longer timeout:"
            echo -e "   timeout 60 aws rds create-db-snapshot --region \"${AWS_REGION}\" --db-instance-identifier \"${DB_INSTANCE_IDENTIFIER}\" --db-snapshot-identifier \"${snapshot_name}\""
        else
            echo -e "${RED}Error: AWS RDS command failed with exit code $error_code.${NC}"
            echo -e "${YELLOW}Troubleshooting steps:${NC}"
            echo -e "1. Check VPC endpoint configuration"
            echo -e "2. Verify security group rules"
            echo -e "3. Confirm AWS credentials haven't expired"
            echo -e "4. Try running command with --debug flag for detailed error info:"
            echo -e "   aws rds create-db-snapshot --region \"${AWS_REGION}\" --db-instance-identifier \"${DB_INSTANCE_IDENTIFIER}\" --db-snapshot-identifier \"${snapshot_name}\" --debug"
        fi
        exit 1
    fi
}

# Function to monitor snapshot progress
monitor_snapshot_progress() {
    local snapshot_id="$1"
    local status=""
    local percent=""
    local spinner=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
    local i=0
    
    echo -e "${YELLOW}Monitoring snapshot creation progress...${NC}"
    
    while true; do
        # Get current status
        snapshot_info=$(aws rds describe-db-snapshots \
            --region "${AWS_REGION}" \
            --db-snapshot-identifier "$snapshot_id" --query "DBSnapshots[0].[Status,PercentProgress]" --output text 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error retrieving snapshot status. Snapshot might not exist or might have been deleted.${NC}"
            return 1
        fi
        
        status=$(echo "$snapshot_info" | awk '{print $1}')
        percent=$(echo "$snapshot_info" | awk '{print $2}')
        
        # Clear the line
        echo -ne "\r\033[K"
        
        # Print current status with spinner
        echo -ne "${spinner[$i]} Status: ${status} | Progress: ${percent}% complete"
        
        # Update spinner index
        i=$(( (i+1) % ${#spinner[@]} ))
        
        # If snapshot is available, we're done
        if [ "$status" == "available" ]; then
            echo -e "\r\033[K${GREEN}Snapshot creation completed successfully!${NC}"
            return 0
        elif [ "$status" == "failed" ]; then
            echo -e "\r\033[K${RED}Snapshot creation failed.${NC}"
            return 1
        fi
        
        sleep 5
    done
}

# Function to check snapshot status
check_snapshot_status() {
    local snapshot_id="$1"
    
    if [ -z "$snapshot_id" ]; then
        echo -e "${RED}Error: No snapshot ID provided.${NC}"
        echo "Usage: $0 status <snapshot-id>"
        exit 1
    fi
    
    echo -e "${YELLOW}Checking status of snapshot '${snapshot_id}'...${NC}"
    
    monitor_snapshot_progress "$snapshot_id"
}

# Function to list snapshots
list_snapshots() {
    local days="$1"
    local filter=""
    
    echo -e "${YELLOW}Listing RDS snapshots for instance '${DB_INSTANCE_IDENTIFIER}'...${NC}"
    
    if [ -n "$days" ] && [ "$days" -gt 0 ]; then
        echo -e "${BLUE}Showing snapshots from the last ${days} days${NC}"
        # Calculate the date N days ago
        local start_time=$(date -d "-${days} days" +%Y-%m-%dT%H:%M:%S)
        filter="--start-time ${start_time}"
    fi
    
    # Get the snapshots in JSON format
    local snapshots=$(aws rds describe-db-snapshots \
        --region "${AWS_REGION}" \
        --db-instance-identifier "${DB_INSTANCE_IDENTIFIER}" \
        $filter)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to retrieve snapshots.${NC}"
        exit 1
    fi
    
    # Format the output in a table
    echo -e "${GREEN}===== Available Snapshots =====${NC}"
    echo -e "${BLUE}SNAPSHOT NAME | STATUS | CREATION TIME | TYPE | SIZE (GB) | PROGRESS${NC}"
    echo "------------------------------------------------------"
    
    # Parse JSON output to create a formatted table
    echo "$snapshots" | jq -r '.DBSnapshots[] | "\(.DBSnapshotIdentifier) | \(.Status) | \(.SnapshotCreateTime) | \(.SnapshotType) | \(.AllocatedStorage) | \(.PercentProgress)%"' | \
    while read -r line; do
        echo -e "$line" | sed 's/ | /  |  /g'
    done
    
    echo -e "${GREEN}===== End of List =====${NC}"
}

# Function to restore from a snapshot
restore_from_snapshot() {
    local snapshot_id="$1"
    local new_instance_id="$2"
    local async="$3"
    
    if [ -z "$snapshot_id" ]; then
        echo -e "${RED}Error: No snapshot ID provided.${NC}"
        echo "Usage: $0 restore <snapshot-id> <new-instance-id> [async]"
        exit 1
    fi
    
    if [ -z "$new_instance_id" ]; then
        echo -e "${RED}Error: No target instance ID provided.${NC}"
        echo "Usage: $0 restore <snapshot-id> <new-instance-id> [async]"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring from snapshot '${snapshot_id}' to new instance '${new_instance_id}'...${NC}"
    echo -e "${RED}WARNING: This operation will create a new database instance. It may incur additional costs.${NC}"
    
    read -p "Are you sure you want to proceed? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Restore operation cancelled.${NC}"
        exit 0
    fi
    
    aws rds restore-db-instance-from-db-snapshot \
        --region "${AWS_REGION}" \
        --db-instance-identifier "${new_instance_id}" \
        --db-snapshot-identifier "${snapshot_id}" \
        --publicly-accessible \
        --tags Key=RestoreFrom,Value="${snapshot_id}" Key=Environment,Value=prod Key=Stack,Value="${stack_name}"
    
    error_code=$?
    if [ $error_code -eq 0 ]; then
        echo -e "${GREEN}Successfully initiated database restore.${NC}"
        
        # If async flag is not set, monitor the progress
        if [ "$async" != "async" ]; then
            echo -e "${YELLOW}Monitoring restore progress (Press Ctrl+C to stop monitoring)...${NC}"
            monitor_restore_progress "$new_instance_id"
        else
            echo -e "${YELLOW}Restore is running in the background. Use the following command to check status:${NC}"
            echo -e "${BLUE}$0 instance-status ${new_instance_id}${NC}"
        fi
    else
        echo -e "${RED}Failed to restore database from snapshot. Error code: $error_code${NC}"
        exit 1
    fi
}

# Function to monitor instance creation/restore progress
monitor_restore_progress() {
    local instance_id="$1"
    local status=""
    local spinner=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
    local i=0
    
    echo -e "${YELLOW}Monitoring instance creation progress...${NC}"
    
    while true; do
        # Get current status
        instance_info=$(aws rds describe-db-instances \
            --region "${AWS_REGION}" \
            --db-instance-identifier "$instance_id" --query "DBInstances[0].[DBInstanceStatus]" --output text 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error retrieving instance status. Instance might not exist.${NC}"
            return 1
        fi
        
        status="$instance_info"
        
        # Clear the line
        echo -ne "\r\033[K"
        
        # Print current status with spinner
        echo -ne "${spinner[$i]} Instance Status: ${status}"
        
        # Update spinner index
        i=$(( (i+1) % ${#spinner[@]} ))
        
        # If instance is available, we're done
        if [ "$status" == "available" ]; then
            # Get endpoint information
            endpoint=$(aws rds describe-db-instances \
                --region "${AWS_REGION}" \
                --db-instance-identifier "$instance_id" \
                --query "DBInstances[0].Endpoint.Address" \
                --output text)
            
            echo -e "\r\033[K${GREEN}Instance creation completed successfully!${NC}"
            echo -e "${BLUE}Endpoint: ${endpoint}${NC}"
            return 0
        elif [ "$status" == "failed" ]; then
            echo -e "\r\033[K${RED}Instance creation failed.${NC}"
            return 1
        fi
        
        sleep 10
    done
}

# Function to check instance status
check_instance_status() {
    local instance_id="$1"
    
    if [ -z "$instance_id" ]; then
        echo -e "${RED}Error: No instance ID provided.${NC}"
        echo "Usage: $0 instance-status <instance-id>"
        exit 1
    fi
    
    echo -e "${YELLOW}Checking status of instance '${instance_id}'...${NC}"
    
    monitor_restore_progress "$instance_id"
}

# Function to delete a snapshot
delete_snapshot() {
    local snapshot_id="$1"
    
    if [ -z "$snapshot_id" ]; then
        echo -e "${RED}Error: No snapshot ID provided.${NC}"
        echo "Usage: $0 delete <snapshot-id>"
        exit 1
    fi
    
    echo -e "${YELLOW}Deleting snapshot '${snapshot_id}'...${NC}"
    echo -e "${RED}WARNING: This operation cannot be undone!${NC}"
    
    read -p "Are you sure you want to delete this snapshot? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Delete operation cancelled.${NC}"
        exit 0
    fi
    
    aws rds delete-db-snapshot \
        --region "${AWS_REGION}" \
        --db-snapshot-identifier "${snapshot_id}"
    
    error_code=$?
    if [ $error_code -eq 0 ]; then
        echo -e "${GREEN}Successfully deleted snapshot.${NC}"
    else
        echo -e "${RED}Failed to delete snapshot. Error code: $error_code${NC}"
        exit 1
    fi
}

# Function to diagnose connectivity issues
diagnose_connectivity() {
    echo -e "${YELLOW}Running connectivity diagnostics...${NC}"
    
    # Check environment variables
    echo -e "\n${BLUE}Checking environment variables:${NC}"
    echo -e "AWS_REGION=${AWS_REGION}"
    echo -e "DB_INSTANCE_IDENTIFIER=${DB_INSTANCE_IDENTIFIER}"
    echo -e "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:0:4}... (${#AWS_ACCESS_KEY_ID} chars)"
    [ -n "$AWS_SECRET_ACCESS_KEY" ] && echo -e "AWS_SECRET_ACCESS_KEY=<set>" || echo -e "AWS_SECRET_ACCESS_KEY=<not set>"
    
    # Check network connectivity
    echo -e "\n${BLUE}Testing basic network connectivity:${NC}"
    if ping -c 1 -W 2 rds.${AWS_REGION}.amazonaws.com &>/dev/null; then
        echo -e "${GREEN}✓ Basic connectivity to RDS endpoint is working${NC}"
    else
        echo -e "${RED}✗ Cannot ping RDS endpoint. Network issues detected.${NC}"
    fi
    
    # Test AWS credentials
    echo -e "\n${BLUE}Testing AWS credentials:${NC}"
    if timeout 5 aws sts get-caller-identity &>/dev/null; then
        CALLER_IDENTITY=$(aws sts get-caller-identity --query "Arn" --output text)
        echo -e "${GREEN}✓ AWS credentials are valid. Current identity: ${CALLER_IDENTITY}${NC}"
    else
        echo -e "${RED}✗ AWS credentials test failed.${NC}"
    fi
    
    # Test RDS access specifically
    echo -e "\n${BLUE}Testing RDS service access:${NC}"
    if timeout 5 aws rds describe-db-engine-versions --region ${AWS_REGION} --engine postgres --query "DBEngineVersions[0].Engine" --output text &>/dev/null; then
        echo -e "${GREEN}✓ RDS service access is working${NC}"
    else
        echo -e "${RED}✗ RDS service access failed. Potential permission issues.${NC}"
    fi
    
    # Check if instance exists
    echo -e "\n${BLUE}Verifying DB instance ${DB_INSTANCE_IDENTIFIER} exists:${NC}"
    if timeout 10 aws rds describe-db-instances --region ${AWS_REGION} --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} --query "DBInstances[0].DBInstanceIdentifier" --output text &>/dev/null; then
        echo -e "${GREEN}✓ DB instance exists and is accessible${NC}"
    else
        echo -e "${RED}✗ DB instance check failed. Instance may not exist or is not accessible.${NC}"
    fi
    
    # Recommendations
    echo -e "\n${BLUE}Recommendations:${NC}"
    echo -e "1. Ensure you're connected to the correct network/VPN if required"
    echo -e "2. Verify your AWS credentials are not expired (run 'aws configure')"
    echo -e "3. Check if your IAM role has permissions for RDS operations"
    echo -e "4. Verify the DB instance identifier is correct (current: ${DB_INSTANCE_IDENTIFIER})"
    echo -e "5. Try increasing the timeout value for AWS commands"
}

# Function to display usage information
show_usage() {
    echo -e "${BLUE}RDS Snapshot Manager${NC}"
    echo
    echo -e "Usage: $0 <command> [options]"
    echo
    echo -e "Commands:"
    echo -e "  create [name] [async]          Create a new snapshot (optional custom name)"
    echo -e "  status <snapshot>              Check status of a snapshot creation"
    echo -e "  list [days]                    List all snapshots (optionally filtered by days)"
    echo -e "  restore <snapshot> <target> [async]  Restore a database from snapshot to new instance"
    echo -e "  instance-status <instance>     Check status of an instance creation/restore"
    echo -e "  delete <snapshot>              Delete a snapshot"
    echo -e "  diagnose                       Run connectivity diagnostics"
    echo -e "  help                           Show this help message"
    echo
    echo -e "Current configuration:"
    echo -e "  DB_INSTANCE_IDENTIFIER: ${DB_INSTANCE_IDENTIFIER}"
    echo -e "  AWS_REGION: ${AWS_REGION}"
    echo -e "  POSTGRES_HOST: ${POSTGRES_HOST}"
    echo
    echo -e "Examples:"
    echo -e "  $0 create pre-supabase-reset         # Create snapshot and monitor progress"
    echo -e "  $0 create pre-supabase-reset async   # Create snapshot in background"
    echo -e "  $0 status pre-supabase-reset         # Check snapshot progress"
    echo -e "  $0 list 7                            # List snapshots from last 7 days"
    echo -e "  $0 restore pre-supabase-reset mly-pg-restored  # Restore and monitor"
    echo -e "  $0 restore pre-supabase-reset mly-pg-restored async  # Restore in background"
    echo -e "  $0 instance-status mly-pg-restored   # Check restore progress"
    echo -e "  $0 delete old-snapshot-name          # Delete a snapshot"
    echo
}

# Main function
main() {
    check_aws_cli
    
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        create)
            create_snapshot "$1" "$2"
            ;;
        status)
            check_snapshot_status "$1"
            ;;
        list)
            list_snapshots "$1"
            ;;
        restore)
            restore_from_snapshot "$1" "$2" "$3"
            ;;
        instance-status)
            check_instance_status "$1"
            ;;
        delete)
            delete_snapshot "$1"
            ;;
        diagnose)
            diagnose_connectivity
            ;;
        help)
            show_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# Execute the script
main "$@"