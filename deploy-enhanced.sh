#!/bin/bash
set -e

echo "🚀 Deploying DeskDev.ai Enhanced Version..."

# Configuration
VPS_IP="31.97.61.137"
VPS_USER="root"
GITHUB_REPO="https://github.com/Dev28desk/openhands-v2.git"

echo "📋 Deployment Configuration:"
echo "   VPS IP: $VPS_IP"
echo "   User: $VPS_USER"
echo "   Repository: $GITHUB_REPO"
echo ""

# Function to run commands on VPS
run_on_vps() {
    ssh -o StrictHostKeyChecking=no $VPS_USER@$VPS_IP "$1"
}

# Function to copy files to VPS
copy_to_vps() {
    scp -o StrictHostKeyChecking=no -r "$1" $VPS_USER@$VPS_IP:"$2"
}

echo "🔧 Installing Ollama on VPS..."
run_on_vps "curl -fsSL https://ollama.ai/install.sh | sh"

echo "⚙️ Configuring Ollama..."
run_on_vps "sudo systemctl edit ollama --force --full << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment=\"OLLAMA_HOST=0.0.0.0:11434\"

[Install]
WantedBy=default.target
EOF"

run_on_vps "sudo systemctl daemon-reload && sudo systemctl enable ollama && sudo systemctl restart ollama"

echo "📥 Pulling DeepSeek Coder model..."
run_on_vps "sleep 5 && ollama pull deepseek-coder:base"

echo "📂 Setting up application directory..."
run_on_vps "mkdir -p /opt/deskdev/{data,workspace} && chmod 755 /opt/deskdev/{data,workspace}"

echo "📦 Cloning repository..."
run_on_vps "cd /opt && rm -rf openhands-v2 && git clone $GITHUB_REPO"

echo "🏗️ Building DeskDev.ai Enhanced image..."
run_on_vps "cd /opt/openhands-v2 && docker build -t deskdev:enhanced -f Dockerfile.enhanced ."

echo "🚀 Starting DeskDev.ai services..."
run_on_vps "cd /opt/openhands-v2 && cp docker-compose.enhanced.yml /opt/deskdev/docker-compose.yml"
run_on_vps "cd /opt/deskdev && docker-compose down 2>/dev/null || true && docker-compose up -d"

echo "⏳ Waiting for services to start..."
sleep 15

echo "🔍 Checking deployment status..."
run_on_vps "docker ps"
run_on_vps "curl -s http://localhost:11434/api/tags | grep deepseek || echo 'Ollama model check failed'"

echo ""
echo "✅ DeskDev.ai Enhanced deployment completed!"
echo ""
echo "🌐 Access your application at: http://$VPS_IP"
echo ""
echo "📋 Features included:"
echo "   ✅ Landing page with GitHub authentication"
echo "   ✅ Pre-configured Ollama with DeepSeek Coder"
echo "   ✅ Complete DeskDev.ai branding"
echo "   ✅ Auto-configured LLM settings"
echo "   ✅ User database and session management"
echo ""
echo "🔧 To check logs: ssh $VPS_USER@$VPS_IP 'docker logs deskdev-app'"
echo "🔧 To restart: ssh $VPS_USER@$VPS_IP 'cd /opt/deskdev && docker-compose restart'"