#!/bin/bash

# Local Development Setup for DeskDev.ai
# This script configures the application to run on localhost with the specified ports

echo "🚀 Setting up DeskDev.ai for local development..."

# Create local development directory
mkdir -p ~/deskdev-local
cd ~/deskdev-local

# Create docker-compose.yml for local development
cat > docker-compose.local.yml << 'EOF'
version: '3'

services:
  deskdev-local:
    image: ghcr.io/all-hands-ai/openhands:latest
    container_name: deskdev-local-app
    environment:
      # Core settings
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/workspace
      
      # Local Ollama configuration
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=deepseek-coder:base
      - LLM_API_KEY=ollama
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      
      # App configuration
      - APP_NAME=DeskDev.ai
      - APP_TITLE=DeskDev.ai - Local Development
      - FRONTEND_URL=http://localhost:52099
      - BACKEND_URL=http://localhost:57469
      
      # CORS and iframe settings
      - CORS_ALLOWED_ORIGINS=http://localhost:52099,http://localhost:57469
      - ALLOW_IFRAME=true
      - ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
      
    ports:
      # Map to your available ports
      - "52099:3000"  # Frontend
      - "57469:3001"  # Backend API
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/.openhands
      - ./workspace:/workspace
    restart: unless-stopped
EOF

# Create vite.config.js for frontend development
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 52099,
    allowedHosts: true,
    cors: {
      origin: ['http://localhost:52099', 'http://localhost:57469'],
      credentials: true
    },
    headers: {
      'X-Frame-Options': 'ALLOWALL',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    }
  },
  preview: {
    host: '0.0.0.0',
    port: 52099,
    cors: true
  }
})
EOF

# Create local Nginx configuration
cat > nginx.local.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    # CORS headers
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;
    add_header 'X-Frame-Options' 'ALLOWALL' always;

    # Frontend (port 52099)
    location / {
        proxy_pass http://localhost:52099;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }

    # Backend API (port 57469)
    location /api/ {
        proxy_pass http://localhost:57469/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS for API
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;
    }

    # WebSocket support
    location /socket.io/ {
        proxy_pass http://localhost:52099;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# Create local environment file
cat > .env.local << 'EOF'
# Local Development Environment
NODE_ENV=development
VITE_APP_NAME=DeskDev.ai
VITE_API_URL=http://localhost:57469
VITE_WS_URL=ws://localhost:52099

# Ollama configuration
VITE_LLM_BASE_URL=http://localhost:11434
VITE_LLM_MODEL=deepseek-coder:base
VITE_LLM_PROVIDER=ollama

# CORS settings
CORS_ORIGIN=http://localhost:52099,http://localhost:57469
ALLOW_IFRAME=true
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
EOF

# Create local development start script
cat > start-local.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting DeskDev.ai Local Development Environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "⚠️  Ollama is not running. Starting Ollama..."
    if command -v ollama > /dev/null 2>&1; then
        ollama serve &
        sleep 5
        echo "✅ Ollama started"
    else
        echo "❌ Ollama is not installed. Please install Ollama first:"
        echo "   curl -fsSL https://ollama.ai/install.sh | sh"
        exit 1
    fi
fi

# Pull the required model if not available
if ! ollama list | grep -q "deepseek-coder:base"; then
    echo "📥 Pulling deepseek-coder:base model..."
    ollama pull deepseek-coder:base
fi

# Create directories
mkdir -p data workspace

# Start the application
echo "🐳 Starting DeskDev.ai container..."
docker-compose -f docker-compose.local.yml up -d

# Wait for the application to start
echo "⏳ Waiting for application to start..."
sleep 10

# Check if the application is running
if curl -s http://localhost:52099 > /dev/null 2>&1; then
    echo "✅ DeskDev.ai is running!"
    echo "🌐 Frontend: http://localhost:52099"
    echo "🔧 Backend API: http://localhost:57469"
    echo "🤖 Ollama: http://localhost:11434"
else
    echo "❌ Application failed to start. Check logs:"
    docker logs deskdev-local-app
fi
EOF

chmod +x start-local.sh

# Create stop script
cat > stop-local.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping DeskDev.ai Local Development Environment..."
docker-compose -f docker-compose.local.yml down
echo "✅ Stopped"
EOF

chmod +x stop-local.sh

# Create package.json for frontend development
cat > package.json << 'EOF'
{
  "name": "deskdev-local",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 52099",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0 --port 52099"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^4.3.9"
  }
}
EOF

echo "✅ Local development environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Install Ollama if not already installed:"
echo "   curl -fsSL https://ollama.ai/install.sh | sh"
echo ""
echo "2. Start the local development environment:"
echo "   ./start-local.sh"
echo ""
echo "3. Access your application:"
echo "   Frontend: http://localhost:52099"
echo "   Backend API: http://localhost:57469"
echo ""
echo "4. Stop the environment when done:"
echo "   ./stop-local.sh"
echo ""
echo "🔧 Configuration files created:"
echo "   - docker-compose.local.yml (Docker configuration)"
echo "   - vite.config.js (Frontend server configuration)"
echo "   - nginx.local.conf (Nginx configuration)"
echo "   - .env.local (Environment variables)"
echo "   - start-local.sh (Start script)"
echo "   - stop-local.sh (Stop script)"
