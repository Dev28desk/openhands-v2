#!/bin/bash
echo "Applying DeskDev.ai branding..."
find /app -type f \( -name "*.js" -o -name "*.html" -o -name "*.css" -o -name "*.json" \) -exec sed -i 's/OpenHands/DeskDev.ai/g' {} \; 2>/dev/null || true
find /app -type f -name "*.py" -exec sed -i 's/"OpenHands"/"DeskDev.ai"/g' {} \; 2>/dev/null || true
echo "Branding applied successfully!"