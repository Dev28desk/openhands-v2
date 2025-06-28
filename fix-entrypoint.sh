#!/bin/bash
set -e

echo "🔧 Fixing DeskDev.ai entrypoint script issue..."

# Create directory structure
cd /opt/deskdev
mkdir -p custom/scripts

# Create the entrypoint script directly in the custom directory
cat > custom/scripts/entrypoint.sh << 'EOF'
#!/bin/bash
echo "Starting DeskDev.ai..."
mkdir -p /.openhands/settings
echo '{"llm":{"provider":"ollama","model":"deepseek-coder:base","baseUrl":"http://host.docker.internal:11434","apiKey":"","apiVersion":"v1"},"ui":{"theme":"dark"}}' > /.openhands/settings/default_settings.json
chmod 644 /.openhands/settings/default_settings.json
exec "$@"
EOF

# Make the script executable
chmod +x custom/scripts/entrypoint.sh

# Update docker-compose.yml with a simpler configuration
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
EOF

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
else
  echo "❌ Application container failed to start"
  echo "Checking Docker logs:"
  docker logs deskdev-app || echo "No logs available"
fi

echo "✅ Entrypoint script fix completed!"
echo "🌐 Access your application at: http://31.97.61.137"