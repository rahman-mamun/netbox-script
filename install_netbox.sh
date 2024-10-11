#!/bin/bash

# NetBox Installation Script for Upcloud - Improved Error Handling
# This script automates the installation of NetBox using Docker on CentOS 9

# Exit on any error and enable debug mode
set -e
set -x

# Log file setup
LOG_FILE="/var/log/netbox_install.log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

echo "Starting NetBox installation on Upcloud - $(date)"

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "Success: $1"
    else
        echo "Error: $1 failed"
        return 1
    fi
}

# Function to handle errors
handle_error() {
    echo "Error occurred in line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Update system and install EPEL
echo "Adding EPEL repository and updating system..."
dnf install -y epel-release
dnf update -y
check_status "System update" || exit 1

# Install prerequisites
echo "Installing prerequisites..."
dnf install -y dnf-utils device-mapper-persistent-data lvm2 curl wget
check_status "Prerequisites installation" || exit 1

# Remove any old Docker installations
echo "Removing any old Docker installations..."
dnf remove -y docker docker-common docker-selinux docker-engine || true

# Install Docker - with retries
echo "Installing Docker..."
for i in {1..3}; do
    if dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo; then
        break
    fi
    echo "Retry $i adding Docker repository..."
    sleep 5
done

for i in {1..3}; do
    if dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
        break
    fi
    echo "Retry $i installing Docker..."
    sleep 5
done
check_status "Docker installation" || exit 1

# Start and enable Docker
echo "Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker
check_status "Docker service activation" || exit 1

# Verify Docker installation
docker --version
check_status "Docker version check" || exit 1

# Create NetBox directory and download compose file
echo "Setting up NetBox environment..."
mkdir -p /opt/netbox-docker/env
cd /opt/netbox-docker || exit 1

# Download necessary files with retries
echo "Downloading NetBox files..."
for i in {1..3}; do
    if wget -O docker-compose.yml https://raw.githubusercontent.com/netbox-community/netbox-docker/release/docker-compose.yml && \
       wget -O env/netbox.env https://raw.githubusercontent.com/netbox-community/netbox-docker/release/env/netbox.env; then
        break
    fi
    echo "Retry $i downloading NetBox files..."
    sleep 5
done
check_status "NetBox files download" || exit 1

# Generate and set secrets
echo "Configuring NetBox environment..."
SECRET_KEY=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 50)
{
    echo "SUPERUSER_PASSWORD=admin"
    echo "SECRET_KEY=$SECRET_KEY"
} >> env/netbox.env
check_status "Environment configuration" || exit 1

# Configure firewall
echo "Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=8000/tcp || true
    firewall-cmd --reload || true
    check_status "Firewall configuration"
fi

# Start NetBox with retry
echo "Starting NetBox containers..."
for i in {1..3}; do
    if docker compose up -d; then
        break
    fi
    echo "Retry $i starting NetBox containers..."
    sleep 10
done
check_status "NetBox container startup" || exit 1

# Wait for NetBox to be ready
echo "Waiting for NetBox to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8000 > /dev/null; then
        echo "NetBox is up!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 10
done

# Get server IP
SERVER_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# Show Docker logs in case of issues
docker compose logs

# Final output
cat << EOF

NetBox Installation Complete!
============================
Access NetBox at: http://${SERVER_IP}:8000

Default login credentials:
Username: admin
Password: admin

IMPORTANT:
1. Please change the default password immediately after logging in
2. For production use, consider setting up HTTPS using a reverse proxy
3. Installation logs are available at: $LOG_FILE

Troubleshooting:
- Check logs: docker compose logs
- Restart NetBox: docker compose restart
- Full restart: docker compose down && docker compose up -d

EOF

echo "Installation completed - $(date)"