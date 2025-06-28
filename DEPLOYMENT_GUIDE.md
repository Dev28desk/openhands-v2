# DeskDev.ai Comprehensive Deployment Guide

This guide provides detailed instructions for rebranding OpenHands to DeskDev.ai and deploying it on your Hostinger KVM4 VPS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Understanding the Codebase](#understanding-the-codebase)
3. [Rebranding Process](#rebranding-process)
4. [Deployment Process](#deployment-process)
5. [Post-Deployment Configuration](#post-deployment-configuration)
6. [Security Considerations](#security-considerations)
7. [Maintenance and Updates](#maintenance-and-updates)
8. [Troubleshooting](#troubleshooting)
9. [Additional Resources](#additional-resources)

## Prerequisites

Before you begin, ensure you have:

- Access to your Hostinger KVM4 VPS with root privileges
- SSH access to the VPS
- Docker installed on your local machine (for building the image)
- Git installed on your local machine
- Basic understanding of Docker, Linux, and web applications

## Understanding the Codebase

DeskDev.ai (formerly OpenHands) is an AI-powered software engineering assistant with:

- **Backend**: Python-based, located in the `openhands` directory
- **Frontend**: React-based, located in the `frontend` directory
- **Docker**: Containerization for easy deployment

Key components:
- **Agent**: The core AI entity that performs software development tasks
- **Microagents**: Specialized prompts that enhance the agent with domain-specific knowledge
- **Runtime**: The execution environment where agents perform their tasks

## Rebranding Process

The rebranding process involves:

1. Replacing all instances of "OpenHands" with "DeskDev.ai" in the codebase
2. Updating logos and branding assets
3. Modifying Docker-related files to use the new name
4. Updating configuration files

The `rebrand.sh` script automates this process.

## Deployment Process

The deployment process involves:

1. Building the Docker image locally
2. Transferring the image to your VPS
3. Setting up the necessary directories and configurations on the VPS
4. Creating a systemd service for automatic startup
5. Configuring Nginx as a reverse proxy

The `deploy.sh` script automates this process.

### One-Click Deployment

For a complete rebranding and deployment in one step, run:

```bash
./one-click-deploy.sh
```

### Manual Deployment Steps

If you prefer to run the steps individually:

#### 1. Set up SSH Key (Optional but Recommended)

```bash
./setup-ssh-key.sh
```

This script will:
- Generate an SSH key
- Copy it to your VPS
- Test the connection
- Update the deployment script to use the key

#### 2. Rebrand OpenHands to DeskDev.ai

```bash
./rebrand.sh
```

#### 3. Deploy to Hostinger KVM4 VPS

```bash
./deploy.sh
```

## Post-Deployment Configuration

After deployment, you may want to:

### 1. Configure a Domain Name

Update your domain's DNS settings to point to your VPS IP address.

### 2. Set up SSL with Let's Encrypt

```bash
ssh root@31.97.61.137
apt-get install certbot python3-certbot-nginx
certbot --nginx -d yourdomain.com
```

### 3. Customize the Application

Edit the configuration file:

```bash
nano /opt/deskdev/config/config.toml
```

### 4. Set up Email Notifications (Optional)

Install and configure a mail server like Postfix for email notifications.

## Security Considerations

To enhance security:

### 1. Create a Non-Root User

```bash
adduser deskdevadmin
usermod -aG sudo deskdevadmin
```

### 2. Configure Firewall

```bash
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
```

### 3. Regular Updates

Keep your system and application updated:

```bash
apt-get update && apt-get upgrade -y
```

### 4. Backup Strategy

Set up regular backups of your application data:

```bash
rsync -avz /opt/deskdev/data /backup/location/
```

## Maintenance and Updates

### Updating the Application

To update DeskDev.ai:

1. Pull the latest changes from the repository
2. Run the rebrand script again
3. Build and deploy the new version

### Monitoring

Monitor your application using:

```bash
# Check system resources
htop

# Check disk usage
df -h

# Check Docker container status
docker ps

# Check logs
journalctl -u deskdev
```

## Troubleshooting

### Common Issues and Solutions

#### Application Not Starting

Check the service status:

```bash
systemctl status deskdev
```

Check Docker logs:

```bash
docker logs deskdev-app
```

#### Nginx Configuration Issues

Test the Nginx configuration:

```bash
nginx -t
```

#### Permission Issues

Check directory permissions:

```bash
ls -la /opt/deskdev
```

### Getting Help

If you encounter issues not covered in this guide, you can:

1. Check the Docker container logs
2. Review the application logs
3. Consult the original OpenHands documentation
4. Contact support@deskdev.ai

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)

---

This guide was created to help you successfully rebrand OpenHands to DeskDev.ai and deploy it on your Hostinger KVM4 VPS. If you have any questions or need further assistance, please don't hesitate to reach out.