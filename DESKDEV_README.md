# DeskDev.ai Deployment Guide

This guide provides instructions for rebranding OpenHands to DeskDev.ai and deploying it on your Hostinger KVM4 VPS.

## Prerequisites

- Access to your Hostinger KVM4 VPS with root privileges
- SSH access to the VPS
- Docker installed on your local machine (for building the image)

## One-Click Deployment

For a complete rebranding and deployment in one step, run:

```bash
./one-click-deploy.sh
```

This script will:
1. Rebrand OpenHands to DeskDev.ai
2. Build the Docker image
3. Deploy the application to your Hostinger KVM4 VPS

## Manual Deployment Steps

If you prefer to run the steps individually:

### 1. Rebrand OpenHands to DeskDev.ai

```bash
./rebrand.sh
```

### 2. Deploy to Hostinger KVM4 VPS

```bash
./deploy.sh
```

## Accessing DeskDev.ai

After deployment, you can access DeskDev.ai at:

```
http://31.97.61.137
```

## Configuration

The application configuration is stored in:

```
/opt/deskdev/config/config.toml
```

## Workspace Directory

The workspace directory is mounted at:

```
/opt/deskdev/workspace
```

## Managing the Service

You can manage the DeskDev.ai service using systemd:

```bash
# Check status
systemctl status deskdev

# Restart service
systemctl restart deskdev

# Stop service
systemctl stop deskdev

# Start service
systemctl start deskdev
```

## Logs

You can view the logs using:

```bash
# View service logs
journalctl -u deskdev

# View Docker container logs
docker logs deskdev-app
```

## Security Recommendations

For production use:
1. Set up SSL with Let's Encrypt
2. Configure a domain name
3. Set up a firewall
4. Create a non-root user for SSH access

## Customization

To customize the DeskDev.ai logo:
1. Replace the placeholder logo files in `frontend/src/assets/branding/deskdev/` with your actual logo
2. Rebuild and redeploy the application

## Troubleshooting

If you encounter issues:
1. Check the Docker container logs
2. Verify that all required ports are open
3. Check the Nginx configuration
4. Ensure Docker is running properly

For additional help, please contact support@deskdev.ai