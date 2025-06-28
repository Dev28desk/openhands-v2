#!/bin/bash
set -e

# SSH Key Setup Script for DeskDev.ai Deployment
# This script will generate an SSH key and copy it to your Hostinger KVM4 VPS

# Configuration
VPS_IP="31.97.61.137"
VPS_USER="root"
SSH_KEY_NAME="deskdev_deploy_key"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up SSH key for DeskDev.ai deployment...${NC}"

# Step 1: Generate SSH key
echo -e "${YELLOW}Generating SSH key...${NC}"
ssh-keygen -t ed25519 -f ~/.ssh/${SSH_KEY_NAME} -N "" -C "deskdev_deploy"

# Step 2: Copy SSH key to VPS
echo -e "${YELLOW}Copying SSH key to VPS...${NC}"
echo -e "${RED}You will be prompted for the VPS password.${NC}"
ssh-copy-id -i ~/.ssh/${SSH_KEY_NAME}.pub ${VPS_USER}@${VPS_IP}

# Step 3: Test SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
ssh -i ~/.ssh/${SSH_KEY_NAME} ${VPS_USER}@${VPS_IP} "echo 'SSH connection successful!'"

echo -e "${GREEN}SSH key setup completed successfully!${NC}"
echo -e "${YELLOW}You can now use the following command to connect to your VPS:${NC}"
echo -e "${GREEN}ssh -i ~/.ssh/${SSH_KEY_NAME} ${VPS_USER}@${VPS_IP}${NC}"

# Update the deploy.sh script to use the SSH key
echo -e "${YELLOW}Updating deploy.sh to use the SSH key...${NC}"
sed -i "s/scp ${APP_NAME}.tar/scp -i ~\/.ssh\/${SSH_KEY_NAME} ${APP_NAME}.tar/g" deploy.sh
sed -i "s/ssh ${VPS_USER}@${VPS_IP}/ssh -i ~\/.ssh\/${SSH_KEY_NAME} ${VPS_USER}@${VPS_IP}/g" deploy.sh

echo -e "${GREEN}deploy.sh has been updated to use the SSH key.${NC}"