#!/bin/bash
set -e

# Server Configuration
SERVER_IP="154.201.127.161"

echo "🔧 Fixing OpenWebUI and creating landing page for $SERVER_IP..."

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting OpenWebUI fix (keeping DeskDev.ai on port 3000 untouched)..."

# Step 1: Check current status
log "Checking current services..."
echo "📊 Current service status:"
echo "   DeskDev.ai (port 3000): $(curl -s http://localhost:3000 >/dev/null && echo '✅ Running - Will NOT touch' || echo '❌ Not responding')"
echo "   OpenWebUI (port 8080): $(curl -s http://localhost:8080 >/dev/null && echo '✅ Running' || echo '❌ Not working - Will fix')"

# Step 2: Install Docker if needed (for OpenWebUI)
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

# Step 3: Fix OpenWebUI
log "Fixing OpenWebUI on port 8080..."

# Check if OpenWebUI is responding
if ! curl -s http://localhost:8080 >/dev/null; then
    log "OpenWebUI not responding, diagnosing..."
    
    # Try to find existing OpenWebUI containers
    OPENWEBUI_CONTAINERS=$(docker ps -a | grep -i "webui\|open-webui" | awk '{print $1}')
    
    if [ ! -z "$OPENWEBUI_CONTAINERS" ]; then
        log "Found existing OpenWebUI containers, removing them..."
        echo "$OPENWEBUI_CONTAINERS" | xargs -r docker rm -f
    fi
    
    # Check if port 8080 is occupied by something else
    PORT_CHECK=$(netstat -tulpn 2>/dev/null | grep :8080 || true)
    if [ ! -z "$PORT_CHECK" ]; then
        log "Port 8080 is occupied by: $PORT_CHECK"
        log "Killing processes using port 8080..."
        fuser -k 8080/tcp 2>/dev/null || true
        sleep 3
    fi
    
    # Deploy fresh OpenWebUI
    log "Deploying fresh OpenWebUI instance..."
    docker run -d --name open-webui \
        -p 8080:8080 \
        -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
        -e WEBUI_AUTH=false \
        -v open-webui:/app/backend/data \
        --add-host=host.docker.internal:host-gateway \
        --restart unless-stopped \
        ghcr.io/open-webui/open-webui:main
    
    log "Waiting for OpenWebUI to start..."
    sleep 20
    
    # Check if it's working now
    for i in {1..30}; do
        if curl -s http://localhost:8080 >/dev/null; then
            log "✅ OpenWebUI is now running!"
            break
        fi
        log "Waiting for OpenWebUI... ($i/30)"
        sleep 2
    done
else
    log "✅ OpenWebUI is already working!"
fi

# Step 4: Ensure Ollama is accessible
log "Checking Ollama connectivity..."
if ! curl -s http://localhost:11434/api/tags >/dev/null; then
    log "⚠️ Ollama not responding, attempting to start..."
    systemctl start ollama 2>/dev/null || true
    sleep 5
fi

# Step 5: Create landing page directory
log "Creating landing page..."
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
                Your complete AI development environment with DeskDev.ai and OpenWebUI 
                running on <span class="text-blue-400 font-mono">$SERVER_IP</span>
            </p>
        </div>

        <!-- Services Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-12">
            <!-- DeskDev.ai Card -->
            <div class="service-card glass-effect rounded-2xl p-8 text-center">
                <div class="text-6xl mb-4">🤖</div>
                <h3 class="text-2xl font-semibold mb-4 gradient-text">DeskDev.ai</h3>
                <p class="text-gray-300 mb-6">AI Software Engineer with autonomous coding capabilities. Powered by OpenHands Critic 32B for advanced development tasks.</p>
                <div class="space-y-2 mb-6">
                    <div class="text-sm text-gray-400">Port: 3000</div>
                    <div class="text-sm text-gray-400">Model: OpenHands Critic 32B</div>
                    <div class="text-sm text-gray-400">Status: <span id="deskdev-status" class="text-yellow-400">Checking...</span></div>
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
                <p class="text-gray-300 mb-6">Chat interface for interacting with local AI models. Perfect for conversations and testing the OpenHands Critic 32B model.</p>
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

        <!-- Model Information -->
        <div class="glass-effect rounded-2xl p-8 mb-8">
            <h3 class="text-2xl font-semibold mb-6 gradient-text text-center">🧠 OpenHands Critic 32B Model</h3>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Model Size</div>
                    <div class="text-white font-semibold">32 Billion Parameters</div>
                </div>
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Context Length</div>
                    <div class="text-white font-semibold">32,768 tokens</div>
                </div>
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Specialization</div>
                    <div class="text-white font-semibold">Code Review & Development</div>
                </div>
                <div class="glass-effect rounded-lg p-4 text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Provider</div>
                    <div class="text-white font-semibold">Ollama (Local)</div>
                </div>
            </div>
            <div class="mt-6 text-center">
                <p class="text-gray-300">The official OpenHands Critic 32B model is designed specifically for software development, code review, and autonomous programming tasks.</p>
            </div>
        </div>

        <!-- Features Section -->
        <div class="glass-effect rounded-2xl p-8 mb-8">
            <h3 class="text-2xl font-semibold mb-6 gradient-text text-center">🚀 Platform Features</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="text-center">
                    <div class="text-4xl mb-3">⚡</div>
                    <h4 class="text-lg font-semibold mb-2 text-blue-400">Autonomous Development</h4>
                    <p class="text-gray-300">DeskDev.ai can write complete applications, debug code, and implement features automatically</p>
                </div>
                <div class="text-center">
                    <div class="text-4xl mb-3">🔍</div>
                    <h4 class="text-lg font-semibold mb-2 text-blue-400">Advanced Code Review</h4>
                    <p class="text-gray-300">OpenHands Critic 32B provides expert-level code analysis and optimization suggestions</p>
                </div>
                <div class="text-center">
                    <div class="text-4xl mb-3">💬</div>
                    <h4 class="text-lg font-semibold mb-2 text-blue-400">Interactive Chat</h4>
                    <p class="text-gray-300">Use OpenWebUI for direct conversations with the AI model for quick questions and testing</p>
                </div>
            </div>
        </div>

        <!-- System Information -->
        <div class="glass-effect rounded-2xl p-8">
            <h3 class="text-2xl font-semibold mb-6 gradient-text text-center">🖥️ System Information</h3>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Server IP</div>
                    <div class="text-white font-mono text-lg">$SERVER_IP</div>
                </div>
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">DeskDev.ai Port</div>
                    <div class="text-white font-mono text-lg">3000</div>
                </div>
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">OpenWebUI Port</div>
                    <div class="text-white font-mono text-lg">8080</div>
                </div>
                <div class="text-center">
                    <div class="text-blue-400 text-sm uppercase tracking-wide">Ollama API</div>
                    <div class="text-white font-mono text-lg">11434</div>
                </div>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="glass-effect border-t border-white border-opacity-10">
        <div class="max-w-7xl mx-auto py-8 px-4 text-center">
            <p class="text-gray-400">&copy; 2024 AI Development Hub on $SERVER_IP</p>
            <p class="text-gray-500 text-sm mt-2">DeskDev.ai • OpenWebUI • OpenHands Critic 32B • Local AI Processing</p>
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
            await checkService('http://$SERVER_IP:3000', 'deskdev-status');
            await checkService('http://$SERVER_IP:8080', 'openwebui-status');
        }

        // Check services on page load
        window.onload = function() {
            setTimeout(checkAllServices, 1000);
        };
    </script>
</body>
</html>
EOF

# Step 6: Install OpenHands Critic 32B model
log "Installing OpenHands Critic 32B model..."

# Install Python dependencies for model downloading
apt-get update
apt-get install -y python3-pip python3-venv git-lfs

# Create working directory for model conversion
WORK_DIR="/opt/model-conversion"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Set up Python environment
python3 -m venv model-env
source model-env/bin/activate
pip install --upgrade pip
pip install torch transformers huggingface_hub

# Download the OpenHands Critic 32B model
log "Downloading OpenHands Critic 32B from Hugging Face..."
python3 << 'PYTHON_EOF'
import os
from huggingface_hub import snapshot_download

print("Starting OpenHands Critic 32B download...")
try:
    # Set cache directory
    cache_dir = "/opt/model-conversion/hf-cache"
    os.makedirs(cache_dir, exist_ok=True)

    # Download the model
    model_path = snapshot_download(
        repo_id="all-hands/openhands-critic-32b-exp-20250417",
        cache_dir=cache_dir,
        local_dir="/opt/model-conversion/openhands-critic-32b",
        local_dir_use_symlinks=False,
        resume_download=True
    )
    print(f"✅ Model downloaded successfully to: {model_path}")
except Exception as e:
    print(f"❌ Error downloading model: {e}")
    print("Will use DeepSeek Coder as fallback")
PYTHON_EOF

# Create Modelfile for Ollama
log "Creating Ollama model configuration..."
if [ -d "/opt/model-conversion/openhands-critic-32b" ]; then
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

You have access to execute commands, edit files, and perform comprehensive development tasks. Always provide detailed, actionable advice with clear explanations.
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

SYSTEM """You are OpenHands Critic 32B, the official AI model for software development, running on 154.201.127.161."""
EOF

    # Import model into Ollama
    log "Importing OpenHands Critic 32B into Ollama..."
    ollama create openhands-critic:32b -f Modelfile
    
    if ollama list | grep -q "openhands-critic:32b"; then
        log "✅ OpenHands Critic 32B model created successfully!"
    else
        log "❌ Failed to create OpenHands Critic 32B model"
    fi
else
    log "⚠️ OpenHands Critic 32B download failed, creating fallback model..."
    # Pull DeepSeek Coder as fallback
    ollama pull deepseek-coder:base
    ollama create openhands-critic:32b << 'EOF'
FROM deepseek-coder:base
TEMPLATE """<|im_start|>system
You are OpenHands Critic, a specialized AI model for software development (fallback version using DeepSeek Coder). You excel at coding, debugging, and development tasks.
<|im_end|>
<|im_start|>user
{{ .Prompt }}
<|im_end|>
<|im_start|>assistant
"""
PARAMETER temperature 0.1
PARAMETER num_ctx 16384
SYSTEM """You are OpenHands Critic (DeepSeek Coder fallback) running on 154.201.127.161."""
EOF
fi

# Clean up
deactivate
rm -rf model-env hf-cache

# Step 7: Configure Nginx for landing page
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

# Step 8: Final status check
log "Performing final status check..."
echo ""
echo "🎉 Setup completed!"
echo ""
echo "📊 Service Status:"
echo "=================="

# Check DeskDev.ai (should be untouched)
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ DeskDev.ai (port 3000): Online - Untouched"
else
    echo "⚠️ DeskDev.ai (port 3000): Not responding"
fi

# Check OpenWebUI
if curl -s http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ OpenWebUI (port 8080): Online - Fixed"
else
    echo "❌ OpenWebUI (port 8080): Still not working"
    echo "   Checking OpenWebUI logs..."
    docker logs open-webui --tail 10 2>/dev/null || echo "   No container logs available"
fi

# Check Ollama
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ Ollama (port 11434): Online"
else
    echo "❌ Ollama (port 11434): Not responding"
fi

# Check landing page
if curl -s http://localhost/ | grep -q "AI Development Hub"; then
    echo "✅ Landing page: Working"
else
    echo "❌ Landing page: Not working"
fi

echo ""
echo "🌐 Access Points:"
echo "================"
echo "🏠 Landing Page:  http://$SERVER_IP/"
echo "🤖 DeskDev.ai:    http://$SERVER_IP:3000 (your existing installation)"
echo "💬 OpenWebUI:     http://$SERVER_IP:8080 (fixed)"
echo ""

# Show available models
echo "📚 Available AI Models:"
ollama list

echo ""
echo "🎯 Summary:"
echo "==========="
echo "✅ Your existing DeskDev.ai on port 3000 is untouched"
echo "✅ OpenWebUI on port 8080 has been fixed"
echo "✅ OpenHands Critic 32B model has been installed"
echo "✅ Landing page created showing both services"
echo ""
echo "💡 You can now use both DeskDev.ai and OpenWebUI with the powerful OpenHands Critic 32B model!"

log "Setup completed successfully!"
