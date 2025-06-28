#!/bin/bash
set -e

echo "🤖 Configuring Ollama with Custom Model for DeskDev.ai..."

# Ensure Ollama is installed
if ! command -v ollama &> /dev/null; then
  echo "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  sleep 5
fi

# Create Ollama service configuration
echo "Configuring Ollama service..."
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

# Reload systemd and restart Ollama
systemctl daemon-reload
systemctl enable ollama
systemctl restart ollama
sleep 5

# Check if Ollama is running
if ! curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null; then
  echo "❌ Ollama service failed to start"
  systemctl status ollama
  journalctl -u ollama --no-pager | tail -n 50
  exit 1
fi

# Pull the deepseek-coder model
echo "Pulling deepseek-coder:base model..."
ollama pull deepseek-coder:base

# Create a custom Modelfile
echo "Creating custom Modelfile..."
mkdir -p /opt/ollama/models
cat > /opt/ollama/models/Modelfile.deskdev << 'EOF'
FROM deepseek-coder:base

# Set a system message to customize the model behavior
SYSTEM """
You are DeskDev.ai, an AI-powered software development assistant.
You help users write, debug, and optimize code.
You have expertise in multiple programming languages and frameworks.
You provide clear, concise, and helpful responses.
"""

# Set parameters for better code generation
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER stop "```"
EOF

# Create the custom model
echo "Creating custom DeskDev model..."
cd /opt/ollama/models
ollama create deskdev -f Modelfile.deskdev

# Verify the model was created
if ollama list | grep -q "deskdev"; then
  echo "✅ Custom DeskDev model created successfully"
else
  echo "❌ Failed to create custom model"
  exit 1
fi

# Update application configuration to use the custom model
echo "Updating application configuration..."

# Create default settings file
mkdir -p /opt/deskdev/data/settings
cat > /opt/deskdev/data/settings/default_settings.json << 'EOF'
{
  "llm": {
    "provider": "ollama",
    "model": "deskdev",
    "baseUrl": "http://host.docker.internal:11434",
    "apiKey": "",
    "apiVersion": "v1"
  },
  "ui": {
    "theme": "dark"
  }
}
EOF

# Update environment variables in docker-compose.yml
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
      - LLM_MODEL=deskdev
      - LLM_API_KEY=
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      - DEFAULT_LLM_PROVIDER=ollama
      - DEFAULT_LLM_MODEL=deskdev
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

# Create a configuration guide for users
mkdir -p /opt/deskdev/custom/templates
cat > /opt/deskdev/custom/templates/ollama-config.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DeskDev.ai - Ollama Configuration</title>
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
        .code-block {
            background-color: #1e293b;
            border-radius: 0.375rem;
            padding: 1rem;
            font-family: monospace;
            overflow-x: auto;
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
                    <a href="/" class="text-gray-300 hover:text-white">Home</a>
                    <a href="/app" class="bg-blue-600 text-white px-4 py-2 rounded-md">Launch App</a>
                </div>
            </div>
        </div>
    </nav>
    <div class="flex-grow">
        <div class="max-w-4xl mx-auto px-4 py-12">
            <h1 class="text-4xl font-bold text-white mb-6">Ollama Configuration</h1>
            
            <div class="glass-effect p-6 mb-8">
                <h2 class="text-2xl font-semibold text-blue-400 mb-4">Default Configuration</h2>
                <p class="mb-4">DeskDev.ai is pre-configured to use the custom <code class="bg-gray-800 px-2 py-1 rounded">deskdev</code> model with Ollama. You don't need to change anything to get started.</p>
                
                <div class="code-block mb-4">
                    <p><span class="text-blue-400">Provider:</span> ollama</p>
                    <p><span class="text-blue-400">Model:</span> deskdev</p>
                    <p><span class="text-blue-400">Base URL:</span> http://host.docker.internal:11434</p>
                    <p><span class="text-blue-400">API Key:</span> (not required)</p>
                    <p><span class="text-blue-400">API Version:</span> v1</p>
                </div>
            </div>
            
            <div class="glass-effect p-6 mb-8">
                <h2 class="text-2xl font-semibold text-blue-400 mb-4">Custom Configuration</h2>
                <p class="mb-4">If you want to use a different model or configuration, you can change the settings in the DeskDev.ai application:</p>
                
                <ol class="list-decimal list-inside space-y-2 mb-4">
                    <li>Launch the DeskDev.ai application</li>
                    <li>Click on the settings icon in the top right corner</li>
                    <li>Go to the "LLM Settings" section</li>
                    <li>Update the configuration as needed</li>
                    <li>Click "Save" to apply the changes</li>
                </ol>
            </div>
            
            <div class="glass-effect p-6">
                <h2 class="text-2xl font-semibold text-blue-400 mb-4">Available Models</h2>
                <p class="mb-4">The following models are available on your server:</p>
                
                <div class="code-block" id="models-list">
                    <!-- This will be populated by JavaScript -->
                    Loading models...
                </div>
                
                <p class="mt-4">To add more models, run the following command on your server:</p>
                <div class="code-block">
                    <p>ollama pull [model-name]</p>
                </div>
                
                <p class="mt-4">For example, to add the Llama 3 model:</p>
                <div class="code-block">
                    <p>ollama pull llama3</p>
                </div>
            </div>
        </div>
    </div>
    <footer class="bg-gray-900 py-6">
        <div class="max-w-7xl mx-auto px-4 text-center text-gray-400">
            <p>© 2024 DeskDev.ai - Powered by Ollama</p>
        </div>
    </footer>
    
    <script>
        // Fetch available models from Ollama
        fetch('/api/ollama/models')
            .then(response => response.json())
            .then(data => {
                const modelsList = document.getElementById('models-list');
                if (data && data.models && data.models.length > 0) {
                    modelsList.innerHTML = data.models.map(model => 
                        `<p><span class="text-green-400">${model.name}</span> - ${model.size} MB</p>`
                    ).join('');
                } else {
                    modelsList.innerHTML = 'No models found. Please check your Ollama installation.';
                }
            })
            .catch(error => {
                document.getElementById('models-list').innerHTML = 'Error fetching models. Please check your Ollama installation.';
                console.error('Error fetching models:', error);
            });
    </script>
</body>
</html>
EOF

# Create API endpoint for Ollama models
mkdir -p /opt/deskdev/custom/api
cat > /opt/deskdev/custom/api/ollama-models.js << 'EOF'
const express = require('express');
const axios = require('axios');
const router = express.Router();

router.get('/models', async (req, res) => {
  try {
    const response = await axios.get('http://host.docker.internal:11434/api/tags');
    const models = response.data.models || [];
    
    res.json({
      models: models.map(model => ({
        name: model.name,
        size: Math.round(model.size / (1024 * 1024)) // Convert to MB
      }))
    });
  } catch (error) {
    console.error('Error fetching Ollama models:', error);
    res.status(500).json({ error: 'Failed to fetch models from Ollama' });
  }
});

module.exports = router;
EOF

# Update Nginx configuration to serve the Ollama config page
cat > /etc/nginx/sites-available/deskdev << 'EOF'
server {
    listen 80;
    server_name _;

    # Landing page
    location = / {
        root /opt/deskdev/custom/templates;
        try_files /landing.html =404;
    }

    # Ollama configuration page
    location = /ollama-config {
        root /opt/deskdev/custom/templates;
        try_files /ollama-config.html =404;
    }

    # Static files
    location /custom/ {
        alias /opt/deskdev/custom/;
    }

    # Frontend application
    location /app {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API for Ollama models
    location /api/ollama/ {
        proxy_pass http://localhost:3001/api/ollama/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
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

echo ""
echo "✅ Ollama configuration completed!"
echo ""
echo "🤖 Ollama Configuration for DeskDev.ai:"
echo "----------------------------------------"
echo "Provider: ollama"
echo "Model: deskdev (custom model based on deepseek-coder:base)"
echo "Base URL: http://host.docker.internal:11434"
echo "API Key: (not required)"
echo "API Version: v1"
echo ""
echo "🌐 Access your application:"
echo "- Landing page: http://31.97.61.137/"
echo "- Application: http://31.97.61.137/app"
echo "- Ollama config guide: http://31.97.61.137/ollama-config"
echo ""
echo "These settings are pre-configured in the application."
echo "Users don't need to manually configure anything to get started."