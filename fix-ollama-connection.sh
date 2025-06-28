#!/bin/bash
set -e

echo "🤖 Fixing Ollama connection for DeskDev.ai..."

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null; then
  echo "Ollama not running, starting it..."
  systemctl restart ollama
  sleep 5
fi

# Verify Ollama is accessible
echo "Testing Ollama API..."
if ! curl -s http://localhost:11434/api/tags | grep -q "models"; then
  echo "Ollama API not responding. Checking service..."
  systemctl status ollama
  
  # Fix Ollama service configuration
  echo "Updating Ollama service configuration..."
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

  # Reload and restart Ollama
  systemctl daemon-reload
  systemctl restart ollama
  sleep 5
fi

# Check if the model is available
echo "Checking if deepseek-coder:base model is available..."
if ! curl -s http://localhost:11434/api/tags | grep -q "deepseek-coder:base"; then
  echo "Model not found, pulling deepseek-coder:base..."
  ollama pull deepseek-coder:base
fi

# Create a default settings file for the application
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

# Update environment variables
cd /opt/deskdev
cat > .env << 'EOL'
APP_NAME=DeskDev.ai
APP_TITLE=DeskDev.ai - AI Software Engineer
OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production
LLM_BASE_URL=http://host.docker.internal:11434
LLM_MODEL=deepseek-coder:base
LLM_PROVIDER=ollama
LLM_API_KEY=
LLM_API_VERSION=v1
RUNTIME_HOST=0.0.0.0
RUNTIME_PORT=30369
POSTHOG_ENABLED=false
POSTHOG_API_KEY=phc_disabled
OPENHANDS_GITHUB_CALLBACK_URL=http://31.97.61.137:3000/api/auth/github/callback
DEFAULT_LLM_PROVIDER=ollama
DEFAULT_LLM_MODEL=deepseek-coder:base
DEFAULT_LLM_BASE_URL=http://host.docker.internal:11434
EOL

# Update docker-compose.yml with Ollama settings
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
      - FRONTEND_URL=http://31.97.61.137:3000
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

# Create a custom init script to ensure Ollama is properly configured
cat > /opt/deskdev/custom/init-ollama.sh << 'EOL'
#!/bin/bash

# This script runs inside the Docker container to ensure Ollama is properly configured
echo "Configuring Ollama connection..."

# Create a default settings file
mkdir -p /.openhands/settings
cat > /.openhands/settings/default_settings.json << 'EOF'
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

# Set permissions
chmod 644 /.openhands/settings/default_settings.json

echo "Ollama configuration complete!"
EOL

chmod +x /opt/deskdev/custom/init-ollama.sh

# Create a custom entrypoint script
cat > /opt/deskdev/custom/entrypoint.sh << 'EOL'
#!/bin/bash

# Run the Ollama init script
/app/custom/init-ollama.sh

# Continue with the original entrypoint
exec "$@"
EOL

chmod +x /opt/deskdev/custom/entrypoint.sh

# Update docker-compose.yml to use the custom entrypoint
cat > docker-compose.yml << 'EOL'
version: '3'

services:
  deskdev:
    image: deskdev:enhanced
    container_name: deskdev-app
    user: root
    entrypoint: ["/app/custom/entrypoint.sh", "/app/entrypoint.sh"]
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
      - FRONTEND_URL=http://31.97.61.137:3000
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

# Ensure Ollama is accessible from Docker
echo "Ensuring Ollama is accessible from Docker..."
iptables -I INPUT -p tcp --dport 11434 -j ACCEPT
iptables -I DOCKER -p tcp --dport 11434 -j ACCEPT

# Restart the Docker container
echo "Restarting the Docker container..."
docker-compose down
docker-compose up -d

echo "✅ Ollama connection fixed!"
echo "🚀 Application: http://31.97.61.137:3000"
echo ""
echo "The application should now automatically connect to Ollama using the deepseek-coder:base model."
echo "Users don't need to configure anything unless they want to change the model."
echo ""
echo "If you still have issues, check the Ollama logs with:"
echo "  systemctl status ollama"
echo "  journalctl -u ollama"
echo ""
echo "And check the application logs with:"
echo "  docker logs deskdev-app"