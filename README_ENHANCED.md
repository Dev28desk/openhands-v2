# DeskDev.ai Enhanced - AI-Powered Software Development Platform

## 🚀 Features

- **🎨 Beautiful Landing Page**: Modern, responsive design with Tailwind CSS
- **🔐 GitHub Authentication**: One-click sign-in with GitHub OAuth
- **🤖 Pre-configured AI**: Ollama with DeepSeek Coder model ready to use
- **⚡ Auto-configuration**: No manual LLM setup required
- **🎯 Complete Rebranding**: Full DeskDev.ai branding throughout
- **💾 User Management**: SQLite database for user sessions and settings
- **🔒 Secure**: Local AI processing with data privacy

## 📦 Quick Deployment

### Prerequisites
- Ubuntu 24.04 VPS with Docker
- Root access to your server
- GitHub OAuth App configured

### One-Command Deployment

```bash
chmod +x deploy-enhanced.sh && ./deploy-enhanced.sh
```

### Manual Deployment

1. **Install Ollama**:
```bash
curl -fsSL https://ollama.ai/install.sh | sh
sudo systemctl enable ollama && sudo systemctl start ollama
ollama pull deepseek-coder:base
```

2. **Clone and Build**:
```bash
git clone https://github.com/Dev28desk/openhands-v2.git
cd openhands-v2
docker build -t deskdev:enhanced -f Dockerfile.enhanced .
```

3. **Deploy**:
```bash
mkdir -p /opt/deskdev/{data,workspace}
cp docker-compose.enhanced.yml /opt/deskdev/docker-compose.yml
cd /opt/deskdev && docker-compose up -d
```

## 🔧 Configuration

### GitHub OAuth Setup
1. Go to GitHub Settings > Developer settings > OAuth Apps
2. Create new OAuth App:
   - Application name: `DeskDev.ai`
   - Homepage URL: `http://your-server-ip`
   - Authorization callback URL: `http://your-server-ip/auth/github/callback`
3. Update environment variables in `docker-compose.enhanced.yml`

### Environment Variables
```bash
OPENHANDS_GITHUB_CLIENT_ID=your_client_id
OPENHANDS_GITHUB_CLIENT_SECRET=your_client_secret
LLM_MODEL=deepseek-coder:base
LLM_BASE_URL=http://host.docker.internal:11434
```

## 📁 Project Structure

```
├── custom/
│   ├── templates/
│   │   └── landing.html          # Landing page template
│   ├── static/
│   │   └── css/
│   │       └── custom.css        # Custom styling
│   └── rebrand.sh               # Rebranding script
├── Dockerfile.enhanced          # Enhanced Docker build
├── docker-compose.enhanced.yml  # Production compose file
├── enhanced-entrypoint.sh       # Custom entrypoint
├── setup-auth.py               # Authentication setup
└── deploy-enhanced.sh          # Deployment script
```

## 🌐 Usage

1. **Access Landing Page**: Visit `http://your-server-ip`
2. **Sign In**: Click "Sign in with GitHub"
3. **Start Coding**: Begin using AI-powered development tools
4. **No Configuration**: Ollama and DeepSeek Coder are pre-configured

## 🔍 Monitoring

```bash
# Check container status
docker ps

# View application logs
docker logs deskdev-app

# Check Ollama status
curl http://localhost:11434/api/tags

# Restart services
cd /opt/deskdev && docker-compose restart
```

## 🛠️ Customization

### Modify Landing Page
Edit `custom/templates/landing.html` and rebuild:
```bash
docker build -t deskdev:enhanced -f Dockerfile.enhanced .
docker-compose restart
```

### Update Styling
Modify `custom/static/css/custom.css` and restart the container.

### Change AI Model
Update `LLM_MODEL` environment variable in docker-compose file.

## 🔒 Security

- All AI processing happens locally with Ollama
- GitHub OAuth for secure authentication
- User data stored in local SQLite database
- No external API calls for AI functionality

## 📞 Support

For issues or questions:
1. Check container logs: `docker logs deskdev-app`
2. Verify Ollama status: `ollama list`
3. Ensure GitHub OAuth is properly configured
4. Check firewall settings for ports 80 and 3001

## 🎯 Next Steps

After deployment:
1. Configure your domain name (optional)
2. Set up SSL with Let's Encrypt
3. Configure backup for user data
4. Monitor resource usage

---

**DeskDev.ai Enhanced** - Your complete AI-powered development platform, ready in minutes!