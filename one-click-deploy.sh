#!/bin/bash
set -e

# DeskDev.ai One-Click Deployment Script
# This script will rebrand OpenHands to DeskDev.ai and deploy it to your Hostinger KVM4 VPS

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting DeskDev.ai One-Click Deployment...${NC}"

# Step 1: Run the rebranding script
echo -e "${YELLOW}Step 1: Rebranding OpenHands to DeskDev.ai...${NC}"
./rebrand.sh

# Step 2: Run the deployment script
echo -e "${YELLOW}Step 2: Deploying DeskDev.ai to Hostinger KVM4 VPS...${NC}"
./deploy.sh

echo -e "${GREEN}One-Click Deployment completed successfully!${NC}"
echo -e "${GREEN}DeskDev.ai is now accessible at http://31.97.61.137${NC}"
echo -e "${YELLOW}Note: For production use, it's recommended to set up SSL with Let's Encrypt and configure a domain name.${NC}"