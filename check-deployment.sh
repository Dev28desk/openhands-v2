#!/bin/bash
set -e

# DeskDev.ai Deployment Status Check Script
# This script will check the status of your DeskDev.ai deployment on your Hostinger KVM4 VPS

# Configuration
VPS_IP="31.97.61.137"
VPS_USER="root"
SSH_KEY_NAME="deskdev_deploy_key"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking DeskDev.ai deployment status...${NC}"

# Check if SSH key exists
if [ -f ~/.ssh/${SSH_KEY_NAME} ]; then
  SSH_CMD="ssh -i ~/.ssh/${SSH_KEY_NAME} ${VPS_USER}@${VPS_IP}"
else
  SSH_CMD="ssh ${VPS_USER}@${VPS_IP}"
  echo -e "${YELLOW}SSH key not found. Using password authentication.${NC}"
fi

# Create a temporary script to run on the VPS
cat > check_status.sh << 'EOF'
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking system status...${NC}"

# Check system resources
echo -e "${YELLOW}System resources:${NC}"
echo "CPU usage:"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'
echo "Memory usage:"
free -m | awk 'NR==2{printf "%.2f%%\n", $3*100/$2}'
echo "Disk usage:"
df -h | grep -v tmpfs | grep -v udev

# Check Docker status
echo -e "\n${YELLOW}Docker status:${NC}"
if systemctl is-active --quiet docker; then
  echo -e "${GREEN}Docker is running${NC}"
else
  echo -e "${RED}Docker is not running${NC}"
fi

# Check DeskDev.ai service status
echo -e "\n${YELLOW}DeskDev.ai service status:${NC}"
if systemctl is-active --quiet deskdev; then
  echo -e "${GREEN}DeskDev.ai service is running${NC}"
else
  echo -e "${RED}DeskDev.ai service is not running${NC}"
fi

# Check Docker containers
echo -e "\n${YELLOW}Docker containers:${NC}"
docker ps

# Check Nginx status
echo -e "\n${YELLOW}Nginx status:${NC}"
if systemctl is-active --quiet nginx; then
  echo -e "${GREEN}Nginx is running${NC}"
else
  echo -e "${RED}Nginx is not running${NC}"
fi

# Check if the application is accessible
echo -e "\n${YELLOW}Checking if DeskDev.ai is accessible...${NC}"
if curl -s --head http://localhost | grep "200 OK" > /dev/null; then
  echo -e "${GREEN}DeskDev.ai is accessible${NC}"
else
  echo -e "${RED}DeskDev.ai is not accessible${NC}"
fi

# Check recent logs
echo -e "\n${YELLOW}Recent logs:${NC}"
journalctl -u deskdev --no-pager -n 20

echo -e "\n${GREEN}Status check completed.${NC}"
EOF

# Copy the script to the VPS
echo -e "${YELLOW}Copying status check script to VPS...${NC}"
if [ -f ~/.ssh/${SSH_KEY_NAME} ]; then
  scp -i ~/.ssh/${SSH_KEY_NAME} check_status.sh ${VPS_USER}@${VPS_IP}:/root/
else
  scp check_status.sh ${VPS_USER}@${VPS_IP}:/root/
fi

# Execute the script on the VPS
echo -e "${YELLOW}Executing status check script on VPS...${NC}"
$SSH_CMD "chmod +x /root/check_status.sh && /root/check_status.sh"

# Clean up
rm check_status.sh
$SSH_CMD "rm /root/check_status.sh"

echo -e "${GREEN}Deployment status check completed.${NC}"