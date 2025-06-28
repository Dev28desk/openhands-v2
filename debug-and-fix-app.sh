#!/bin/bash
set -e

echo "🔍 Debugging and Fixing DeskDev.ai App Loading Issues"
echo "==================================================="

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

# Check Docker container status
section "Checking Docker container status"
docker ps -a
if docker ps -a | grep -q deskdev-app; then
  echo "Container exists, checking its status..."
  if docker ps | grep -q deskdev-app; then
    echo "✅ Container is running"
  else
    echo "❌ Container exists but is not running"
    echo "Container logs:"
    docker logs deskdev-app --tail 100
  fi
else
  echo "❌ Container does not exist"
fi

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
if curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null; then
  echo "✅ Ollama API is responding"
  echo "Available models:"
  curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4
else
  echo "❌ Ollama API is not responding"
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

# Check network connectivity
section "Checking network connectivity"
echo "Testing connection from host to Ollama:"
curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null
if [ $? -eq 0 ]; then
  echo "✅ Host can connect to Ollama"
else
  echo "❌ Host cannot connect to Ollama"
fi

# Check port availability
section "Checking port availability"
echo "Checking if ports 3000, 3001, and 30369 are available:"
netstat -tuln | grep -E '3000|3001|30369'
if [ $? -eq 0 ]; then
  echo "⚠️ Some ports are already in use"
  echo "Stopping any processes using these ports..."
  fuser -k 3000/tcp 3001/tcp 30369/tcp 2>/dev/null || true
else
  echo "✅ All ports are available"
fi

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

# Create a dark-themed landing page
section "Creating dark-themed landing page"
mkdir -p /opt/deskdev/custom/templates
cat > /opt/deskdev/custom/templates/landing.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DeskDev.ai - AI-Powered Software Development</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
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
EOL

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

    # Frontend application - direct access
    location = /app {
        return 301 http://31.97.61.137:3000;
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

# Ensure firewall rules allow Docker to access Ollama
section "Configuring firewall rules"
iptables -I INPUT -p tcp --dport 11434 -j ACCEPT
iptables -I DOCKER -p tcp --dport 11434 -j ACCEPT 2>/dev/null || true

# Stop any running containers
section "Stopping any running containers"
docker ps -q | xargs -r docker stop
docker ps -aq | xargs -r docker rm

# Pull the latest image
section "Pulling the latest image"
docker pull docker.all-hands.dev/all-hands-ai/openhands:latest

# Start the application
section "Starting the application"
cd /opt/deskdev
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

section "Creating direct access script"
cat > /opt/deskdev/direct-access.sh << 'EOF'
#!/bin/bash
echo "DeskDev.ai Direct Access URLs:"
echo "----------------------------"
echo "Frontend: http://31.97.61.137:3000"
echo "Backend API: http://31.97.61.137:3001/api"
echo "Runtime: http://31.97.61.137:30369"
echo ""
echo "Testing direct access..."
echo "Frontend: $(curl -s -o /dev/null -w "%{http_code}" http://31.97.61.137:3000)"
echo "Backend: $(curl -s -o /dev/null -w "%{http_code}" http://31.97.61.137:3001/api/health)"
echo ""
echo "If you see 200 for both, the application is accessible directly."
echo "If not, check the container logs with: docker logs deskdev-app"
EOF
chmod +x /opt/deskdev/direct-access.sh

section "Debug and fix complete"
echo "✅ Debugging and fixing completed!"
echo ""
echo "🌐 Access your application directly:"
echo "- Frontend: http://31.97.61.137:3000"
echo "- Landing page: http://31.97.61.137/"
echo ""
echo "The following changes have been made:"
echo "1. Simplified docker-compose.yml to avoid configuration issues"
echo "2. Updated Nginx to redirect /app to the direct application URL"
echo "3. Created a direct access script to test connectivity"
echo "4. Pulled the latest image to ensure compatibility"
echo ""
echo "If the application is still not loading, run the direct access script:"
echo "  cd /opt/deskdev && ./direct-access.sh"
echo ""
echo "You can also check the container logs with:"
echo "  docker logs deskdev-app"