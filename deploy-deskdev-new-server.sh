#!/bin/bash
set -e

# Server Configuration
SERVER_IP="154.201.127.161"
DESKDEV_PORT="4000"
DESKDEV_API_PORT="4001"

echo "🚀 Deploying DeskDev.ai alongside existing OpenHands and OpenWebUI..."

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting DeskDev.ai deployment on $SERVER_IP (Port $DESKDEV_PORT)..."

# Step 1: Check existing services
log "Checking existing services..."
echo "📊 Current service status:"
echo "   OpenHands (port 3000): $(curl -s http://localhost:3000 >/dev/null && echo '✅ Running' || echo '❌ Not responding')"
echo "   OpenWebUI (port 8080): $(curl -s http://localhost:8080 >/dev/null && echo '✅ Running' || echo '❌ Not responding')"

# Step 2: Install dependencies if needed
log "Checking and installing dependencies..."
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl start docker
    systemctl enable docker
fi

# Step 3: Fix OpenWebUI if it's not working
log "Attempting to fix OpenWebUI on port 8080..."
if ! curl -s http://localhost:8080 >/dev/null; then
    log "OpenWebUI not responding, attempting to restart..."
    
    # Try to find and restart OpenWebUI container
    OPENWEBUI_CONTAINER=$(docker ps -a | grep -i "webui\|open-webui" | awk '{print $1}' | head -1)
    if [ ! -z "$OPENWEBUI_CONTAINER" ]; then
        log "Found OpenWebUI container: $OPENWEBUI_CONTAINER"
        docker restart $OPENWEBUI_CONTAINER
        sleep 10
    else
        log "No OpenWebUI container found, deploying a new one..."
        docker run -d --name open-webui-fixed \
            -p 8080:8080 \
            -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
            -v open-webui:/app/backend/data \
            --add-host=host.docker.internal:host-gateway \
            --restart unless-stopped \
            ghcr.io/open-webui/open-webui:main
    fi
fi

# Step 4: Install/Configure Ollama if needed
if ! command -v ollama &> /dev/null; then
    log "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Configure Ollama
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
    
    # Pull DeepSeek Coder model
    log "Pulling DeepSeek Coder model..."
    ollama pull deepseek-coder:base
fi

# Create DeskDev custom model if it doesn't exist
if ! ollama list | grep -q "deskdev:latest"; then
    log "Creating DeskDev custom model..."
    ollama create deskdev:latest << 'EOF'
FROM deepseek-coder:base

TEMPLATE """### System:
You are DeskDev.ai, an advanced AI assistant specialized in software development running on 154.201.127.161:4000. You excel at:
- Writing, reviewing, and debugging code
- Providing detailed explanations of programming concepts
- Suggesting best practices and optimizations
- Helping with software architecture decisions
- Assisting with debugging and troubleshooting

Always provide clear, actionable advice and explain your reasoning.

### User:
{{ .Prompt }}

### Assistant:
"""

PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 16384
PARAMETER num_predict 4096
PARAMETER repeat_penalty 1.1

SYSTEM """You are DeskDev.ai, running on 154.201.127.161:4000, working alongside OpenHands (port 3000) and OpenWebUI (port 8080)."""
EOF
fi

# Step 5: Setup DeskDev.ai directories
log "Setting up DeskDev.ai directories..."
mkdir -p /opt/deskdev-ai/{data,workspace,landing}
chmod 755 /opt/deskdev-ai/{data,workspace}

# Step 6: Configure DeskDev.ai
log "Configuring DeskDev.ai..."
cd /opt/deskdev-ai

# Create environment file
cat > .env << EOF
# DeskDev.ai Configuration (Port $DESKDEV_PORT)
APP_NAME=DeskDev.ai
APP_TITLE=DeskDev.ai - AI Software Engineer
OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production

# Model Configuration
LLM_BASE_URL=http://host.docker.internal:11434
LLM_MODEL=deskdev:latest
LLM_API_KEY=
LLM_API_VERSION=v1
LLM_PROVIDER=ollama

# Application URLs
FRONTEND_URL=http://$SERVER_IP:$DESKDEV_PORT
BACKEND_URL=http://$SERVER_IP:$DESKDEV_API_PORT

# Runtime Configuration
RUNTIME_HOST=0.0.0.0
RUNTIME_PORT=30370
WORKSPACE_MOUNT_PATH=/opt/deskdev-ai/workspace

# Disable Analytics
POSTHOG_CLIENT_KEY=
ANALYTICS_ENABLED=false
EOF

# Create docker-compose.yml
cat > docker-compose.yml << EOF
version: '3'

services:
  deskdev-ai:
    image: ghcr.io/all-hands-ai/openhands:latest
    container_name: deskdev-ai-app
    user: root
    environment:
      # Core Configuration
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/deskdev-ai/workspace
      
      # GitHub OAuth
      - OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
      - OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
      - OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production
      
      # Model Configuration
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=deskdev:latest
      - LLM_API_KEY=
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      
      # Application Configuration
      - APP_NAME=DeskDev.ai
      - APP_TITLE=DeskDev.ai - AI Software Engineer
      - FRONTEND_URL=http://$SERVER_IP:$DESKDEV_PORT
      - BACKEND_URL=http://$SERVER_IP:$DESKDEV_API_PORT
      
      # Runtime Configuration
      - RUNTIME_HOST=0.0.0.0
      - RUNTIME_PORT=30370
      
      # Disable Analytics
      - POSTHOG_CLIENT_KEY=
      - ANALYTICS_ENABLED=false
      
    ports:
      - "$DESKDEV_PORT:3000"
      - "$DESKDEV_API_PORT:3001"
      - "30370:30370"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/deskdev-ai/data:/.openhands
      - /opt/deskdev-ai/workspace:/opt/workspace_base
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Step 7: Create landing page that shows all services
log "Creating comprehensive landing page..."
cat > /opt/deskdev-ai/landing/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Development Hub - $SERVER_IP</title>
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
        .service-card {
            transition: all 0.3s ease;
        }
        .service-card:hover {
            transform: translateY(-8px);
            box-shadow: 0 20px 40px rgba(59, 130, 246, 0.3);
        }
    </style>
</head>
<body class="min-h-screen text-white">
    <!-- Navigation -->
    <nav class="glass-effect border-b border-white border-opacity-10">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <h1 class="text-2xl font-bold gradient-text">AI Development Hub</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <span class="text-gray-300 font-mono">$SERVER_IP</span>
                </div>
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <div class="max-w-7xl mx-auto px-4 py-12">
        <div class="text-center mb-12">
            <h1 class="text-5xl font-bold mb-6">
                <span class="gradient-text">AI Development</span><br>
                <span class="text-white">Multi-Platform Hub</span>
            </h1>
            <p class="text-xl text-gray-300 mb-8 max-w-3xl mx-auto">
                Your complete AI development environment with multiple specialized platforms 
                running on <span class="text-blue-400 font-mono">$SERVER_IP</span>
            </p>
        </div>

        <!-- Services Grid -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-12">
            <!-- DeskDev.ai Card -->
            <div class="service-card glass-effect rounded-2xl p-8 text-center">
                <div class="text-6xl mb-4">🚀</div>
                <h3 class="text-2xl font-semibold mb-4 gradient-text">DeskDev.ai</h3>
                <p class="text-gray-300 mb-6">Advanced AI coding assistant with custom DeepSeek model optimized for software development.</p>
                <div class="space-y-2 mb-6">
                    <div class="text-sm text-gray-400">Port: $DESKDEV_PORT</div>
                    <div class="text-sm text-gray-400">Model: DeskDev Custom</div>
                    <div class="text-sm text-gray-400">Status: <span id="deskdev-status" class="text-yellow-400">Checking...</span></div>
                </div>
                <a href="http://$SERVER_IP:$DESKDEV_PORT" 
                   class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-6 py-3 rounded-lg transition-all duration-300 neon-glow inline-block">
                    Launch DeskDev.ai
                </a>
            </div>

            <!-- OpenHands Card -->
            <div class="service-card glass-effect rounded-2xl p-8 text-center">
                <div class="text-6xl mb-4">🤖</div>
                <h3 class="text-2xl font-semibold mb-4 text-green-400">OpenHands</h3>
                <p class="text-gray-300 mb-6">Original OpenHands AI software engineer for autonomous coding and development tasks.</p>
                <div class="space-y-2 mb-6">
                    <div class="text-sm text-gray-400">Port: 3000</div>
                    <div class="text-sm text-gray-400">Type: AI Agent</div>
                    <div class="text-sm text-gray-400">Status: <span id="openhands-status" class="text-yellow-400">Checking...</span></div>
                </div>
                <a href="http://$SERVER_IP:3000" 
                   class="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 text-white px-6 py-3 rounded-lg transition-all duration-300 inline-block">
                    Launch OpenHands
                </a>
            </div>

            <!-- OpenWebUI Card -->
            <div class="service-card glass-effect rounded-2xl p-8 text-center">
                <div class="text-6xl mb-4">💬</div>
                <h3 class="text-2xl font-semibold mb-4 text-orange-400">OpenWebUI</h3>
                <p class="text-gray-300 mb-6">Chat interface for interacting with local AI models through a web-based UI.</p>
                <div class="space-y-2 mb-6">
                    <div class="text-sm text-gray-400">Port: 8080</div>
                    <div class="text-sm text-gray-400">Type: Chat Interface</div>
                    <div class="text-sm text-gray-400">Status: <span id="openwebui-status" class="text-yellow-400">Checking...</span></div>
                </div>
                <a href="http://$SERVER_IP:8080" 
                   class="bg-gradient-to-r from-orange-600 to-red-600 hover:from-orange-700 hover:to-red-700 text-white px-6 py-3 rounded-lg transition-all duration-300 inline-block">
                    Launch OpenWebUI
                </a>
            </div>
        </div>

        <!-- System Information -->
        <div class="glass-effect rounded-2xl p-8 mb-8">
            <h3 class="text-2xl font-semibold mb-6 gradient-text text-center">🖥️ System Information</h3>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Server IP</div>
                    <div class="text-white font-mono text-lg">$SERVER_IP</div>
                </div>
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">AI Model Provider</div>
                    <div class="text-white font-semibold">Ollama (Port 11434)</div>
                </div>
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Active Services</div>
                    <div class="text-white font-semibold" id="active-services">3</div>
                </div>
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Processing</div>
                    <div class="text-white font-semibold">Local (Private)</div>
                </div>
            </div>
        </div>

        <!-- Quick Actions -->
        <div class="glass-effect rounded-2xl p-8">
            <h3 class="text-2xl font-semibold mb-6 gradient-text text-center">⚡ Quick Actions</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <button onclick="checkAllServices()" 
                        class="glass-effect text-white px-4 py-3 rounded-lg hover:bg-white hover:bg-opacity-10 transition-all duration-300">
                    🔄 Refresh Status
                </button>
                <a href="http://$SERVER_IP:11434/api/tags" target="_blank"
                   class="glass-effect text-white px-4 py-3 rounded-lg hover:bg-white hover:bg-opacity-10 transition-all duration-300 text-center">
                    📋 View Models
                </a>
                <button onclick="window.location.reload()" 
                        class="glass-effect text-white px-4 py-3 rounded-lg hover:bg-white hover:bg-opacity-10 transition-all duration-300">
                    🔄 Reload Page
                </button>
                <a href="http://$SERVER_IP:$DESKDEV_PORT" 
                   class="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-4 py-3 rounded-lg hover:from-blue-700 hover:to-purple-700 transition-all duration-300 text-center">
                    🚀 Start Coding
                </a>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="glass-effect border-t border-white border-opacity-10">
        <div class="max-w-7xl mx-auto py-8 px-4 text-center">
            <p class="text-gray-400">&copy; 2024 AI Development Hub on $SERVER_IP</p>
            <p class="text-gray-500 text-sm mt-2">DeskDev.ai • OpenHands • OpenWebUI • Local AI Processing</p>
        </div>
    </footer>

    <script>
        // Check service status
        async function checkService(url, statusElementId) {
            try {
                const response = await fetch(url, { method: 'HEAD', mode: 'no-cors' });
                document.getElementById(statusElementId).innerHTML = '<span class="text-green-400">✅ Online</span>';
                return true;
            } catch (error) {
                document.getElementById(statusElementId).innerHTML = '<span class="text-red-400">❌ Offline</span>';
                return false;
            }
        }

        async function checkAllServices() {
            const services = [
                { url: 'http://$SERVER_IP:$DESKDEV_PORT', id: 'deskdev-status' },
                { url: 'http://$SERVER_IP:3000', id: 'openhands-status' },
                { url: 'http://$SERVER_IP:8080', id: 'openwebui-status' }
            ];

            let activeCount = 0;
            for (const service of services) {
                if (await checkService(service.url, service.id)) {
                    activeCount++;
                }
            }
            
            document.getElementById('active-services').textContent = activeCount;
        }

        // Check services on page load
        window.onload = function() {
            setTimeout(checkAllServices, 1000);
        };
    </script>
</body>
</html>
EOF

# Step 8: Configure Nginx for all services
log "Configuring Nginx for all services..."
apt-get install -y nginx

cat > /etc/nginx/sites-available/ai-hub << EOF
server {
    listen 80;
    server_name $SERVER_IP;

    # Main landing page
    location = / {
        root /opt/deskdev-ai/landing;
        index index.html;
    }

    # DeskDev.ai routes
    location /deskdev {
        return 301 http://\$host:$DESKDEV_PORT;
    }

    # OpenHands routes  
    location /openhands {
        return 301 http://\$host:3000;
    }

    # OpenWebUI routes
    location /openwebui {
        return 301 http://\$host:8080;
    }

    # Direct service access
    location /api/ {
        proxy_pass http://localhost:$DESKDEV_API_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Enable the site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ai-hub /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Step 9: Start DeskDev.ai
log "Starting DeskDev.ai..."
docker compose down 2>/dev/null || true
docker compose up -d

# Wait for services to start
sleep 30

# Step 10: Final status check
log "Checking all services..."
echo ""
echo "🎉 AI Development Hub deployment completed!"
echo ""
echo "📊 Service Status:"
echo "=================="

# Check each service
services=(
    "DeskDev.ai:$DESKDEV_PORT"
    "OpenHands:3000"
    "OpenWebUI:8080"
    "Ollama:11434"
)

for service in "${services[@]}"; do
    name="${service%:*}"
    port="${service#*:}"
    if curl -s http://localhost:$port >/dev/null 2>&1; then
        echo "✅ $name (port $port): Online"
    else
        echo "❌ $name (port $port): Offline"
    fi
done

echo ""
echo "🌐 Access Points:"
echo "================"
echo "🏠 Main Hub:      http://$SERVER_IP/"
echo "🚀 DeskDev.ai:    http://$SERVER_IP:$DESKDEV_PORT"
echo "🤖 OpenHands:     http://$SERVER_IP:3000"
echo "💬 OpenWebUI:     http://$SERVER_IP:8080"
echo ""

# Show available models
echo "📚 Available AI Models:"
ollama list

echo ""
echo "💡 All services are now configured to work together!"
echo "   Visit http://$SERVER_IP/ to access the main hub."

log "Deployment completed successfully!"
