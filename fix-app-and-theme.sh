#!/bin/bash
set -e

echo "🔧 Fixing DeskDev.ai app loading and updating landing page theme..."

# Check Docker container status
echo "Checking Docker container status..."
if ! docker ps | grep -q deskdev-app; then
  echo "❌ DeskDev.ai container is not running"
  docker ps -a | grep deskdev-app
  
  # Check container logs
  echo "Checking container logs..."
  docker logs deskdev-app 2>&1 || echo "No logs available"
fi

# Update the landing page with dark theme
cd /opt/deskdev
mkdir -p custom/templates
cat > custom/templates/landing.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DeskDev.ai - AI-Powered Software Development</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/custom/static/css/custom-icon.css">
    <style>
        body {
            background-color: #0f172a;
            color: #e2e8f0;
        }
        .glass-effect { 
            background: rgba(15, 23, 42, 0.7); 
            backdrop-filter: blur(10px); 
            border: 1px solid rgba(51, 65, 85, 0.5);
            border-radius: 0.5rem;
        }
        .btn-primary {
            background-color: #3b82f6;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 0.375rem;
            font-weight: 500;
            transition: background-color 0.2s;
        }
        .btn-primary:hover {
            background-color: #2563eb;
        }
        .header {
            background-color: rgba(15, 23, 42, 0.8);
            backdrop-filter: blur(10px);
            border-bottom: 1px solid rgba(51, 65, 85, 0.5);
        }
    </style>
</head>
<body class="min-h-screen flex flex-col">
    <nav class="header sticky top-0 z-10">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <div class="flex-shrink-0">
                        <img src="/custom/static/images/deskdev-logo.png" alt="DeskDev.ai Logo" class="h-10 w-10">
                    </div>
                    <h1 class="text-2xl font-bold text-white ml-2">DeskDev.ai</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <a href="http://31.97.61.137:3000" class="btn-primary">
                        Launch App
                    </a>
                </div>
            </div>
        </div>
    </nav>
    <div class="flex-grow flex items-center justify-center">
        <div class="max-w-4xl mx-auto px-4 py-12 text-center">
            <h1 class="text-5xl font-bold text-white mb-6">AI-Powered Software Development</h1>
            <p class="text-xl text-gray-300 mb-8">DeskDev.ai is your intelligent coding companion with pre-configured Ollama and DeepSeek Coder.</p>
            <div class="flex justify-center space-x-4">
                <a href="http://31.97.61.137:3000" class="btn-primary text-lg px-8 py-4">
                    Get Started
                </a>
            </div>
        </div>
    </div>
    <footer class="bg-gray-900 py-6">
        <div class="max-w-7xl mx-auto px-4 text-center text-gray-400">
            <p>© 2024 DeskDev.ai - Powered by Ollama and DeepSeek Coder</p>
        </div>
    </footer>
</body>
</html>
EOF

# Create a simplified docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  deskdev:
    image: docker.all-hands.dev/all-hands-ai/openhands:latest
    container_name: deskdev-app
    user: root
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

# Update Nginx configuration for proper proxying
cat > /etc/nginx/sites-available/deskdev << 'EOF'
server {
    listen 80;
    server_name _;

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
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Socket.io for real-time communication
    location /socket.io/ {
        proxy_pass http://localhost:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Apply Nginx configuration
ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Ensure Ollama is running
if ! systemctl is-active --quiet ollama; then
  echo "Starting Ollama service..."
  systemctl start ollama
  sleep 5
fi

# Verify Ollama is accessible
if ! curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null; then
  echo "❌ Ollama API is not responding"
  
  # Fix Ollama service
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
  sleep 5
fi

# Check if deepseek-coder model is available
if ! curl -s http://localhost:11434/api/tags | grep -q "deepseek-coder"; then
  echo "Pulling deepseek-coder model..."
  ollama pull deepseek-coder:base
fi

# Restart the application
echo "Restarting the application..."
docker-compose down
docker-compose up -d

# Wait for the application to start
echo "Waiting for the application to start..."
sleep 10

# Check if the application is running
if docker ps | grep -q deskdev-app; then
  echo "✅ DeskDev.ai container is running"
else
  echo "❌ DeskDev.ai container failed to start"
  docker logs deskdev-app
fi

echo "✅ App and theme fixes completed!"
echo "🌐 Landing page (dark theme): http://31.97.61.137/"
echo "🚀 Application: http://31.97.61.137/app"
echo ""
echo "If the application is still not loading, try accessing it directly at:"
echo "  http://31.97.61.137:3000"