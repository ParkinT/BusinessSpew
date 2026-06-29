#!/bin/bash

# DigitalOcean Deployment Script

set -e

# Configuration
APP_NAME="business-spew"
SSH_USER="root"
SERVER_IP="$1"
DEPLOYMENT_PATH="/var/www/$APP_NAME"
RESTART_SCRIPT="/etc/init.d/nginx"

# Check arguments
if [ -z "$SERVER_IP" ]; then
  echo "Usage: $0 <server-ip>"
  exit 1
fi

echo "Deploying to $SERVER_IP..."

# Archive the application
echo " Packing application..."
tar -czf business-spew.tar.gz app.rb config.ru lib public views Gemfile* fly.toml digitalocean-deploy.sh

# Transfer to server
echo " Uploading to server..."
scp business-spew.tar.gz "$SSH_USER@$SERVER_IP:$DEPLOYMENT_PATH"

# SSH into server and deploy
echo " Deploying..."
ssh "$SSH_USER@$SERVER_IP" <<EOF
    set -e
    
    echo "Stopping existing service..."
    kill -SIGTERM $(cat $DEPLOYMENT_PATH/pid) 2>/dev/null || true
    
    cd $DEPLOYMENT_PATH
    
    echo "Extracting new version..."
    tar -xzvf business-spew.tar.gz --strip-components=1
    
    echo "Installing dependencies..."
    gem install bundler && bundle install --path vendor/bundle
    
    echo "Compiling assets..."
    # Add any asset compilation steps here
    
    echo "Generating PID file..."
    touch pid && chmod 755 pid
    
    echo "Starting service..."
    export RACK_ENV=production
    nohup rackup config.ru -p 3000 > log/production.log 2>&1 &
    
    # Save PID
    echo \$! > pid
    
    echo "Cleaning up..."
    rm business-spew.tar.gz
    
    echo "Deployment complete!"
EOF

# Kill any lingering processes
ssh "$SSH_USER@$SERVER_IP" <<EOF
    killall -SIGTERM rackup 2>/dev/null || true
    killall -SIGTERM ruby 2>/dev/null || true
EOF

# Restart Nginx
echo "Restarting Nginx..."
ssh "$SSHsystem" "sudo service nginx restart"

echo "Deployment to DigitalOcean complete!"

