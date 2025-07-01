#!/bin/bash
set -e

echo "🚀 Complete System Deployment Script for 154.201.127.161"
echo "========================================================"
echo "Installing: OpenHands + Open WebUI + Ollama + CodeLlama 70B"
echo ""

# Variables
SERVER_IP="154.201.127.161"
OLLAMA_MODEL="codellama:70b-code"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Clean up everything
print_status "🧹 Cleaning up existing installations..."
sudo systemctl stop docker ollama nginx apache2 2>/dev/null || true
sudo systemctl disable docker ollama nginx apache2 2>/dev/null || true
sudo apt-get remove -y docker docker-engine docker.io containerd runc nginx apache2 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true
sudo rm -rf /opt/deskdev /opt/openhands /opt/open-webui /var/lib/docker /etc/docker
sudo rm -rf /usr/local/bin/ollama /etc/systemd/system/ollama.service
sudo rm -rf /etc/nginx /etc/apache2
sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
sudo docker rmi $(sudo docker images -q) 2>/dev/null || true

# Update system
print_status "📦 Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl wget git nano htop net-tools ufw ca-certificates gnupg lsb-release

# Configure firewall
print_status "🔥 Configuring firewall..."
sudo ufw --force disable
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 3000/tcp  # OpenHands Frontend
sudo ufw allow 3001/tcp  # OpenHands Backend
sudo ufw allow 8080/tcp  # Open WebUI
sudo ufw allow 11434/tcp # Ollama API
sudo ufw allow 30369/tcp # OpenHands Runtime
sudo ufw --force enable

# Install Docker
print_status "🐳 Installing Docker..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# Install Docker Compose
print_status "🐳 Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Ollama
print_status "🤖 Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

# Configure Ollama
print_status "⚙️ Configuring Ollama..."
sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ollama serve
User=root
Group=root
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Environment="OLLAMA_CORS_ALLOWED_ORIGINS=*"
Environment="OLLAMA_KEEP_ALIVE=24h"
Environment="OLLAMA_MODELS=/usr/share/ollama/.ollama/models"

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl restart ollama
sleep 10

# Test Ollama
print_status "🧪 Testing Ollama..."
curl -s http://localhost:11434/api/tags || print_error "Ollama test failed!"

# Pull CodeLlama 70B model
print_status "📥 Pulling CodeLlama 70B model (this will take 30-60 minutes)..."
print_warning "The 70B model requires ~40GB of disk space and ~70GB of RAM to run efficiently"
ollama pull $OLLAMA_MODEL || print_error "Failed to pull model!"

# Create application directories
print_status "📁 Creating application directories..."
sudo mkdir -p /opt/{deskdev,open-webui}/{data,config}
sudo mkdir -p /opt/deskdev/{workspace,custom/templates,custom/static/{css,images}}
sudo chmod -R 755 /opt

# Create landing page for DeskDev
print_status "🎨 Creating DeskDev landing page..."
sudo tee /opt/deskdev/custom/templates/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Development Platform - 154.201.127.161</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0a0a0a;
            color: #ffffff;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 2rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin-top: 3rem;
        }
        .service-card {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 1rem;
            padding: 2rem;
            transition: transform 0.2s;
        }
        .service-card:hover {
            transform: translateY(-5px);
            background: rgba(255, 255, 255, 0.08);
        }
        .service-card h2 {
            margin-bottom: 1rem;
            color: #667eea;
        }
        .service-card p {
            color: #999;
            margin-bottom: 1.5rem;
        }
        .btn {
            display: inline-block;
            padding: 0.75rem 1.5rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 0.5rem;
            font-weight: 600;
            transition: opacity 0.2s;
        }
        .btn:hover {
            opacity: 0.9;
        }
        .status {
            margin-top: 3rem;
            padding: 1rem;
            background: rgba(0, 255, 0, 0.1);
            border: 1px solid rgba(0, 255, 0, 0.3);
            border-radius: 0.5rem;
        }
        .model-info {
            margin-top: 2rem;
            padding: 1rem;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 0.5rem;
        }
        code {
            background: rgba(255, 255, 255, 0.1);
            padding: 0.25rem 0.5rem;
            border-radius: 0.25rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>AI Development Platform</h1>
        <p style="font-size: 1.25rem; color: #999;">Complete AI development environment with CodeLlama 70B</p>
        
        <div class="services">
            <div class="service-card">
                <h2>🚀 OpenHands (DeskDev.ai)</h2>
                <p>AI-powered software development assistant for building applications</p>
                <a href="http://154.201.127.161:3000" class="btn">Launch OpenHands</a>
            </div>
            
            <div class="service-card">
                <h2>💬 Open WebUI</h2>
                <p>Chat interface for interacting with CodeLlama 70B model</p>
                <a href="http://154.201.127.161:8080" class="btn">Launch Open WebUI</a>
            </div>
            
            <div class="service-card">
                <h2>🤖 Ollama API</h2>
                <p>Direct API access to CodeLlama and other models</p>
                <a href="http://154.201.127.161:11434" class="btn">API Endpoint</a>
            </div>
        </div>
        
        <div class="status">
            <h3>✅ All Services Running</h3>
            <p>Server IP: <code>154.201.127.161</code></p>
        </div>
        
        <div class="model-info">
            <h3>🧠 Available Model</h3>
            <p>Model: <code>codellama:70b-code</code></p>
            <p>Specialized for code generation, debugging, and software development tasks</p>
        </div>
    </div>
</body>
</html>
EOF

# Create main Docker Compose file
print_status "🐳 Creating Docker Compose configuration..."
sudo tee /opt/docker-compose.yml > /dev/null << 'EOF'
version: '3.8'

networks:
  ai-network:
    driver: bridge

services:
  # OpenHands (DeskDev.ai)
  openhands:
    image: ghcr.io/all-hands-ai/openhands:latest
    container_name: openhands
    restart: unless-stopped
    user: root
    networks:
      - ai-network
    environment:
      # Core settings
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/workspace_base
      
      # Ollama Configuration
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=codellama:70b-code
      - LLM_API_KEY=
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      - DEFAULT_LLM_PROVIDER=ollama
      - DEFAULT_LLM_MODEL=codellama:70b-code
      
      # App Configuration
      - APP_NAME=DeskDev.ai
      - APP_TITLE=DeskDev.ai - AI Software Engineer
      - FRONTEND_URL=http://154.201.127.161:3000
      - BACKEND_URL=http://154.201.127.161:3001
      
      # Runtime Configuration
      - RUNTIME_HOST=0.0.0.0
      - RUNTIME_PORT=30369
      - RUNTIME_TIMEOUT=300
      
      # Disable analytics
      - POSTHOG_CLIENT_KEY=
      - DISABLE_ANALYTICS=true
      
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

  # Open WebUI
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    networks:
      - ai-network
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - WEBUI_SECRET_KEY=your-secret-key-change-this-$(openssl rand -hex 32)
      - WEBUI_NAME=Open WebUI - CodeLlama 70B
      - ENABLE_SIGNUP=true
      - DEFAULT_MODELS=codellama:70b-code
      - WEBUI_URL=http://154.201.127.161:8080
    ports:
      - "8080:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /opt/open-webui/data:/app/backend/data

  # Nginx reverse proxy
  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    restart: unless-stopped
    networks:
      - ai-network
    ports:
      - "80:80"
    volumes:
      - /opt/nginx.conf:/etc/nginx/nginx.conf:ro
      - /opt/deskdev/custom/templates:/usr/share/nginx/html:ro
EOF

# Create Nginx configuration
print_status "🔧 Creating Nginx configuration..."
sudo tee /opt/nginx.conf > /dev/null << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Increase timeouts for AI operations
    proxy_read_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    client_max_body_size 100M;
    
    # Main landing page
    server {
        listen 80;
        server_name _;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;
        }
        
        # Proxy to OpenHands
        location /openhands {
            return 301 http://$server_addr:3000;
        }
        
        # Proxy to Open WebUI
        location /chat {
            return 301 http://$server_addr:8080;
        }
    }
}
EOF

# Create systemd service for docker-compose
print_status "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/ai-platform.service > /dev/null << 'EOF'
[Unit]
Description=AI Development Platform
After=docker.service ollama.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Start all services
print_status "🚀 Starting all services..."
cd /opt
sudo docker-compose up -d
sudo systemctl daemon-reload
sudo systemctl enable ai-platform.service

# Wait for services to start
print_status "⏳ Waiting for services to start..."
sleep 30

# Health checks
print_status "🏥 Running health checks..."
echo ""
echo "Checking Ollama..."
curl -s http://localhost:11434/api/tags | grep -q "codellama:70b-code" && echo "✅ Ollama: OK" || echo "❌ Ollama: Failed"

echo "Checking OpenHands..."
curl -s http://localhost:3000 > /dev/null && echo "✅ OpenHands: OK" || echo "❌ OpenHands: Failed"

echo "Checking Open WebUI..."
curl -s http://localhost:8080 > /dev/null && echo "✅ Open WebUI: OK" || echo "❌ Open WebUI: Failed"

echo "Checking Nginx..."
curl -s http://localhost > /dev/null && echo "✅ Nginx: OK" || echo "❌ Nginx: Failed"

# Display final information
print_status "✅ Deployment Complete!"
echo ""
echo "=========================================="
echo "🌐 Access your services:"
echo "=========================================="
echo "📍 Landing Page:    http://$SERVER_IP/"
echo "🚀 OpenHands:       http://$SERVER_IP:3000"
echo "💬 Open WebUI:      http://$SERVER_IP:8080"
echo "🤖 Ollama API:      http://$SERVER_IP:11434"
echo ""
echo "=========================================="
echo "📊 Service Ports:"
echo "=========================================="
echo "Port 80:    Landing Page (Nginx)"
echo "Port 3000:  OpenHands Frontend"
echo "Port 3001:  OpenHands Backend"
echo "Port 8080:  Open WebUI"
echo "Port 11434: Ollama API"
echo "Port 30369: OpenHands Runtime"
echo ""
echo "=========================================="
echo "🔧 Useful Commands:"
echo "=========================================="
echo "View logs:           docker-compose logs -f"
echo "Restart services:    docker-compose restart"
echo "Stop services:       docker-compose down"
echo "List models:         ollama list"
echo "Pull new model:      ollama pull <model-name>"
echo ""
echo "=========================================="
echo "💡 Tips:"
echo "=========================================="
echo "1. First-time Open WebUI users need to sign up"
echo "2. CodeLlama 70B requires ~70GB RAM for optimal performance"
echo "3. All services are accessible from outside the server"
echo "4. Firewall is configured to allow all necessary ports"
echo ""

# Show running containers
print_status "🐳 Running containers:"
sudo docker ps

# Show system resources
print_status "💻 System resources:"
free -h
df -h /
