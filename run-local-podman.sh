#!/bin/bash

# Drupal Local Development with Podman
# This script runs the Drupal application locally using Podman

set -e

echo "🚀 Starting Drupal application with Podman..."

# Create a network for the containers
echo "📡 Creating podman network..."
podman network create drupal-network 2>/dev/null || echo "Network already exists"

# Build the Drupal image
echo "🔨 Building Drupal image..."
podman build -t drupal-app:latest -f docker/Dockerfile .

# Run MariaDB container
echo "🗄️  Starting MariaDB container..."
podman run -d \
  --name drupal-mariadb \
  --network drupal-network \
  -e MYSQL_ROOT_PASSWORD=drupal123 \
  -e MYSQL_DATABASE=drupal \
  -e MYSQL_USER=drupal \
  -e MYSQL_PASSWORD=drupal123 \
  -p 3306:3306 \
  mariadb:10.6

# Wait for MariaDB to be ready
echo "⏳ Waiting for MariaDB to be ready..."
sleep 10

# Run Drupal container
echo "🌐 Starting Drupal container..."
podman run -d \
  --name drupal-app \
  --network drupal-network \
  -p 8080:80 \
  -p 8443:443 \
  -e DB_HOST=drupal-mariadb \
  -e DB_NAME=drupal \
  -e DB_USER=drupal \
  -e DB_PASS=drupal123 \
  drupal-app:latest

echo "✅ Drupal application is starting up!"
echo ""
echo "📋 Access Information:"
echo "   🌐 Drupal Site: http://localhost:8080"
echo "   🔐 Admin Panel: http://localhost:8080/user/login"
echo "   👤 Admin Username: admin"
echo "   🔑 Admin Password: admin123"
echo ""
echo "🗄️  Database Information:"
echo "   Host: localhost"
echo "   Port: 3306"
echo "   Database: drupal"
echo "   Username: drupal"
echo "   Password: drupal123"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs: podman logs drupal-app"
echo "   Stop containers: podman stop drupal-app drupal-mariadb"
echo "   Remove containers: podman rm drupal-app drupal-mariadb"
echo "   Remove network: podman network rm drupal-network"
echo ""
echo "⏳ Waiting for Drupal to be fully ready..."
sleep 15

# Check if Drupal is accessible
echo "🔍 Checking if Drupal is accessible..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302"; then
    echo "✅ Drupal is running successfully!"
else
    echo "⚠️  Drupal might still be starting up. Please wait a moment and try accessing http://localhost"
fi