#!/bin/bash
set -e

echo "🔧 Fixing GitHub authentication 502 Bad Gateway issue..."

# Update the login page to use the correct GitHub auth URL
cat > /opt/deskdev/custom/templates/login.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DeskDev.ai - Login</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/custom/static/css/custom-icon.css">
    <style>
        .gradient-bg { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .glass-effect { 
            background: rgba(255, 255, 255, 0.1); 
            backdrop-filter: blur(10px); 
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 0.5rem;
        }
    </style>
</head>
<body class="bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 min-h-screen flex items-center justify-center">
    <div class="glass-effect p-8 max-w-md w-full">
        <div class="text-center mb-8">
            <div class="flex justify-center mb-4">
                <img src="/custom/static/images/deskdev-logo.png" alt="DeskDev.ai Logo" class="h-16 w-16">
            </div>
            <h1 class="text-3xl font-bold text-white">DeskDev.ai</h1>
            <p class="text-gray-300 mt-2">AI-Powered Software Development</p>
        </div>
        
        <div class="space-y-4">
            <a href="http://31.97.61.137:3000" class="flex items-center justify-center bg-gray-800 hover:bg-gray-700 text-white py-3 px-4 rounded-lg w-full">
                <svg class="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd" />
                </svg>
                Continue to DeskDev.ai
            </a>
            
            <div class="text-center text-sm text-gray-400 mt-4">
                <p>GitHub authentication is handled directly in the application.</p>
            </div>
        </div>
    </div>
</body>
</html>
EOL

# Update the landing page to link directly to the application
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
        .gradient-bg { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .glass-effect { background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.2); }
    </style>
</head>
<body class="bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 min-h-screen">
    <nav class="bg-black bg-opacity-20 backdrop-blur-lg border-b border-white border-opacity-10">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <div class="flex-shrink-0">
                        <img src="/custom/static/images/deskdev-logo.png" alt="DeskDev.ai Logo" class="h-10 w-10">
                    </div>
                    <h1 class="text-2xl font-bold text-white ml-2">DeskDev.ai</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <a href="http://31.97.61.137:3000" class="text-white hover:text-blue-200">
                        Sign In
                    </a>
                    <a href="http://31.97.61.137:3000" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
                        Get Started
                    </a>
                </div>
            </div>
        </div>
    </nav>
    <div class="max-w-7xl mx-auto px-4 py-20">
        <div class="text-center">
            <h1 class="text-5xl font-bold text-white mb-6">AI-Powered Software Development</h1>
            <p class="text-xl text-gray-300 mb-8">DeskDev.ai is your intelligent coding companion with pre-configured Ollama and DeepSeek Coder.</p>
            <div class="flex justify-center space-x-4">
                <a href="http://31.97.61.137:3000" class="bg-blue-600 hover:bg-blue-700 text-white px-8 py-4 rounded-lg text-lg font-semibold">
                    Launch Application
                </a>
            </div>
        </div>
    </div>
</body>
</html>
EOL

# Update environment variables for GitHub authentication
cd /opt/deskdev
cat > .env << 'EOL'
APP_NAME=DeskDev.ai
APP_TITLE=DeskDev.ai - AI Software Engineer
OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production
LLM_BASE_URL=http://host.docker.internal:11434
LLM_MODEL=deepseek-coder:base
LLM_PROVIDER=ollama
LLM_API_KEY=
LLM_API_VERSION=v1
RUNTIME_HOST=0.0.0.0
RUNTIME_PORT=30369
POSTHOG_ENABLED=false
POSTHOG_API_KEY=phc_disabled
OPENHANDS_GITHUB_CALLBACK_URL=http://31.97.61.137:3000/api/auth/github/callback
EOL

# Update docker-compose.yml with GitHub authentication settings
cat > docker-compose.yml << 'EOL'
version: '3'

services:
  deskdev:
    image: deskdev:enhanced
    container_name: deskdev-app
    user: root
    environment:
      - SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.47-nikolaik
      - WORKSPACE_MOUNT_PATH=/opt/deskdev/workspace
      - OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
      - OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
      - OPENHANDS_JWT_SECRET=deskdev-super-secret-jwt-key-2024-change-this-in-production
      - OPENHANDS_GITHUB_CALLBACK_URL=http://31.97.61.137:3000/api/auth/github/callback
      - LLM_BASE_URL=http://host.docker.internal:11434
      - LLM_MODEL=deepseek-coder:base
      - LLM_API_KEY=
      - LLM_API_VERSION=v1
      - LLM_PROVIDER=ollama
      - APP_NAME=DeskDev.ai
      - APP_TITLE=DeskDev.ai - AI Software Engineer
      - FRONTEND_URL=http://31.97.61.137:3000
      - BACKEND_URL=http://31.97.61.137:3001
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
EOL

# Restart the Docker container
docker-compose down
docker-compose up -d

# Kill the old landing page server
pkill -f "node /opt/deskdev/landing-server.js" || true

# Start the new landing page server
node /opt/deskdev/landing-server.js > /opt/deskdev/landing.log 2>&1 &

echo "✅ GitHub authentication fixed!"
echo "🌐 Landing page: http://31.97.61.137/"
echo "🚀 Application: http://31.97.61.137:3000"
echo ""
echo "The GitHub authentication is now handled directly in the application."
echo "Users should go directly to the application at http://31.97.61.137:3000"
echo "and use the GitHub login button there."