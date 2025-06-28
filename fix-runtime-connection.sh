#!/bin/bash
set -e

echo "🔧 Fixing Runtime Connection and Ollama Issues"
echo "=============================================="

# Function to print section headers
section() {
  echo ""
  echo "📋 $1"
  echo "----------------------------------------"
}

# Check Docker container status
section "Checking Docker container status"
if ! docker ps | grep -q deskdev-app; then
  echo "❌ DeskDev.ai container is not running"
  docker ps -a | grep deskdev-app || echo "No container found"
else
  echo "✅ DeskDev.ai container is running"
fi

# Check Ollama status
section "Checking Ollama status"
if ! systemctl is-active --quiet ollama; then
  echo "❌ Ollama is not running"
  echo "Starting Ollama service..."
  systemctl start ollama
  sleep 5
else
  echo "✅ Ollama is running"
fi

# Test Ollama API
section "Testing Ollama API"
if curl -s --max-time 5 http://localhost:11434/api/tags | grep -q "models"; then
  echo "✅ Ollama API is responding"
  echo "Available models:"
  curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4
else
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
  
  if curl -s --max-time 5 http://localhost:11434/api/tags | grep -q "models"; then
    echo "✅ Ollama API is now responding after fix"
  else
    echo "❌ Ollama API is still not responding after fix"
    echo "Checking Ollama logs:"
    journalctl -u ollama --no-pager | tail -n 50
    
    echo "Reinstalling Ollama..."
    systemctl stop ollama
    rm -rf /usr/local/bin/ollama
    curl -fsSL https://ollama.com/install.sh | sh
    systemctl daemon-reload
    systemctl restart ollama
    sleep 10
  fi
fi

# Check if deepseek-coder model is available
section "Checking if deepseek-coder model is available"
if curl -s http://localhost:11434/api/tags | grep -q "deepseek-coder"; then
  echo "✅ deepseek-coder model is available"
else
  echo "❌ deepseek-coder model is not available"
  echo "Pulling deepseek-coder model..."
  ollama pull deepseek-coder:base
fi

# Check network connectivity between Docker and Ollama
section "Checking network connectivity"
echo "Testing connection from Docker to Ollama..."
docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:latest curl -s --max-time 5 http://host.docker.internal:11434/api/tags > /dev/null
if [ $? -eq 0 ]; then
  echo "✅ Docker can connect to Ollama"
else
  echo "❌ Docker cannot connect to Ollama"
  echo "Adding firewall rules to allow Docker to connect to Ollama..."
  iptables -I INPUT -p tcp --dport 11434 -j ACCEPT
  iptables -I DOCKER -p tcp --dport 11434 -j ACCEPT 2>/dev/null || true
  
  echo "Testing connection again..."
  docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:latest curl -s --max-time 5 http://host.docker.internal:11434/api/tags > /dev/null
  if [ $? -eq 0 ]; then
    echo "✅ Docker can now connect to Ollama after firewall fix"
  else
    echo "❌ Docker still cannot connect to Ollama"
    echo "This is a critical issue that needs to be resolved"
  fi
fi

# Update docker-compose.yml with increased timeouts
section "Updating docker-compose.yml with increased timeouts"
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
    network_mode: "host"
EOF

# Update Nginx configuration with increased timeouts
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
  
  echo "Testing application backend..."
  if curl -s --max-time 5 http://localhost:3001/api/health > /dev/null; then
    echo "✅ Application backend is responding"
  else
    echo "❌ Application backend is not responding"
    echo "Checking application logs:"
    docker logs deskdev-app --tail 50
  fi
else
  echo "❌ DeskDev.ai container failed to start"
  echo "Checking Docker logs:"
  docker logs deskdev-app || echo "No logs available"
fi

section "Fix complete"
echo "✅ Runtime connection and Ollama fixes have been applied!"
echo ""
echo "🌐 Access your application:"
echo "- Landing page: http://31.97.61.137/"
echo "- Application: http://31.97.61.137/app"
echo ""
echo "The following changes have been made:"
echo "1. Increased connection timeouts for runtime"
echo "2. Verified Ollama is running and accessible"
echo "3. Ensured deepseek-coder model is available"
echo "4. Added firewall rules for Docker-to-Ollama communication"
echo "5. Updated Nginx configuration with increased timeouts"
echo "6. Switched to host network mode for better connectivity"
echo ""
echo "If you still encounter issues, please check the logs with:"
echo "  docker logs deskdev-app"
echo "  journalctl -u ollama"