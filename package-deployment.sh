#!/bin/bash
set -e

# DeskDev.ai Deployment Package Script
# This script will create a zip file with all the deployment files

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Creating DeskDev.ai deployment package...${NC}"

# Create a directory for the deployment files
mkdir -p deskdev-deployment

# Copy the deployment files
cp rebrand.sh deploy.sh one-click-deploy.sh setup-ssh-key.sh check-deployment.sh deskdev-deployment/
cp DESKDEV_README.md DEPLOYMENT_GUIDE.md README_DESKDEV.md deskdev-deployment/

# Create a zip file
zip -r deskdev-deployment.zip deskdev-deployment

# Clean up
rm -rf deskdev-deployment

echo -e "${GREEN}Deployment package created: deskdev-deployment.zip${NC}"
echo -e "${YELLOW}You can now transfer this file to your local machine and extract it.${NC}"