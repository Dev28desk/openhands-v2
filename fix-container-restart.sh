#!/bin/bash
set -e

echo "🔧 Fixing Container Restart Issue"
echo "================================"

# Function to print section headers
section() {
  echo ""
  echo "📋 $1"
  echo "----------------------------------------"
}

# Check Docker container logs
section "Checking Docker container logs"
docker logs deskdev-app 2>&1 | tail -n 100 || echo "No logs found."

# Stop all runtime containers
section "Stopping all runtime containers"
docker ps | grep openhands-runtime | awk '{print $1}' | xargs -r docker stop
docker ps | grep openhands-runtime | awk '{print $1}' | xargs -r docker rm

# Stop the main container
section "Stopping the main container"
docker stop deskdev-app || true
docker rm deskdev-app || true

# Create a simplified docker-compose.yml
section "Creating simplified docker-compose.yml"
cd /opt/deskdev
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  deskdev:
    image: docker.all-hands.dev/all-hands-ai/openhands:latest
    container_name: deskdev-app
    user: root
    entrypoint: ["/app/entrypoint.sh"]
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/deskdev/workspace
      - OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
      - OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
      - OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production
      - OPENHANDS_GITHUB_CALLBACK_URL=http://31.97.61.137/api/auth/github/callback
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=deepseek-coder:base
      - LLM_API_KEY=
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      - DEFAULT_LLM_PROVIDER=ollama
      - DEFAULT_LLM_MODEL=deepseek-coder:base
      - DEFAULT_LLM_BASE_URL=http://host.docker.internal:11434
      - APP_NAME=DeskDev.ai
      - APP_TITLE=DeskDev.ai - AI Software Engineer
      - FRONTEND_URL=http://31.97.61.137
      - BACKEND_URL=http://31.97.61.137/api
      - RUNTIME_HOST=0.0.0.0
      - RUNTIME_PORT=30369
      - POSTHOG_ENABLED=false
      - POSTHOG_API_KEY=phc_disabled
      - RUNTIME_TIMEOUT=300000
      - RUNTIME_CONNECTION_TIMEOUT=120000
      - RUNTIME_KEEP_ALIVE=true
      - NODE_OPTIONS=--max-old-space-size=4096
    ports:
      - "3000:3000"
      - "3001:3001"
      - "30369:30369"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/deskdev/data:/.openhands
      - /opt/deskdev/workspace:/opt/workspace_base
      - /opt/deskdev/custom:/app/custom
    restart: unless-stopped
EOF

# Create default settings file
section "Creating default settings file"
mkdir -p /opt/deskdev/data/settings
cat > /opt/deskdev/data/settings/default_settings.json << 'EOF'
{
  "llm": {
    "provider": "ollama",
    "model": "deepseek-coder:base",
    "baseUrl": "http://host.docker.internal:11434",
    "apiKey": "",
    "apiVersion": "v1"
  },
  "ui": {
    "theme": "dark"
  }
}
EOF

chmod 644 /opt/deskdev/data/settings/default_settings.json

# Update Nginx configuration
section "Updating Nginx configuration"
cat > /etc/nginx/sites-available/deskdev << 'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 50M;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    # Landing page
    location = / {
        root /opt/deskdev/custom/templates;
        try_files /landing.html =404;
    }

    # Static files
    location /custom/ {
        alias /opt/deskdev/custom/;
    }

    # Frontend
    location = /app {
        return 301 http://31.97.61.137:3000;
    }

    # API
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Runtime
    location /runtime/ {
        proxy_pass http://localhost:30369/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Allow access to Ollama
section "Configuring firewall rules"
iptables -I INPUT -p tcp --dport 11434 -j ACCEPT
iptables -I DOCKER -p tcp --dport 11434 -j ACCEPT 2>/dev/null || true

# Pull latest image
section "Pulling latest Docker image"
docker pull docker.all-hands.dev/all-hands-ai/openhands:latest

# Start application
section "Starting Docker application"
cd /opt/deskdev
docker-compose up -d

# Wait and check
echo "Waiting for app to boot..."
sleep 15

if docker ps | grep -q deskdev-app; then
  echo "✅ DeskDev.ai container is running"

  echo "Testing frontend..."
  if curl -s --max-time 5 http://localhost:3000 > /dev/null; then
    echo "✅ Frontend is responding"
  else
    echo "❌ Frontend not responding"
    docker logs deskdev-app --tail 50
  fi
else
  echo "❌ Container failed to start"
  docker logs deskdev-app || echo "No logs available"
fi

section "Fix complete"
echo "✅ Container restart issue fix completed!"
echo ""
echo "🌐 Access your application:"
echo "- Frontend: http://31.97.61.137:3000"
echo "- Landing:  http://31.97.61.137/"
echo ""
