#!/bin/bash
set -e

echo "🌐 Setting up DeskDev.ai landing page..."

# Create directory structure
mkdir -p /opt/deskdev/custom/{templates,static/{css,images}}

# Download the custom icon
curl -o /opt/deskdev/custom/static/images/deskdev-logo.png https://developers.redhat.com/sites/default/files/styles/keep_original/public/ML%20models.png?itok=T-pMYACJ

# Create custom CSS
cat > /opt/deskdev/custom/static/css/custom-icon.css << 'EOL'
.app-logo, .logo-image {
  background-image: url('/custom/static/images/deskdev-logo.png') !important;
  background-size: contain !important;
  background-repeat: no-repeat !important;
  background-position: center !important;
}
EOL

# Create landing page HTML
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
                    <a href="/app" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
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
            <a href="/app" class="bg-blue-600 hover:bg-blue-700 text-white px-8 py-4 rounded-lg text-lg font-semibold">
                Get Started
            </a>
        </div>
    </div>
</body>
</html>
EOL

# Create a simple landing page server using Node.js instead of Flask
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
    res.writeHead(302, { 'Location': 'http://localhost:3000' });
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

# Install Node.js if not already installed
if ! command -v node &> /dev/null; then
  echo "Installing Node.js..."
  apt-get update
  apt-get install -y nodejs npm
fi

# Start the Node.js server
node /opt/deskdev/landing-server.js > /opt/deskdev/landing.log 2>&1 &

# Configure Nginx
apt-get install -y nginx

cat > /etc/nginx/sites-available/deskdev << 'EOL'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /app {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /socket.io {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /custom {
        alias /opt/deskdev/custom;
    }
}
EOL

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/deskdev /etc/nginx/sites-enabled/
systemctl restart nginx

echo "✅ Landing page setup complete! Visit http://31.97.61.137/ to see your new landing page."