#!/bin/bash
set -e

# DeskDev.ai Deployment Script for Hostinger KVM4 VPS
# This script will deploy the rebranded DeskDev.ai application to your VPS

# Configuration
VPS_IP="31.97.61.137"
VPS_USER="root"
APP_NAME="deskdev"
APP_PORT="3000"
FRONTEND_PORT="3001"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting deployment of DeskDev.ai to Hostinger KVM4 VPS (${VPS_IP})...${NC}"

# Step 1: Build the Docker image locally
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t ${APP_NAME}:latest -f containers/app/Dockerfile .

# Step 2: Save the Docker image to a tar file
echo -e "${YELLOW}Saving Docker image to a tar file...${NC}"
docker save ${APP_NAME}:latest > ${APP_NAME}.tar

# Step 3: Create deployment script for the VPS
echo -e "${YELLOW}Creating VPS deployment script...${NC}"
cat > vps_setup.sh << 'EOF'
#!/bin/bash
set -e

# Configuration
APP_NAME="deskdev"
APP_PORT="3000"
FRONTEND_PORT="3001"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up DeskDev.ai on VPS...${NC}"

# Step 1: Update system and install Docker if not already installed
echo -e "${YELLOW}Updating system and installing Docker...${NC}"
apt-get update
apt-get upgrade -y

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

# Step 2: Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo -e "${GREEN}Docker Compose is already installed.${NC}"
fi

# Step 3: Load the Docker image
echo -e "${YELLOW}Loading Docker image...${NC}"
docker load < ${APP_NAME}.tar

# Step 4: Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p /opt/deskdev/workspace
mkdir -p /opt/deskdev/data
mkdir -p /opt/deskdev/config

# Step 5: Create Docker Compose file
echo -e "${YELLOW}Creating Docker Compose file...${NC}"
cat > /opt/deskdev/docker-compose.yml << 'EOL'
version: '3'

services:
  deskdev:
    image: deskdev:latest
    container_name: deskdev-app
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/deskdev/workspace
    ports:
      - "3000:3000"
      - "3001:3001"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/deskdev/data:/.openhands
      - /opt/deskdev/workspace:/opt/workspace_base
    restart: unless-stopped
EOL

# Step 6: Create a basic configuration file
echo -e "${YELLOW}Creating configuration file...${NC}"
cat > /opt/deskdev/config/config.toml << 'EOL'
[core]
workspace_base="/opt/deskdev/workspace"
EOL

# Step 7: Create a systemd service for DeskDev.ai
echo -e "${YELLOW}Creating systemd service...${NC}"
cat > /etc/systemd/system/deskdev.service << 'EOL'
[Unit]
Description=DeskDev.ai AI Software Engineer
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/opt/deskdev
ExecStart=/usr/local/bin/docker-compose -f /opt/deskdev/docker-compose.yml up
ExecStop=/usr/local/bin/docker-compose -f /opt/deskdev/docker-compose.yml down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Step 8: Enable and start the service
echo -e "${YELLOW}Enabling and starting DeskDev.ai service...${NC}"
systemctl daemon-reload
systemctl enable deskdev.service
systemctl start deskdev.service

# Step 9: Set up Nginx as a reverse proxy
echo -e "${YELLOW}Setting up Nginx as a reverse proxy...${NC}"
apt-get install -y nginx

# Create Nginx configuration
cat > /etc/nginx/sites-available/deskdev << 'EOL'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /ws {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOL

# Enable the site
ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Restart Nginx
systemctl restart nginx

echo -e "${GREEN}DeskDev.ai has been successfully deployed!${NC}"
echo -e "${GREEN}You can access it at http://${VPS_IP}${NC}"
echo -e "${YELLOW}Note: For production use, it's recommended to set up SSL with Let's Encrypt.${NC}"
EOF

chmod +x vps_setup.sh

# Step 4: Transfer files to the VPS
echo -e "${YELLOW}Transferring files to the VPS...${NC}"
scp ${APP_NAME}.tar vps_setup.sh ${VPS_USER}@${VPS_IP}:/root/

# Step 5: Execute the setup script on the VPS
echo -e "${YELLOW}Executing setup script on the VPS...${NC}"
ssh ${VPS_USER}@${VPS_IP} "cd /root && ./vps_setup.sh"

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}DeskDev.ai is now accessible at http://${VPS_IP}${NC}"
echo -e "${YELLOW}Note: For production use, it's recommended to set up SSL with Let's Encrypt.${NC}"