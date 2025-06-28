#!/bin/bash
set -e

echo "🚀 DeskDev.ai One-Click Deployment"
echo "=================================="

# Create directory structure
mkdir -p /opt/deskdev/{data,workspace,custom/{templates,static/{css,images}}}

# Download scripts from GitHub
echo "📥 Downloading deployment scripts..."
cd /opt/deskdev
curl -s -o fix-runtime.sh https://raw.githubusercontent.com/Dev28desk/openhands-v2/main/fix-runtime.sh
curl -s -o setup-landing-page.sh https://raw.githubusercontent.com/Dev28desk/openhands-v2/main/setup-landing-page.sh
curl -s -o update-docker-compose.sh https://raw.githubusercontent.com/Dev28desk/openhands-v2/main/update-docker-compose.sh
curl -s -o apply-all-fixes.sh https://raw.githubusercontent.com/Dev28desk/openhands-v2/main/apply-all-fixes.sh

# Make scripts executable
chmod +x *.sh

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "🤖 Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Configure Ollama
    echo "⚙️ Configuring Ollama..."
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

    # Reload and start Ollama
    systemctl daemon-reload
    systemctl enable ollama
    systemctl restart ollama
    sleep 5
fi

# Pull the DeepSeek Coder model
echo "🧠 Pulling DeepSeek Coder model..."
ollama pull deepseek-coder:base

# Apply all fixes
echo "🔧 Applying all fixes..."
./apply-all-fixes.sh

echo ""
echo "✅ DeskDev.ai deployment complete!"
echo "🌐 Access your application at: http://31.97.61.137/"
echo "🔧 If you encounter any issues, run the individual fix scripts:"
echo "   - ./fix-runtime.sh - Fix runtime connection issues"
echo "   - ./setup-landing-page.sh - Set up the landing page"
echo "   - ./update-docker-compose.sh - Update Docker configuration"