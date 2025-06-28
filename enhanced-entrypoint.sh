#!/bin/bash

echo "Starting DeskDev.ai with enhanced features..."

# Set environment variables for branding
export APP_NAME="DeskDev.ai"
export APP_TITLE="DeskDev.ai - AI Software Engineer"
export LANDING_PAGE_ENABLED="true"
export GITHUB_AUTH_ENABLED="true"

# Auto-configure Ollama settings
export LLM_BASE_URL="http://host.docker.internal:11434"
export LLM_MODEL="deepseek-coder:base"
export LLM_API_KEY="ollama"
export LLM_API_VERSION="v1"
export LLM_PROVIDER="ollama"

# Setup authentication and database
python3 /app/setup-auth.py

# Create custom routes file
cat > /app/custom_routes.py << 'EOF'
from fastapi import FastAPI, Request, Response, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
import os

def setup_custom_routes(app: FastAPI):
    """Setup custom routes for DeskDev.ai"""
    
    # Mount static files
    if os.path.exists("/app/custom/static"):
        app.mount("/static", StaticFiles(directory="/app/custom/static"), name="static")
    
    @app.get("/", response_class=HTMLResponse)
    async def landing_page():
        """Serve landing page"""
        try:
            with open("/app/custom/templates/landing.html", "r") as f:
                return HTMLResponse(content=f.read())
        except FileNotFoundError:
            return RedirectResponse(url="/app")
    
    @app.get("/auth/github")
    async def github_auth():
        """GitHub OAuth redirect"""
        github_client_id = os.getenv("OPENHANDS_GITHUB_CLIENT_ID")
        if not github_client_id:
            return {"error": "GitHub OAuth not configured"}
        
        redirect_uri = f"{os.getenv('FRONTEND_URL', 'http://localhost:3000')}/auth/github/callback"
        github_url = f"https://github.com/login/oauth/authorize?client_id={github_client_id}&redirect_uri={redirect_uri}&scope=user:email"
        return RedirectResponse(url=github_url)
    
    @app.get("/auth/github/callback")
    async def github_callback(code: str = None):
        """Handle GitHub OAuth callback"""
        if not code:
            return RedirectResponse(url="/?error=auth_failed")
        
        # Here you would normally exchange the code for an access token
        # and create a user session. For now, redirect to the app.
        return RedirectResponse(url="/app")
    
    @app.get("/app")
    async def app_redirect():
        """Redirect to the main application"""
        return RedirectResponse(url="/")

EOF

# Inject custom routes into the main application
if [ -f "/app/openhands/server/listen.py" ]; then
    echo "Injecting custom routes..."
    cat >> /app/openhands/server/listen.py << 'EOF'

# DeskDev.ai Custom Routes
try:
    import sys
    sys.path.append('/app')
    from custom_routes import setup_custom_routes
    setup_custom_routes(app)
    print("Custom routes loaded successfully!")
except Exception as e:
    print(f"Failed to load custom routes: {e}")
EOF
fi

# Start the original application
exec /app/entrypoint.sh "$@"