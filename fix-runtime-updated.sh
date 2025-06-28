#!/bin/bash
set -e

echo "🔧 Fixing DeskDev.ai runtime connection issues..."

# Check for running containers using port 30369
PORT_CONTAINER=$(docker ps -q --filter "publish=30369")
if [ -n "$PORT_CONTAINER" ]; then
  echo "Found container using port 30369: $PORT_CONTAINER"
  echo "Stopping container to free up the port..."
  docker stop $PORT_CONTAINER
  docker rm $PORT_CONTAINER
fi

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null; then
  echo "Ollama not running, restarting..."
  systemctl restart ollama
  sleep 5
fi

# Verify Ollama model
echo "Checking Ollama models:"
ollama list

# Update environment variables
cd /opt/deskdev
cat > .env << 'EOL'
APP_NAME=DeskDev.ai
APP_TITLE=DeskDev.ai - AI Software Engineer
OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
LLM_BASE_URL=http://host.docker.internal:11434
LLM_MODEL=deepseek-coder:base
LLM_PROVIDER=ollama
LLM_API_KEY=
LLM_API_VERSION=v1
RUNTIME_HOST=0.0.0.0
RUNTIME_PORT=30369
EOL

# Update docker-compose.yml with volume mounts for custom files
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
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=deepseek-coder:base
      - LLM_API_KEY=
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      - APP_NAME=DeskDev.ai
      - APP_TITLE=DeskDev.ai - AI Software Engineer
      - FRONTEND_URL=http://31.97.61.137:3000
      - BACKEND_URL=http://31.97.61.137:3001
      - RUNTIME_HOST=0.0.0.0
      - RUNTIME_PORT=30369
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

# Restart the container
docker-compose up -d

echo "✅ Runtime fix completed! Please check if the runtime is now connecting."