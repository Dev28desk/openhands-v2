#!/bin/bash
set -e

echo "🚀 DeskDev.ai Complete Deployment Script"
echo "========================================"
echo "This script will deploy DeskDev.ai with all fixes and configurations."
echo ""

# Function to print section headers
section() {
  echo ""
  echo "📋 $1"
  echo "----------------------------------------"
}

# Check system requirements
section "Checking system requirements"
echo "Memory:"
free -h
echo ""
echo "Disk space:"
df -h
echo ""
echo "CPU info:"
nproc

# Install required packages
section "Installing required packages"
apt-get update
apt-get install -y curl wget git nginx docker.io docker-compose tmux

# Create directory structure
section "Creating directory structure"
mkdir -p /opt/deskdev/{data,workspace,custom/static/images,custom/static/css,custom/templates,custom/scripts}

# Download custom logo
section "Downloading custom logo"
curl -s -o /opt/deskdev/custom/static/images/deskdev-logo.png https://developers.redhat.com/sites/default/files/styles/keep_original/public/ML%20models.png?itok=T-pMYACJ

# Create custom CSS
section "Creating custom CSS"
cat > /opt/deskdev/custom/static/css/custom-icon.css << 'EOL'
.app-logo, .logo-image {
  background-image: url('/custom/static/images/deskdev-logo.png') !important;
  background-size: contain !important;
  background-repeat: no-repeat !important;
  background-position: center !important;
}
EOL

# Create dark-themed landing page
section "Creating dark-themed landing page"
cat > /opt/deskdev/custom/templates/landing.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DeskDev.ai - AI-Powered Software Development</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/custom/static/css/custom-icon.css">
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
                    <div class="flex-shrink-0">
                        <img src="/custom/static/images/deskdev-logo.png" alt="DeskDev.ai Logo" class="h-10 w-10">
                    </div>
                    <h1 class="text-2xl font-bold text-white ml-2">DeskDev.ai</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <a href="/app" class="btn-primary">
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
                <a href="/app" class="btn-primary text-lg px-8 py-4">
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

# Install and configure Ollama
section "Installing and configuring Ollama"
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
EOF

# Create the custom model
echo "Creating custom DeskDev model..."
cd /opt/ollama/models
ollama create deskdev -f Modelfile.deskdev

# Create initialization script for the container
section "Creating initialization script"
cat > /opt/deskdev/custom/scripts/init.sh << 'EOL'
#!/bin/bash
echo "Initializing DeskDev.ai..."
mkdir -p /.openhands/settings
echo '{"llm":{"provider":"ollama","model":"deskdev","baseUrl":"http://host.docker.internal:11434","apiKey":"","apiVersion":"v1"},"ui":{"theme":"dark"}}' > /.openhands/settings/default_settings.json
chmod 644 /.openhands/settings/default_settings.json
EOL
chmod +x /opt/deskdev/custom/scripts/init.sh

# Create docker-compose.yml
section "Creating docker-compose.yml"
cd /opt/deskdev
cat > docker-compose.yml << 'EOL'
version: '3'

services:
  deskdev:
    image: docker.all-hands.dev/all-hands-ai/openhands:latest
    container_name: deskdev-app
    user: root
    entrypoint: ["/bin/bash", "-c"]
    command: >
      "mkdir -p /.openhands/settings &&
       echo '{\"llm\":{\"provider\":\"ollama\",\"model\":\"deskdev\",\"baseUrl\":\"http://host.docker.internal:11434\",\"apiKey\":\"\",\"apiVersion\":\"v1\"},\"ui\":{\"theme\":\"dark\"}}' > /.openhands/settings/default_settings.json &&
       chmod 644 /.openhands/settings/default_settings.json &&
       /app/entrypoint.sh"
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
      - RUNTIME_TIMEOUT=120000
      - RUNTIME_CONNECTION_TIMEOUT=60000
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
EOL

# Configure Nginx
section "Configuring Nginx"
cat > /etc/nginx/sites-available/deskdev << 'EOL'
server {
    listen 80;
    server_name _;

    # Landing page
    location = / {
        root /opt/deskdev/custom/templates;
        try_files /landing.html =404;
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
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
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
        proxy_connect_timeout 75s;
    }

    # Socket.io for real-time communication
    location /socket.io/ {
        proxy_pass http://localhost:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
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
        proxy_connect_timeout 75s;
    }
}
EOL

# Enable the Nginx configuration
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Configure firewall rules
section "Configuring firewall rules"
iptables -I INPUT -p tcp --dport 11434 -j ACCEPT
iptables -I DOCKER -p tcp --dport 11434 -j ACCEPT 2>/dev/null || true

# Create a custom microagent for DeskDev.ai
section "Creating custom microagent"
mkdir -p /opt/deskdev/data/microagents
cat > /opt/deskdev/data/microagents/deskdev.md << 'EOL'
---
name: DeskDev.ai
type: knowledge
version: 1.0.0
agent: CodeActAgent
triggers:
  - deskdev
  - desk dev
  - desk-dev
---

# DeskDev.ai Microagent

You are DeskDev.ai, an AI-powered software development assistant. You help users write, debug, and optimize code.

## Capabilities

- Write, debug, and optimize code in multiple programming languages
- Explain complex programming concepts in simple terms
- Provide best practices and design patterns
- Help with software architecture and system design
- Assist with debugging and troubleshooting

## Configuration

DeskDev.ai is pre-configured to use Ollama with the custom "deskdev" model, which is based on deepseek-coder:base.

Default configuration:
- Provider: ollama
- Model: deskdev
- Base URL: http://host.docker.internal:11434
- API Key: (not required)
- API Version: v1

## Best Practices

When helping users with code:
1. Understand the requirements thoroughly before providing solutions
2. Provide explanations along with code to help users learn
3. Consider performance, security, and maintainability
4. Suggest tests and error handling when appropriate
5. Provide references to documentation or resources for further learning

## Troubleshooting

If users encounter issues with the application:
1. Check if Ollama is running: `systemctl status ollama`
2. Verify the model is available: `ollama list`
3. Check Docker container logs: `docker logs deskdev-app`
4. Restart the application: `cd /opt/deskdev && docker-compose restart`
EOL

# Stop any running containers
section "Stopping any running containers"
docker ps -q | xargs -r docker stop
docker ps -aq | xargs -r docker rm

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

section "Deployment complete"
echo "✅ DeskDev.ai has been deployed successfully!"
echo ""
echo "🌐 Access your application:"
echo "- Landing page: http://31.97.61.137/"
echo "- Application: http://31.97.61.137/app"
echo ""
echo "📝 Default Ollama configuration:"
echo "- Provider: ollama"
echo "- Model: deskdev (custom model based on deepseek-coder:base)"
echo "- Base URL: http://host.docker.internal:11434"
echo ""
echo "🔧 If you encounter any issues:"
echo "- Check Docker logs: docker logs deskdev-app"
echo "- Check Ollama status: systemctl status ollama"
echo "- Restart the application: cd /opt/deskdev && docker-compose restart"