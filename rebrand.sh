#!/bin/bash
set -e

echo "Rebranding OpenHands to DeskDev.ai..."

# 1. Update translation.json to replace "OpenHands" with "DeskDev.ai"
echo "Updating translation.json..."
sed -i 's/OpenHands/DeskDev.ai/g' frontend/src/i18n/translation.json

# 2. Update all TypeScript/JavaScript files
echo "Updating TypeScript/JavaScript files..."
find frontend/src -name "*.ts" -o -name "*.tsx" | xargs sed -i 's/OpenHands/DeskDev.ai/g'

# 3. Update Docker-related files
echo "Updating Docker-related files..."
sed -i 's/openhands/deskdev/g' docker-compose.yml
sed -i 's/OpenHands/DeskDev.ai/g' containers/app/entrypoint.sh
sed -i 's/openhands/deskdev/g' containers/app/Dockerfile
sed -i 's/OPENHANDS/DESKDEV/g' containers/app/Dockerfile

# 4. Update Makefile
echo "Updating Makefile..."
sed -i 's/OpenHands/DeskDev.ai/g' Makefile
sed -i 's/openhands/deskdev/g' Makefile

# 5. Create a new logo (placeholder for now)
echo "Creating logo placeholder..."
mkdir -p frontend/src/assets/branding/deskdev
touch frontend/src/assets/branding/deskdev/logo.svg
touch frontend/src/assets/branding/deskdev/logo.png

echo "Rebranding complete! Please replace the placeholder logo files with your actual DeskDev.ai logo."