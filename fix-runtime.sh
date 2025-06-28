#!/bin/bash
set -e

echo "🔧 Fixing DeskDev.ai runtime connection issues..."

# Check Docker runtime container
RUNTIME_CONTAINER=$(docker ps | grep openhands-runtime | awk '{print $1}')
if [ -z "$RUNTIME_CONTAINER" ]; then
  echo "Runtime container not found, restarting DeskDev..."
  cd /opt/deskdev
  docker-compose down
  docker-compose up -d
  sleep 10
else
  echo "Runtime container found: $RUNTIME_CONTAINER"
  echo "Checking runtime logs:"
  docker logs $RUNTIME_CONTAINER --tail 20
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

# Restart the container
docker-compose restart
sleep 10

echo "✅ Runtime fix completed! Please check if the runtime is now connecting."