if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges."
    echo "Please run: sudo $0"
    exit 1
fi

# Clear logs for all containers
for log in $(find /var/lib/docker/containers/ -name "*.log"); do
    truncate -s 0 "$log"
done
