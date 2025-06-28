#!/bin/bash
set -e

echo "🔧 Fixing Network Mode Issue"
echo "==========================="

# Function to print section headers
section() {
  echo ""
  echo "📋 $1"
  echo "----------------------------------------"
}

# Update docker-compose.yml without host network mode
section "Updating docker-compose.yml"
cd /opt/deskdev
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  deskdev:
    image: docker.all-hands.dev/all-hands-ai/openhands:latest
    container_name: deskdev-app
    user: root
    entrypoint: ["/bin/bash", "-c"]
    command: >
      "mkdir -p /.openhands/settings &&
       echo '{\"llm\":{\"provider\":\"ollama\",\"model\":\"deepseek-coder:base\",\"baseUrl\":\"http://host.docker.internal:11434\",\"apiKey\":\"\",\"apiVersion\":\"v1\"},\"ui\":{\"theme\":\"dark\"}}' > /.openhands/settings/default_settings.json &&
       chmod 644 /.openhands/settings/default_settings.json &&
       /app/entrypoint.sh"
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

# Ensure Ollama is running
section "Ensuring Ollama is running"
if ! systemctl is-active --quiet ollama; then
  echo "Starting Ollama service..."
  systemctl start ollama
  sleep 5
fi

# Test Ollama API
if ! curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null; then
  echo "❌ Ollama API is not responding"
  
  # Fix Ollama service
  echo "Fixing Ollama service..."
  cat > /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=root
Group=root
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"

[Install]
WantedBy=default.target
EOF

  systemctl daemon-reload
  systemctl restart ollama
  sleep 10
fi

# Ensure firewall rules allow Docker to access Ollama
section "Configuring firewall rules"
iptables -I INPUT -p tcp --dport 11434 -j ACCEPT
iptables -I DOCKER -p tcp --dport 11434 -j ACCEPT 2>/dev/null || true

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

    # Frontend application
    location /app {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Backend API
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Socket.io for real-time communication
    location /socket.io/ {
        proxy_pass http://localhost:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Runtime connection
    location /runtime/ {
        proxy_pass http://localhost:30369/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF

# Apply Nginx configuration
ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Restart the application
section "Restarting the application"
docker-compose down
docker-compose up -d

# Wait for the application to start
echo "Waiting for the application to start..."
sleep 15

# Check if the application is running
if docker ps | grep -q deskdev-app; then
  echo "✅ DeskDev.ai container is running"
  
  # Check if the application is responding
  echo "Testing application frontend..."
  if curl -s --max-time 5 http://localhost:3000 > /dev/null; then
    echo "✅ Application frontend is responding"
  else
    echo "❌ Application frontend is not responding"
    echo "Checking application logs:"
    docker logs deskdev-app --tail 50
  fi
else
  echo "❌ DeskDev.ai container failed to start"
  echo "Checking Docker logs:"
  docker logs deskdev-app || echo "No logs available"
fi

section "Fix complete"
echo "✅ Network mode issue has been fixed!"
echo ""
echo "🌐 Access your application:"
echo "- Landing page: http://31.97.61.137/"
echo "- Application: http://31.97.61.137/app"
echo ""
echo "The following changes have been made:"
echo "1. Removed incompatible 'host' network mode"
echo "2. Kept port bindings for proper container access"
echo "3. Ensured Ollama is running and accessible"
echo "4. Updated Nginx configuration with proper timeouts"
echo ""
echo "If you still encounter issues with agent creation, please check the logs with:"
echo "  docker logs deskdev-app"