#!/bin/bash
set -e

echo "🔧 Fixing Open WebUI and Landing Page Issues"
echo "==========================================="

# Check what's currently running
echo "📊 Checking current Docker containers..."
sudo docker ps -a

# Check if ports are in use
echo ""
echo "🔍 Checking port usage..."
sudo netstat -tlnp | grep -E ':(80|8080|3000|11434)' || echo "No services found on expected ports"

# Stop all containers
echo ""
echo "🛑 Stopping all containers..."
cd /opt
sudo docker-compose down 2>/dev/null || true

# Remove old containers
sudo docker rm -f nginx-proxy open-webui openhands 2>/dev/null || true

# Fix permissions
echo ""
echo "🔐 Fixing permissions..."
sudo chmod -R 755 /opt
sudo chown -R $USER:$USER /opt 2>/dev/null || true

# Create a simpler setup without Nginx first
echo ""
echo "📝 Creating simplified Docker Compose configuration..."
sudo tee /opt/docker-compose-simple.yml > /dev/null << 'EOF'
version: '3.8'

services:
  # OpenHands
  openhands:
    image: ghcr.io/all-hands-ai/openhands:latest
    container_name: openhands
    restart: unless-stopped
    user: root
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/workspace_base
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=codellama:70b-code
      - LLM_PROVIDER=ollama
      - DISABLE_ANALYTICS=true
    ports:
      - "3000:3000"
      - "3001:3001"
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
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - WEBUI_SECRET_KEY=your-secret-key-change-this
      - ENABLE_SIGNUP=true
    ports:
      - "8080:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /opt/open-webui/data:/app/backend/data
EOF

# Start services with simple configuration
echo ""
echo "🚀 Starting services with simplified configuration..."
cd /opt
sudo docker-compose -f docker-compose-simple.yml up -d

# Wait for services to start
echo ""
echo "⏳ Waiting for services to start (30 seconds)..."
sleep 30

# Check container status
echo ""
echo "📊 Container status:"
sudo docker ps

# Test services
echo ""
echo "🧪 Testing services..."
echo -n "OpenHands (port 3000): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "Failed"

echo -n "Open WebUI (port 8080): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "Failed"

echo -n "Ollama (port 11434): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags || echo "Failed"

# Create a simple landing page with Python
echo ""
echo "🌐 Creating simple landing page server..."
sudo tee /opt/landing.py > /dev/null << 'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>AI Development Platform</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #1a1a1a;
            color: white;
            text-align: center;
            padding: 50px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        h1 {
            color: #667eea;
            font-size: 3em;
            margin-bottom: 30px;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 50px;
        }
        .service {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            text-decoration: none;
            color: white;
            transition: all 0.3s;
        }
        .service:hover {
            background: rgba(255,255,255,0.2);
            transform: translateY(-5px);
        }
        .service h2 {
            color: #667eea;
            margin-bottom: 10px;
        }
        .status {
            margin-top: 50px;
            padding: 20px;
            background: rgba(0,255,0,0.1);
            border-radius: 10px;
        }
        a {
            color: #667eea;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>AI Development Platform</h1>
        <p>Your AI-powered development environment</p>
        
        <div class="services">
            <a href="http://154.201.127.161:3000" class="service">
                <h2>🚀 OpenHands</h2>
                <p>AI Software Development Assistant</p>
            </a>
            
            <a href="http://154.201.127.161:8080" class="service">
                <h2>💬 Open WebUI</h2>
                <p>Chat with CodeLlama 70B</p>
            </a>
            
            <a href="http://154.201.127.161:11434" class="service">
                <h2>🤖 Ollama API</h2>
                <p>Direct Model Access</p>
            </a>
        </div>
        
        <div class="status">
            <h3>✅ Services Status</h3>
            <p>Server: 154.201.127.161</p>
            <p>Model: codellama:70b-code</p>
        </div>
    </div>
</body>
</html>
"""

class MyHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html_content.encode())

if __name__ == '__main__':
    os.chdir('/opt')
    httpd = HTTPServer(('0.0.0.0', 80), MyHandler)
    print("Landing page server running on port 80...")
    httpd.serve_forever()
EOF

# Make it executable
sudo chmod +x /opt/landing.py

# Kill any process using port 80
sudo fuser -k 80/tcp 2>/dev/null || true

# Start landing page in background
echo ""
echo "🚀 Starting landing page server..."
sudo python3 /opt/landing.py > /opt/landing.log 2>&1 &

# Create systemd service for landing page
sudo tee /etc/systemd/system/landing-page.service > /dev/null << 'EOF'
[Unit]
Description=AI Platform Landing Page
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/landing.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable landing-page.service
sudo systemctl restart landing-page.service

# Check all services
echo ""
echo "✅ Services should now be available at:"
echo "=========================================="
echo "🌐 Landing Page: http://154.201.127.161/"
echo "🚀 OpenHands:    http://154.201.127.161:3000"
echo "💬 Open WebUI:   http://154.201.127.161:8080"
echo "🤖 Ollama API:   http://154.201.127.161:11434"
echo "=========================================="

# Show logs if there are issues
echo ""
echo "📋 Recent Docker logs:"
echo "=========================================="
sudo docker logs openhands --tail 10 2>&1 || echo "OpenHands logs not available"
echo "------------------------------------------"
sudo docker logs open-webui --tail 10 2>&1 || echo "Open WebUI logs not available"

# Final status check
echo ""
echo "🔍 Final status check:"
sudo docker ps
