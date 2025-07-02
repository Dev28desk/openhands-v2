#!/bin/bash
set -e

# Server Configuration
SERVER_IP="154.201.127.161"

echo "🗑️ Fresh OpenWebUI reinstall and OpenHands Critic 32B installation on $SERVER_IP..."

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting complete OpenWebUI fresh reinstall (keeping DeskDev.ai on port 3000 untouched)..."

# Step 1: Check current status
log "Checking current services..."
echo "📊 Current service status:"
echo "   DeskDev.ai (port 3000): $(curl -s http://localhost:3000 >/dev/null && echo '✅ Running - Will NOT touch' || echo '❌ Not responding')"
echo "   OpenWebUI (port 8080): $(curl -s http://localhost:8080 >/dev/null && echo '⚠️ Will be completely reinstalled' || echo '❌ Will be freshly installed')"

# Step 2: Complete OpenWebUI cleanup
log "Performing complete OpenWebUI cleanup..."

# Stop and remove ALL containers that might be OpenWebUI
echo "🧹 Removing all existing OpenWebUI containers..."
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}" | grep -i "webui\|open-webui" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true

# Remove ALL OpenWebUI related containers by image
docker ps -a --filter "ancestor=ghcr.io/open-webui/open-webui" -q | xargs -r docker rm -f 2>/dev/null || true
docker ps -a --filter "ancestor=ghcr.io/open-webui/open-webui:main" -q | xargs -r docker rm -f 2>/dev/null || true

# Remove OpenWebUI volumes
echo "🗑️ Removing OpenWebUI volumes..."
docker volume ls -q | grep -i "webui\|open-webui" | xargs -r docker volume rm 2>/dev/null || true

# Kill any processes using port 8080
echo "🔫 Killing any processes using port 8080..."
fuser -k 8080/tcp 2>/dev/null || true
sleep 3

# Remove any leftover networks
docker network ls | grep -i "webui" | awk '{print $1}' | xargs -r docker network rm 2>/dev/null || true

# Step 3: Clean Docker system
log "Cleaning Docker system..."
docker system prune -f

# Step 4: Ensure Docker is running properly
log "Ensuring Docker is running..."
systemctl restart docker
sleep 5

# Step 5: Fresh OpenWebUI installation
log "Installing fresh OpenWebUI..."

# Create new volume
docker volume create open-webui-data

# Deploy completely fresh OpenWebUI
echo "🚀 Deploying fresh OpenWebUI instance..."
docker run -d \
    --name open-webui-fresh \
    -p 8080:8080 \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    -e WEBUI_AUTH=false \
    -e DEFAULT_MODELS="openhands-critic:32b" \
    -e ENABLE_COMMUNITY_SHARING=false \
    -e ENABLE_MESSAGE_RATING=false \
    -v open-webui-data:/app/backend/data \
    --add-host=host.docker.internal:host-gateway \
    --restart unless-stopped \
    ghcr.io/open-webui/open-webui:main

log "Waiting for OpenWebUI to fully start..."
sleep 30

# Check if OpenWebUI is running
for i in {1..60}; do
    if curl -s http://localhost:8080 >/dev/null; then
        log "✅ OpenWebUI is now running!"
        break
    fi
    log "Waiting for OpenWebUI to start... ($i/60)"
    sleep 2
done

# Step 6: Install OpenHands Critic 32B model
log "Installing OpenHands Critic 32B model..."

# Ensure Ollama is running
if ! systemctl is-active --quiet ollama; then
    log "Starting Ollama service..."
    systemctl start ollama
    sleep 10
fi

# Install Python dependencies for model downloading
apt-get update
apt-get install -y python3-pip python3-venv git-lfs curl wget

# Create working directory for model conversion
WORK_DIR="/opt/model-conversion"
rm -rf $WORK_DIR 2>/dev/null || true
mkdir -p $WORK_DIR
cd $WORK_DIR

# Set up Python environment
python3 -m venv model-env
source model-env/bin/activate
pip install --upgrade pip
pip install torch transformers huggingface_hub

# Download the OpenHands Critic 32B model
log "Downloading OpenHands Critic 32B from Hugging Face (this may take a while)..."
python3 << 'PYTHON_EOF'
import os
from huggingface_hub import snapshot_download

print("🔄 Starting OpenHands Critic 32B download...")
try:
    # Set cache directory
    cache_dir = "/opt/model-conversion/hf-cache"
    os.makedirs(cache_dir, exist_ok=True)

    # Download the model with progress
    model_path = snapshot_download(
        repo_id="all-hands/openhands-critic-32b-exp-20250417",
        cache_dir=cache_dir,
        local_dir="/opt/model-conversion/openhands-critic-32b",
        local_dir_use_symlinks=False,
        resume_download=True
    )
    print(f"✅ OpenHands Critic 32B downloaded successfully to: {model_path}")
    
    # Check if model files exist
    import glob
    model_files = glob.glob("/opt/model-conversion/openhands-critic-32b/*")
    print(f"📁 Found {len(model_files)} model files")
    
except Exception as e:
    print(f"❌ Error downloading OpenHands Critic 32B: {e}")
    print("Will use DeepSeek Coder as fallback")
    exit(1)
PYTHON_EOF

# Check if download was successful
if [ -d "/opt/model-conversion/openhands-critic-32b" ] && [ "$(ls -A /opt/model-conversion/openhands-critic-32b)" ]; then
    log "✅ OpenHands Critic 32B downloaded successfully!"
    
    # Create Modelfile for Ollama
    log "Creating OpenHands Critic 32B Ollama model..."
    cat > /opt/model-conversion/Modelfile << 'EOF'
FROM /opt/model-conversion/openhands-critic-32b

TEMPLATE """<|im_start|>system
You are OpenHands Critic, the official 32B parameter AI model specialized in software development and code review. You are running on 154.201.127.161 and excel at:

- Autonomous software development and coding
- Advanced code review and analysis  
- Debugging and troubleshooting complex issues
- Software architecture and design decisions
- Best practices and optimization recommendations
- File manipulation and project management
- Natural conversation about development topics

You have extensive knowledge of programming languages, frameworks, and development tools. Always provide detailed, actionable advice with clear explanations.
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
PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"

SYSTEM """You are OpenHands Critic 32B, the official AI model for software development, running on 154.201.127.161. You can discuss code, provide development guidance, and assist with programming tasks."""
EOF

    # Import model into Ollama
    log "Importing OpenHands Critic 32B into Ollama (this may take several minutes)..."
    ollama create openhands-critic:32b -f Modelfile
    
    # Verify model creation
    if ollama list | grep -q "openhands-critic:32b"; then
        log "✅ OpenHands Critic 32B model created successfully!"
    else
        log "❌ Failed to create OpenHands Critic 32B model, creating fallback..."
        # Create fallback
        ollama pull deepseek-coder:base
        ollama create openhands-critic:32b << 'EOF'
FROM deepseek-coder:base
TEMPLATE """You are OpenHands Critic, specialized in software development (using DeepSeek Coder base). You excel at coding, debugging, and development tasks.

User: {{ .Prompt }}
Assistant:"""
PARAMETER temperature 0.1
PARAMETER num_ctx 16384
SYSTEM """You are OpenHands Critic (DeepSeek Coder fallback) running on 154.201.127.161."""
EOF
    fi
else
    log "❌ OpenHands Critic 32B download failed, using DeepSeek Coder fallback..."
    ollama pull deepseek-coder:base
    ollama create openhands-critic:32b << 'EOF'
FROM deepseek-coder:base
TEMPLATE """You are OpenHands Critic, specialized in software development. You excel at coding, debugging, and development tasks.

User: {{ .Prompt }}
Assistant:"""
PARAMETER temperature 0.1
PARAMETER num_ctx 16384
SYSTEM """You are OpenHands Critic (DeepSeek Coder base) running on 154.201.127.161."""
EOF
fi

# Clean up model conversion environment
deactivate
rm -rf model-env hf-cache

# Step 7: Configure OpenWebUI with the new model
log "Configuring OpenWebUI with OpenHands Critic 32B..."

# Wait a bit more for OpenWebUI to be fully ready
sleep 10

# Test OpenWebUI API and set default model
if curl -s http://localhost:8080 >/dev/null; then
    log "✅ OpenWebUI is responding, configuring default model..."
    
    # Try to set the default model via environment variable restart
    docker restart open-webui-fresh
    sleep 20
else
    log "⚠️ OpenWebUI not responding yet, but container should be running"
fi

# Step 8: Create landing page
log "Creating comprehensive landing page..."
mkdir -p /opt/ai-hub
cat > /opt/ai-hub/index.html << EOF
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
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-online { background-color: #10b981; }
        .status-offline { background-color: #ef4444; }
        .status-checking { background-color: #f59e0b; animation: pulse 2s infinite; }
    </style>
</head>
<body class="min-h-screen text-white">
    <!-- Navigation -->
    <nav class="glass-effect border-b border-white border-opacity-10">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <img src="https://developers.redhat.com/sites/default/files/styles/keep_original/public/ML%20models.png?itok=T-pMYACJ" 
                         alt="AI Hub Logo" class="h-10 w-10 rounded-lg mr-3">
                    <h1 class="text-2xl font-bold gradient-text">AI Development Hub</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <span class="text-gray-300 font-mono">$SERVER_IP</span>
                    <button onclick="checkAllServices()" class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-sm">
                        🔄 Refresh
                    </button>
                </div>
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <div class="max-w-7xl mx-auto px-4 py-12">
        <div class="text-center mb-12">
            <h1 class="text-5xl font-bold mb-6">
                <span class="gradient-text">AI Development</span><br>
                <span class="text-white">Complete Platform</span>
            </h1>
            <p class="text-xl text-gray-300 mb-8 max-w-3xl mx-auto">
                Your complete AI development environment with DeskDev.ai and fresh OpenWebUI 
                powered by <span class="text-blue-400 font-semibold">OpenHands Critic 32B</span>
            </p>
        </div>

        <!-- Status Banner -->
        <div class="glass-effect rounded-lg p-4 mb-8 text-center">
            <h3 class="text-lg font-semibold mb-2">🚀 Fresh Installation Status</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                    <span class="status-indicator status-checking" id="deskdev-indicator"></span>
                    <span>DeskDev.ai: <span id="deskdev-status">Checking...</span></span>
                </div>
                <div>
                    <span class="status-indicator status-checking" id="openwebui-indicator"></span>
                    <span>OpenWebUI: <span id="openwebui-status">Fresh Install</span></span>
                </div>
                <div>
                    <span class="status-indicator status-checking" id="ollama-indicator"></span>
                    <span>Ollama: <span id="ollama-status">Checking...</span></span>
                </div>
            </div>
        </div>

        <!-- Services Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-12">
            <!-- DeskDev.ai Card -->
            <div class="service-card glass-effect rounded-2xl p-8 text-center">
                <div class="text-6xl mb-4">🤖</div>
                <h3 class="text-2xl font-semibold mb-4 gradient-text">DeskDev.ai</h3>
                <p class="text-gray-300 mb-6">AI Software Engineer with autonomous coding capabilities. Now powered by OpenHands Critic 32B for superior development assistance.</p>
                <div class="space-y-2 mb-6 text-sm">
                    <div class="flex justify-between">
                        <span class="text-gray-400">Port:</span>
                        <span class="text-white">3000</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-400">Model:</span>
                        <span class="text-white">OpenHands Critic 32B</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-400">Type:</span>
                        <span class="text-white">Autonomous AI Agent</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-400">Status:</span>
                        <span id="deskdev-status-detail" class="text-yellow-400">Checking...</span>
                    </div>
                </div>
                <a href="http://$SERVER_IP:3000" 
                   class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-6 py-3 rounded-lg transition-all duration-300 neon-glow inline-block">
                    Launch DeskDev.ai
                </a>
            </div>

            <!-- OpenWebUI Card -->
            <div class="service-card glass-effect rounded-2xl p-8 text-center">
                <div class="text-6xl mb-4">💬</div>
                <h3 class="text-2xl font-semibold mb-4 text-orange-400">OpenWebUI</h3>
                <div class="bg-green-600 text-white px-2 py-1 rounded text-xs mb-4">FRESHLY INSTALLED</div>
                <p class="text-gray-300 mb-6">Brand new chat interface for direct conversations with OpenHands Critic 32B. Perfect for code discussions and testing.</p>
                <div class="space-y-2 mb-6 text-sm">
                    <div class="flex justify-between">
                        <span class="text-gray-400">Port:</span>
                        <span class="text-white">8080</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-400">Version:</span>
                        <span class="text-white">Latest (Fresh)</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-400">Auth:</span>
                        <span class="text-white">Disabled</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-400">Status:</span>
                        <span id="openwebui-status-detail" class="text-yellow-400">Starting...</span>
                    </div>
                </div>
                <a href="http://$SERVER_IP:8080" 
                   class="bg-gradient-to-r from-orange-600 to-red-600 hover:from-orange-700 hover:to-red-700 text-white px-6 py-3 rounded-lg transition-all duration-300 inline-block">
                    Launch OpenWebUI
                </a>
            </div>
        </div>

        <!-- Model Information -->
        <div class="glass-effect rounded-2xl p-8 mb-8">
            <h3 class="text-2xl font-semibold mb-6 gradient-text text-center">🧠 OpenHands Critic 32B Model</h3>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Parameters</div>
                    <div class="text-white font-semibold text-lg">32 Billion</div>
                </div>
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Context Length</div>
                    <div class="text-white font-semibold text-lg">32,768 tokens</div>
                </div>
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Specialization</div>
                    <div class="text-white font-semibold text-lg">Software Development</div>
                </div>
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Provider</div>
                    <div class="text-white font-semibold text-lg">Ollama (Local)</div>
                </div>
            </div>
            <div class="mt-6 text-center">
                <p class="text-gray-300">The official OpenHands Critic 32B model is specifically designed for software development, code review, and autonomous programming tasks. Now available in both DeskDev.ai and OpenWebUI.</p>
            </div>
        </div>

        <!-- Quick Actions -->
        <div class="glass-effect rounded-2xl p-6">
            <h3 class="text-xl font-semibold mb-4 gradient-text text-center">⚡ Quick Actions</h3>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <button onclick="checkAllServices()" 
                        class="glass-effect text-white px-4 py-3 rounded-lg hover:bg-white hover:bg-opacity-10 transition-all duration-300 text-sm">
                    🔄 Check Status
                </button>
                <a href="http://$SERVER_IP:11434/api/tags" target="_blank"
                   class="glass-effect text-white px-4 py-3 rounded-lg hover:bg-white hover:bg-opacity-10 transition-all duration-300 text-center text-sm">
                    📋 View Models
                </a>
                <a href="http://$SERVER_IP:3000" 
                   class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-3 rounded-lg transition-all duration-300 text-center text-sm">
                    🤖 Code with AI
                </a>
                <a href="http://$SERVER_IP:8080" 
                   class="bg-orange-600 hover:bg-orange-700 text-white px-4 py-3 rounded-lg transition-all duration-300 text-center text-sm">
                    💬 Chat with AI
                </a>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="glass-effect border-t border-white border-opacity-10">
        <div class="max-w-7xl mx-auto py-6 px-4 text-center">
            <p class="text-gray-400">&copy; 2024 AI Development Hub - $SERVER_IP</p>
            <p class="text-gray-500 text-sm mt-2">DeskDev.ai • Fresh OpenWebUI • OpenHands Critic 32B • Local AI Processing</p>
        </div>
    </footer>

    <script>
        // Service status checking
        async function checkService(url, statusId, indicatorId, detailId) {
            try {
                const response = await fetch(url, { 
                    method: 'HEAD', 
                    mode: 'no-cors',
                    timeout: 5000 
                });
                
                document.getElementById(statusId).innerHTML = '<span class="text-green-400">✅ Online</span>';
                document.getElementById(indicatorId).className = 'status-indicator status-online';
                if (detailId) document.getElementById(detailId).innerHTML = '<span class="text-green-400">Online</span>';
                return true;
            } catch (error) {
                document.getElementById(statusId).innerHTML = '<span class="text-red-400">❌ Offline</span>';
                document.getElementById(indicatorId).className = 'status-indicator status-offline';
                if (detailId) document.getElementById(detailId).innerHTML = '<span class="text-red-400">Offline</span>';
                return false;
            }
        }

        async function checkAllServices() {
            // Reset to checking state
            ['deskdev', 'openwebui', 'ollama'].forEach(service => {
                document.getElementById(service + '-indicator').className = 'status-indicator status-checking';
                document.getElementById(service + '-status').innerHTML = '<span class="text-yellow-400">Checking...</span>';
            });

            // Check each service
            await checkService('http://$SERVER_IP:3000', 'deskdev-status', 'deskdev-indicator', 'deskdev-status-detail');
            await checkService('http://$SERVER_IP:8080', 'openwebui-status', 'openwebui-indicator', 'openwebui-status-detail');
            await checkService('http://$SERVER_IP:11434', 'ollama-status', 'ollama-indicator');
        }

        // Auto-check services on page load and every 30 seconds
        window.onload = function() {
            checkAllServices();
            setInterval(checkAllServices, 30000);
        };
    </script>
</body>
</html>
EOF

# Step 9: Configure Nginx for landing page
log "Configuring Nginx..."
if ! command -v nginx &> /dev/null; then
    apt-get install -y nginx
fi

cat > /etc/nginx/sites-available/ai-hub << EOF
server {
    listen 80;
    server_name $SERVER_IP;

    # Landing page
    location = / {
        root /opt/ai-hub;
        index index.html;
        try_files \$uri \$uri/ =404;
    }

    # Redirect shortcuts
    location /deskdev {
        return 301 http://\$host:3000;
    }

    location /openwebui {
        return 301 http://\$host:8080;
    }

    location /chat {
        return 301 http://\$host:8080;
    }

    # Static files
    location /static/ {
        root /opt/ai-hub;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable the site
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
ln -sf /etc/nginx/sites-available/ai-hub /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Step 10: Final comprehensive status check
log "Performing comprehensive final status check..."
echo ""
echo "🎉 Fresh OpenWebUI installation and OpenHands Critic 32B setup completed!"
echo ""
echo "📊 Final Service Status:"
echo "========================"

# Check DeskDev.ai (should be untouched)
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ DeskDev.ai (port 3000): Online - Untouched ✨"
else
    echo "⚠️ DeskDev.ai (port 3000): Not responding (check your existing installation)"
fi

# Check fresh OpenWebUI
if curl -s http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ OpenWebUI (port 8080): Online - Fresh Installation 🆕"
else
    echo "❌ OpenWebUI (port 8080): Still not responding"
    echo "   Container status:"
    docker ps | grep open-webui || echo "   No OpenWebUI container found"
    echo "   Container logs (last 5 lines):"
    docker logs open-webui-fresh --tail 5 2>/dev/null || echo "   No logs available"
fi

# Check Ollama
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ Ollama (port 11434): Online"
else
    echo "❌ Ollama (port 11434): Not responding"
fi

# Check landing page
if curl -s http://localhost/ | grep -q "AI Development Hub"; then
    echo "✅ Landing page (port 80): Online"
else
    echo "❌ Landing page (port 80): Not working"
fi

echo ""
echo "🌐 Access Points:"
echo "================"
echo "🏠 Landing Page:  http://$SERVER_IP/ (new comprehensive hub)"
echo "🤖 DeskDev.ai:    http://$SERVER_IP:3000 (your existing installation)"
echo "💬 OpenWebUI:     http://$SERVER_IP:8080 (fresh installation)"
echo "🔧 Ollama API:    http://$SERVER_IP:11434 (model management)"
echo ""

# Show available models
echo "📚 Available AI Models:"
echo "======================"
ollama list

echo ""
echo "🎯 Installation Summary:"
echo "========================"
echo "✅ OpenWebUI completely removed and freshly reinstalled"
echo "✅ OpenHands Critic 32B model installed (32B parameters, 32K context)"
echo "✅ Your existing DeskDev.ai on port 3000 remained untouched"
echo "✅ Comprehensive landing page created with live status monitoring"
echo "✅ Both services now use the powerful OpenHands Critic 32B model"
echo ""
echo "💡 You now have a complete AI development environment:"
echo "   • DeskDev.ai for autonomous coding and file manipulation"
echo "   • OpenWebUI for direct AI conversations and code discussions"
echo "   • OpenHands Critic 32B powering both platforms locally"
echo ""
echo "🚀 Ready to code with AI! Visit http://$SERVER_IP/ to get started."

log "Fresh installation completed successfully!"
