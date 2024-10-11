# netbox-script
installlations file
$scriptContent = @'
#!/bin/bash
# Paste the entire script here
'@

scp C:\path\to\your\install_netbox.sh username@server-ip:/destination/path/

I'll create a guide for installing NetBox using Git on your Upcloud environment.





# Installing NetBox Using Git

## Step 1: Create a GitHub Repository

1. Go to GitHub and create a new repository
2. Create a new file named `install_netbox.sh` in your repository
3. Copy and paste the following script content:

```bash
#!/bin/bash

# NetBox Installation Script for Upcloud
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

# Update system and install prerequisites
echo "Updating system and installing prerequisites..."
dnf update -y
dnf install -y epel-release git dnf-utils device-mapper-persistent-data lvm2 curl wget
check_status "System update and prerequisites" || exit 1

# Install Docker
echo "Installing Docker..."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
check_status "Docker installation" || exit 1

# Start and enable Docker
systemctl start docker
systemctl enable docker
check_status "Docker service activation" || exit 1

# Create NetBox directory and download compose file
echo "Setting up NetBox environment..."
mkdir -p /opt/netbox-docker/env
cd /opt/netbox-docker || exit 1

# Download NetBox files
wget -O docker-compose.yml https://raw.githubusercontent.com/netbox-community/netbox-docker/release/docker-compose.yml
wget -O env/netbox.env https://raw.githubusercontent.com/netbox-community/netbox-docker/release/env/netbox.env
check_status "NetBox files download" || exit 1

# Configure environment
SECRET_KEY=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 50)
{
    echo "SUPERUSER_PASSWORD=admin"
    echo "SECRET_KEY=$SECRET_KEY"
} >> env/netbox.env

# Configure firewall
firewall-cmd --permanent --add-port=8000/tcp || true
firewall-cmd --reload || true

# Start NetBox
docker compose up -d
check_status "NetBox container startup" || exit 1

# Get server IP
SERVER_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

echo "Installation completed - Access NetBox at http://${SERVER_IP}:8000"
```

4. Commit the file to your repository

## Step 2: Install on Upcloud Server

1. SSH into your Upcloud server
2. Install Git if not already installed:
```bash
sudo dnf install -y git
```

3. Clone your repository:
```bash
git clone https://github.com/yourusername/yourrepository.git
```

4. Navigate to the repository directory:
```bash
cd yourrepository
```

5. Make the script executable:
```bash
chmod +x install_netbox.sh
```

6. Run the installation script:
```bash
sudo ./install_netbox.sh
```

## Alternative: One-Line Installation

You can also use this one-line command to download and run the script directly:

```bash
curl -s https://raw.githubusercontent.com/yourusername/yourrepository/main/install_netbox.sh | sudo bash
```

Replace `yourusername` and `yourrepository` with your actual GitHub username and repository name.

## Troubleshooting

If you encounter any issues:

1. Check the logs:
```bash
cat /var/log/netbox_install.log
```

2. Verify Docker containers are running:
```bash
docker compose ps
```

3. Check Docker logs:
```bash
docker compose logs
```

## Post-Installation

After successful installation:
1. Access NetBox at `http://your-server-ip:8000`
2. Login with:
   - Username: admin
   - Password: admin
3. Change the default password immediately



Let me provide some additional context and tips:

1. **Security Note**: Be cautious when using the one-line installation command. It's generally safer to clone the repository and review the script before running it.

2. **GitHub Repository**: Make sure your repository is public if you want to use the direct curl method. If it's private, you'll need to use personal access tokens or SSH keys.

3. **Script Modifications**: Feel free to modify the script in your repository to suit your specific needs. For example, you might want to:
   - Change the default password
   - Modify the installation directory
   - Add additional configuration options

