#!/bin/bash
set -e

echo "🔄 Fixing DeskDev.ai app routing and PostHog issues..."

# Update the landing page server to correctly redirect to the app
cat > /opt/deskdev/landing-server.js << 'EOL'
const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = 8080;

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url);
  let pathname = parsedUrl.pathname;
  
  // Redirect /app to the main application
  if (pathname === '/app') {
    res.writeHead(302, { 'Location': '/' });
    res.end();
    return;
  }
  
  // Serve landing page at root
  if (pathname === '/') {
    pathname = '/templates/landing.html';
  }
  
  // Handle static files
  if (pathname.startsWith('/custom/static/')) {
    pathname = pathname.replace('/custom/static/', '/static/');
  }
  
  // Determine the file path
  let filePath = '';
  if (pathname.startsWith('/static/')) {
    filePath = path.join('/opt/deskdev/custom', pathname);
  } else if (pathname.startsWith('/templates/')) {
    filePath = path.join('/opt/deskdev/custom', pathname);
  } else {
    filePath = path.join('/opt/deskdev/custom/templates', 'landing.html');
  }
  
  // Get the file extension
  const extname = path.extname(filePath);
  const contentType = MIME_TYPES[extname] || 'text/plain';
  
  // Read the file
  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        // File not found
        res.writeHead(404);
        res.end('File not found');
      } else {
        // Server error
        res.writeHead(500);
        res.end(`Server Error: ${err.code}`);
      }
    } else {
      // Success
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`Landing page server running at http://localhost:${PORT}`);
});
EOL

# Update the landing page HTML to point directly to the app URL
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
                <div class="flex items-center">
                    <a href="http://31.97.61.137:3000" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
                        Launch App
                    </a>
                </div>
            </div>
        </div>
    </nav>
    <div class="max-w-7xl mx-auto px-4 py-20">
        <div class="text-center">
            <h1 class="text-5xl font-bold text-white mb-6">AI-Powered Software Development</h1>
            <p class="text-xl text-gray-300 mb-8">DeskDev.ai is your intelligent coding companion with pre-configured Ollama and DeepSeek Coder.</p>
            <a href="http://31.97.61.137:3000" class="bg-blue-600 hover:bg-blue-700 text-white px-8 py-4 rounded-lg text-lg font-semibold">
                Get Started
            </a>
        </div>
    </div>
</body>
</html>
EOL

# Update Nginx configuration to properly handle routing
cat > /etc/nginx/sites-available/deskdev << 'EOL'
server {
    listen 80;
    server_name _;

    # Landing page
    location = / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Static files for landing page
    location /custom/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Main application - direct access
    location /app {
        return 301 http://$host:3000;
    }

    # Main application - proxy all requests to port 3000
    location ~ ^/(?!custom|api) {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Socket.io for real-time communication
    location /socket.io {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # API endpoints
    location /api {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOL

# Fix PostHog client key issue by disabling analytics
cd /opt/deskdev
cat > .env << 'EOL'
APP_NAME=DeskDev.ai
APP_TITLE=DeskDev.ai - AI Software Engineer
OPENHANDS_GITHUB_CLIENT_ID=Ov23li90Lvf2AD0Jd8OA
OPENHANDS_GITHUB_CLIENT_SECRET=93cb0e2513c4a9a907ac78eb7243ae00327db9db
LLM_BASE_URL=http://host.docker.internal:11434
LLM_MODEL=deepseek-coder:base
LLM_PROVIDER=ollama
LLM_API_KEY=
LLM_API_VERSION=v1
RUNTIME_HOST=0.0.0.0
RUNTIME_PORT=30369
POSTHOG_ENABLED=false
POSTHOG_API_KEY=phc_disabled
EOL

# Update docker-compose.yml with PostHog settings
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

# Restart services
systemctl restart nginx

# Kill the old landing page server
pkill -f "node /opt/deskdev/landing-server.js" || true

# Start the new landing page server
node /opt/deskdev/landing-server.js > /opt/deskdev/landing.log 2>&1 &

# Restart the Docker container
docker-compose down
docker-compose up -d

echo "✅ App routing and PostHog issues fixed!"
echo "🌐 Landing page: http://31.97.61.137/"
echo "🚀 Application: http://31.97.61.137:3000"