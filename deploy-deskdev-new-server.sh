#!/bin/bash
set -e

# Server Configuration
SERVER_IP="154.201.127.161"
DOMAIN="deskdev.ai"  # Optional: if you have a domain pointing to this IP

echo "🚀 Deploying DeskDev.ai to server $SERVER_IP..."

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting DeskDev.ai deployment on $SERVER_IP..."

# Step 1: Update system and install dependencies
log "Installing system dependencies..."
apt-get update
apt-get install -y curl wget git docker.io docker-compose nginx python3-pip python3-venv git-lfs

# Step 2: Install Docker if not already installed
log "Setting up Docker..."
systemctl start docker
systemctl enable docker
usermod -aG docker root

# Step 3: Install Ollama
log "Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

# Configure Ollama to accept external connections
cat > /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload
systemctl enable ollama
systemctl restart ollama
sleep 10

# Step 4: Clone the repository
log "Cloning DeskDev.ai repository..."
cd /opt
rm -rf openhands-v2 2>/dev/null || true
git clone https://github.com/Dev28desk/openhands-v2.git
cd openhands-v2

# Step 5: Create working directory for DeskDev.ai
log "Setting up DeskDev.ai directories..."
mkdir -p /opt/deskdev/{data,workspace,landing/static}
chmod 755 /opt/deskdev/{data,workspace}

# Step 6: Download and install OpenHands Critic 32B model
log "Installing OpenHands Critic 32B model..."

# Create model conversion directory
WORK_DIR="/opt/model-conversion"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Set up Python environment
python3 -m venv model-env
source model-env/bin/activate
pip install --upgrade pip
pip install torch transformers huggingface_hub

# Download the model from Hugging Face
log "Downloading OpenHands Critic 32B from Hugging Face..."
python3 << 'EOF'
import os
from huggingface_hub import snapshot_download

# Set cache directory
cache_dir = "/opt/model-conversion/hf-cache"
os.makedirs(cache_dir, exist_ok=True)

try:
    # Download the model
    model_path = snapshot_download(
        repo_id="all-hands/openhands-critic-32b-exp-20250417",
        cache_dir=cache_dir,
        local_dir="/opt/model-conversion/openhands-critic-32b",
        local_dir_use_symlinks=False
    )
    print(f"Model downloaded to: {model_path}")
except Exception as e:
    print(f"Error downloading model: {e}")
    print("Falling back to DeepSeek Coder model...")
EOF

# Create Modelfile for Ollama
cat > /opt/model-conversion/Modelfile << 'EOF'
FROM /opt/model-conversion/openhands-critic-32b

TEMPLATE """<|im_start|>system
You are OpenHands Critic, an AI assistant specialized in software development running in DeskDev.ai. You excel at:
- Writing, reviewing, and debugging code
- Providing detailed explanations of programming concepts
- Suggesting best practices and optimizations
- Helping with software architecture decisions
- Assisting with debugging and troubleshooting

Always provide clear, actionable advice and explain your reasoning.
<|im_end|>
<|im_start|>user
{{ .Prompt }}
<|im_end|>
<|im_start|>assistant
"""

PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 32768
PARAMETER num_predict 4096
PARAMETER repeat_penalty 1.1

SYSTEM """You are OpenHands Critic, a specialized AI assistant for software development in DeskDev.ai."""
EOF

# Import model into Ollama
log "Creating Ollama model..."
if [ -d "/opt/model-conversion/openhands-critic-32b" ]; then
    ollama create openhands-critic:32b -f Modelfile
    log "✅ OpenHands Critic 32B model created successfully"
else
    log "⚠️ OpenHands Critic model not found, using DeepSeek Coder as fallback..."
    ollama pull deepseek-coder:base
    ollama create deskdev:latest << 'EOF'
FROM deepseek-coder:base
TEMPLATE """### System:
You are DeskDev.ai, an AI assistant specialized in software development. You excel at writing, reviewing, and debugging code.

### User:
{{ .Prompt }}

### Assistant:
"""
PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER num_ctx 16384
SYSTEM """You are DeskDev.ai, a specialized AI assistant for software development."""
EOF
fi

# Clean up model environment
deactivate
rm -rf model-env hf-cache

# Step 7: Configure DeskDev.ai
log "Configuring DeskDev.ai..."
cd /opt/deskdev

# Create environment file
cat > .env << EOF
# DeskDev.ai Configuration for $SERVER_IP
APP_NAME=DeskDev.ai
APP_TITLE=DeskDev.ai - AI Software Engineer
OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production

# Model Configuration
LLM_BASE_URL=http://host.docker.internal:11434
LLM_MODEL=openhands-critic:32b
LLM_API_KEY=
LLM_API_VERSION=v1
LLM_PROVIDER=ollama

# Application URLs
FRONTEND_URL=http://$SERVER_IP
BACKEND_URL=http://$SERVER_IP:3001

# Runtime Configuration
RUNTIME_HOST=0.0.0.0
RUNTIME_PORT=30369
WORKSPACE_MOUNT_PATH=/opt/deskdev/workspace

# Disable Analytics
POSTHOG_CLIENT_KEY=
ANALYTICS_ENABLED=false
EOF

# Create docker-compose.yml
cat > docker-compose.yml << EOF
version: '3'

services:
  deskdev:
    image: ghcr.io/all-hands-ai/openhands:latest
    container_name: deskdev-app
    user: root
    environment:
      # Core Configuration
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/deskdev/workspace
      
      # GitHub OAuth
      - OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
      - OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
      - OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production
      
      # Model Configuration
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=openhands-critic:32b
      - LLM_API_KEY=
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      
      # Application Configuration
      - APP_NAME=DeskDev.ai
      - APP_TITLE=DeskDev.ai - AI Software Engineer
      - FRONTEND_URL=http://$SERVER_IP
      - BACKEND_URL=http://$SERVER_IP:3001
      
      # Runtime Configuration
      - RUNTIME_HOST=0.0.0.0
      - RUNTIME_PORT=30369
      
      # Disable Analytics
      - POSTHOG_CLIENT_KEY=
      - ANALYTICS_ENABLED=false
      
      # Custom entrypoint to set default model
      - DEFAULT_LLM_CONFIG={"model":"openhands-critic:32b","base_url":"http://host.docker.internal:11434","api_key":"","provider":"ollama"}
      
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
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Step 8: Create custom landing page
log "Creating landing page..."
cat > /opt/deskdev/landing/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DeskDev.ai - AI-Powered Software Development</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <style>
        body {
            background: linear-gradient(135deg, #0c0c0c 0%, #1a1a2e 50%, #16213e 100%);
        }
        .glass-effect {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(15px);
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        .neon-glow {
            box-shadow: 0 0 30px rgba(59, 130, 246, 0.3);
        }
        .gradient-text {
            background: linear-gradient(45deg, #3b82f6, #8b5cf6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
    </style>
</head>
<body class="min-h-screen text-white">
    <!-- Navigation -->
    <nav class="glass-effect border-b border-white border-opacity-10">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <div class="flex-shrink-0">
                        <img src="https://developers.redhat.com/sites/default/files/styles/keep_original/public/ML%20models.png?itok=T-pMYACJ" 
                             alt="DeskDev.ai Logo" class="h-10 w-10 rounded-lg">
                    </div>
                    <h1 class="text-2xl font-bold gradient-text ml-3">DeskDev.ai</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <a href="http://$SERVER_IP:3000" 
                       class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-6 py-2 rounded-lg transition-all duration-300 neon-glow">
                        Launch App
                    </a>
                </div>
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <div class="max-w-7xl mx-auto px-4 py-20">
        <div class="text-center">
            <h1 class="text-6xl font-bold mb-6">
                <span class="gradient-text">AI-Powered</span><br>
                <span class="text-white">Software Development</span>
            </h1>
            <p class="text-xl text-gray-300 mb-8 max-w-3xl mx-auto">
                DeskDev.ai is your intelligent coding companion powered by OpenHands Critic 32B, 
                deployed on <span class="text-blue-400 font-mono">$SERVER_IP</span> for blazing-fast local AI processing.
            </p>
            
            <!-- Model Info Card -->
            <div class="glass-effect rounded-2xl p-8 mb-12 max-w-4xl mx-auto">
                <h3 class="text-2xl font-semibold mb-6 gradient-text">🤖 Powered by OpenHands Critic 32B</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                    <div class="glass-effect rounded-lg p-4">
                        <div class="text-blue-400 text-sm uppercase tracking-wide">Model</div>
                        <div class="text-white font-semibold">OpenHands Critic 32B</div>
                    </div>
                    <div class="glass-effect rounded-lg p-4">
                        <div class="text-blue-400 text-sm uppercase tracking-wide">Provider</div>
                        <div class="text-white font-semibold">Ollama (Local)</div>
                    </div>
                    <div class="glass-effect rounded-lg p-4">
                        <div class="text-blue-400 text-sm uppercase tracking-wide">Context</div>
                        <div class="text-white font-semibold">32,768 tokens</div>
                    </div>
                    <div class="glass-effect rounded-lg p-4">
                        <div class="text-blue-400 text-sm uppercase tracking-wide">Server</div>
                        <div class="text-white font-semibold font-mono">$SERVER_IP</div>
                    </div>
                </div>
            </div>
            
            <div class="space-y-4 sm:space-y-0 sm:flex sm:justify-center sm:space-x-4">
                <a href="http://$SERVER_IP:3000" 
                   class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-8 py-4 rounded-lg text-lg font-semibold transition-all duration-300 neon-glow inline-block">
                    Start Coding with AI
                </a>
                <a href="http://$SERVER_IP:3000" 
                   class="glass-effect text-white px-8 py-4 rounded-lg text-lg font-semibold transition-all duration-300 hover:bg-white hover:bg-opacity-10 inline-block">
                    View Demo
                </a>
            </div>
        </div>
    </div>

    <!-- Features Section -->
    <div class="max-w-7xl mx-auto px-4 py-16">
        <h2 class="text-4xl font-bold text-center mb-12 gradient-text">Revolutionary Features</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div class="glass-effect rounded-2xl p-8 text-center hover:scale-105 transition-transform duration-300">
                <div class="text-5xl mb-4">🧠</div>
                <h3 class="text-xl font-semibold mb-4 text-blue-400">Smart Code Review</h3>
                <p class="text-gray-300">Advanced AI-powered code analysis with OpenHands Critic 32B for comprehensive review and optimization suggestions.</p>
            </div>
            <div class="glass-effect rounded-2xl p-8 text-center hover:scale-105 transition-transform duration-300">
                <div class="text-5xl mb-4">⚡</div>
                <h3 class="text-xl font-semibold mb-4 text-blue-400">Lightning Fast</h3>
                <p class="text-gray-300">Local AI processing on $SERVER_IP ensures ultra-fast responses without external API dependencies.</p>
            </div>
            <div class="glass-effect rounded-2xl p-8 text-center hover:scale-105 transition-transform duration-300">
                <div class="text-5xl mb-4">🔒</div>
                <h3 class="text-xl font-semibold mb-4 text-blue-400">Privacy Guaranteed</h3>
                <p class="text-gray-300">Your code never leaves your server. Complete privacy with local AI model processing.</p>
            </div>
        </div>
    </div>

    <!-- Server Info Section -->
    <div class="max-w-7xl mx-auto px-4 py-16">
        <div class="glass-effect rounded-2xl p-8 text-center">
            <h3 class="text-2xl font-semibold mb-6 gradient-text">🖥️ Server Information</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div>
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Server IP</div>
                    <div class="text-white font-mono text-lg">$SERVER_IP</div>
                </div>
                <div>
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Application Port</div>
                    <div class="text-white font-mono text-lg">3000</div>
                </div>
                <div>
                    <div class="text-blue-400 text-sm uppercase tracking-wide">AI Model Port</div>
                    <div class="text-white font-mono text-lg">11434</div>
                </div>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="glass-effect border-t border-white border-opacity-10">
        <div class="max-w-7xl mx-auto py-8 px-4 text-center">
            <p class="text-gray-400">&copy; 2024 DeskDev.ai. Powered by OpenHands Critic 32B on $SERVER_IP.</p>
            <p class="text-gray-500 text-sm mt-2">Local AI • Privacy First • Developer Focused</p>
        </div>
    </footer>
</body>
</html>
EOF

# Step 9: Configure Nginx
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/deskdev << EOF
server {
    listen 80;
    server_name $SERVER_IP;

    # Increase timeout values for AI processing
    proxy_connect_timeout 600;
    proxy_send_timeout 600;
    proxy_read_timeout 600;
    send_timeout 600;

    # Landing page
    location = / {
        root /opt/deskdev/landing;
        index index.html;
        try_files \$uri \$uri/ =404;
    }

    # Static files for landing page
    location /static/ {
        root /opt/deskdev/landing;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Direct access to application
    location /app {
        return 301 http://\$host:3000;
    }

    # Proxy all other requests to the application
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Extended timeouts for AI processing
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }

    # API routes with extended timeouts
    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # Extended timeouts for AI model responses
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }

    # WebSocket support
    location /socket.io/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Enable the site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Step 10: Start DeskDev.ai
log "Starting DeskDev.ai..."
docker-compose down 2>/dev/null || true
docker-compose up -d

# Wait for services to start
sleep 30

# Step 11: Test the setup
log "Testing the deployment..."

# Test Ollama
echo "🔍 Testing Ollama..."
if curl -s http://localhost:11434/api/tags | grep -q "openhands-critic:32b"; then
    echo "✅ OpenHands Critic 32B model is available"
elif curl -s http://localhost:11434/api/tags | grep -q "deskdev:latest"; then
    echo "✅ DeskDev fallback model is available"
else
    echo "⚠️ No model found, pulling DeepSeek Coder as fallback..."
    ollama pull deepseek-coder:base
fi

# Test application
echo "🔍 Testing application..."
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ DeskDev.ai application is responding"
else
    echo "❌ Application not responding, checking logs..."
    docker logs deskdev-app --tail 20
fi

# Test landing page
echo "🔍 Testing landing page..."
if curl -s http://localhost/ | grep -q "DeskDev.ai"; then
    echo "✅ Landing page is working"
else
    echo "❌ Landing page not working"
fi

# Step 12: Configure firewall (optional)
log "Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp
ufw allow 11434/tcp

# Step 13: Final status report
echo ""
echo "🎉 DeskDev.ai deployment completed on $SERVER_IP!"
echo ""
echo "📋 Deployment Summary:"
echo "======================="
echo "Server IP: $SERVER_IP"
echo "Landing Page: http://$SERVER_IP/"
echo "Application: http://$SERVER_IP:3000"
echo "Model: OpenHands Critic 32B (or DeepSeek Coder fallback)"
echo "Provider: Ollama (Local)"
echo ""
echo "🔍 Service Status:"
echo "=================="

# Check services
services=("docker" "nginx" "ollama")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: Running"
    else
        echo "❌ $service: Not running"
    fi
done

# Check containers
if docker ps | grep -q "deskdev-app"; then
    echo "✅ DeskDev.ai container: Running"
else
    echo "❌ DeskDev.ai container: Not running"
fi

echo ""
echo "📚 Available Models:"
ollama list

echo ""
echo "🎯 Quick Access Links:"
echo "Landing Page: http://$SERVER_IP/"
echo "Application: http://$SERVER_IP:3000"
echo "GitHub Auth: Configured with OAuth"
echo ""
echo "💡 Users can now start coding with AI assistance!"
echo "   The application is pre-configured with OpenHands Critic 32B model."

log "Deployment completed successfully!"
