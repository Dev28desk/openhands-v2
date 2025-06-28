#!/bin/bash
set -e

echo "🔍 DeskDev.ai Comprehensive Troubleshooting"
echo "=========================================="

# Function to print section headers
section() {
  echo ""
  echo "📋 $1"
  echo "----------------------------------------"
}

# Check system resources
section "Checking system resources"
echo "Memory usage:"
free -h
echo ""
echo "Disk space:"
df -h
echo ""
echo "CPU load:"
uptime

# Check Docker status
section "Checking Docker status"
if ! systemctl is-active --quiet docker; then
  echo "❌ Docker is not running. Starting Docker..."
  systemctl start docker
  sleep 5
else
  echo "✅ Docker is running"
fi

# Check running containers
section "Checking running containers"
docker ps
echo ""
echo "All containers (including stopped):"
docker ps -a

# Check Ollama status
section "Checking Ollama status"
if ! systemctl is-active --quiet ollama; then
  echo "❌ Ollama is not running. Starting Ollama..."
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
  echo "Checking Ollama logs:"
  journalctl -u ollama --no-pager | tail -n 50
  
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
    echo "This is a critical issue that needs to be resolved"
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

# Check application container logs
section "Checking application container logs"
if docker ps -q -f "name=deskdev-app" | grep -q .; then
  echo "Application container logs:"
  docker logs deskdev-app --tail 100
else
  echo "❌ Application container is not running"
fi

# Check network connectivity
section "Checking network connectivity"
echo "Testing connection from host to Ollama:"
curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null
if [ $? -eq 0 ]; then
  echo "✅ Host can connect to Ollama"
else
  echo "❌ Host cannot connect to Ollama"
fi

echo "Testing connection from Docker to Ollama:"
docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:latest curl -s --max-time 5 http://host.docker.internal:11434/api/tags > /dev/null
if [ $? -eq 0 ]; then
  echo "✅ Docker can connect to Ollama"
else
  echo "❌ Docker cannot connect to Ollama"
  echo "Adding firewall rules to allow Docker to connect to Ollama..."
  iptables -I INPUT -p tcp --dport 11434 -j ACCEPT
  iptables -I DOCKER -p tcp --dport 11434 -j ACCEPT 2>/dev/null || true
fi

# Rebuild and restart the application
section "Rebuilding and restarting the application"
cd /opt/deskdev

# Create a custom Dockerfile to build an enhanced image
cat > Dockerfile << 'EOF'
FROM docker.all-hands.dev/all-hands-ai/openhands:latest

# Set environment variables
ENV APP_NAME="DeskDev.ai" \
    APP_TITLE="DeskDev.ai - AI Software Engineer" \
    LLM_PROVIDER="ollama" \
    LLM_MODEL="deepseek-coder:base" \
    LLM_BASE_URL="http://host.docker.internal:11434" \
    POSTHOG_ENABLED="false"

# Copy custom files
COPY custom /app/custom

# Make custom scripts executable
RUN chmod +x /app/custom/*.sh || true

# Create a directory for the entrypoint script
RUN mkdir -p /app/custom/scripts

# Create a custom entrypoint script
RUN echo '#!/bin/bash' > /app/custom/scripts/entrypoint.sh && \
    echo 'echo "Starting DeskDev.ai..."' >> /app/custom/scripts/entrypoint.sh && \
    echo 'mkdir -p /.openhands/settings' >> /app/custom/scripts/entrypoint.sh && \
    echo 'echo "{\"llm\":{\"provider\":\"ollama\",\"model\":\"deepseek-coder:base\",\"baseUrl\":\"http://host.docker.internal:11434\",\"apiKey\":\"\",\"apiVersion\":\"v1\"},\"ui\":{\"theme\":\"dark\"}}" > /.openhands/settings/default_settings.json' >> /app/custom/scripts/entrypoint.sh && \
    echo 'chmod 644 /.openhands/settings/default_settings.json' >> /app/custom/scripts/entrypoint.sh && \
    echo 'exec "$@"' >> /app/custom/scripts/entrypoint.sh && \
    chmod +x /app/custom/scripts/entrypoint.sh

ENTRYPOINT ["/app/custom/scripts/entrypoint.sh", "/app/entrypoint.sh"]
EOF

# Create necessary directories
mkdir -p /opt/deskdev/custom/static/images
mkdir -p /opt/deskdev/custom/static/css

# Download the custom icon if it doesn't exist
if [ ! -f /opt/deskdev/custom/static/images/deskdev-logo.png ]; then
  curl -s -o /opt/deskdev/custom/static/images/deskdev-logo.png https://developers.redhat.com/sites/default/files/styles/keep_original/public/ML%20models.png?itok=T-pMYACJ
fi

# Create custom CSS
cat > /opt/deskdev/custom/static/css/custom-icon.css << 'EOL'
.app-logo, .logo-image {
  background-image: url('/custom/static/images/deskdev-logo.png') !important;
  background-size: contain !important;
  background-repeat: no-repeat !important;
  background-position: center !important;
}
EOL

# Build the enhanced image
echo "Building enhanced DeskDev.ai image..."
docker build -t deskdev:enhanced .

# Create an updated docker-compose.yml
cat > docker-compose.yml << 'EOL'
version: '3'

services:
  deskdev:
    image: deskdev:enhanced
    container_name: deskdev-app
    user: root
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/deskdev/workspace
      - OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
      - OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
      - OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production
      - OPENHANDS_GITHUB_CALLBACK_URL=http://31.97.61.137:3000/api/auth/github/callback
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
      - BACKEND_URL=http://31.97.61.137:3001
      - RUNTIME_HOST=0.0.0.0
      - RUNTIME_PORT=30369
      - POSTHOG_ENABLED=false
      - POSTHOG_API_KEY=phc_disabled
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
EOL

# Stop all running containers
echo "Stopping all running containers..."
docker ps -q | xargs -r docker stop
docker ps -aq | xargs -r docker rm

# Start the application
echo "Starting the application..."
docker-compose up -d

# Wait for the application to start
echo "Waiting for the application to start..."
sleep 10

# Check if the application is running
if docker ps -q -f "name=deskdev-app" | grep -q .; then
  echo "✅ Application container is running"
  
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
  echo "❌ Application container failed to start"
  echo "Checking Docker logs:"
  docker logs deskdev-app || echo "No logs available"
fi

# Update Nginx configuration
section "Updating Nginx configuration"
cat > /etc/nginx/sites-available/deskdev << 'EOL'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /socket.io {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /custom {
        alias /opt/deskdev/custom;
    }
}
EOL

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
systemctl restart nginx

section "Troubleshooting complete"
echo "The application has been rebuilt and restarted."
echo "You can access it at: http://31.97.61.137"
echo ""
echo "If you still have issues, please check the logs with:"
echo "  docker logs deskdev-app"
echo ""
echo "You can also try accessing the application directly at:"
echo "  http://31.97.61.137:3000"