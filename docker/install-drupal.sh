#!/bin/bash

# Exit on any error
set -e

echo "Starting Drupal installation..."

# Check if Drupal is already installed
if [ -f "/var/www/html/web/sites/default/settings.php" ]; then
    echo "Drupal is already installed. Skipping installation."
    exit 0
fi

# Create web directory if it doesn't exist
mkdir -p /var/www/html/web

# Wait for MariaDB to be ready (max 5 minutes)
echo "Waiting for MariaDB to be ready..."
for i in {1..60}; do
    if timeout 5 bash -c "</dev/tcp/localhost/3306" 2>/dev/null; then
        echo "MariaDB is ready!"
        break
    fi
    echo "Waiting for MariaDB... (attempt $i/60)"
    sleep 5
done

# Check if MariaDB is accessible
if ! timeout 5 bash -c "</dev/tcp/localhost/3306" 2>/dev/null; then
    echo "ERROR: MariaDB is not accessible after 5 minutes"
    exit 1
fi

# Create Drupal in a temporary directory to avoid conflicts with existing structure
echo "Creating Drupal in temporary directory..."
cd /tmp
composer create-project drupal/recommended-project:^10 drupal-temp --no-interaction

# Move Drupal files to web directory, preserving EFS mount
echo "Moving Drupal files to web directory..."
cd /var/www/html

# Backup existing sites directory if it exists and is not a mount
if [ -d "web/sites" ] && ! mountpoint -q "web/sites/default/files"; then
    echo "Backing up existing sites directory..."
    mv web/sites web/sites.backup
fi

# Remove everything in web directory except EFS mount
echo "Cleaning web directory..."
rm -rf web/* 2>/dev/null || true

# Move Drupal files from temp directory
echo "Moving Drupal files..."
mv /tmp/drupal-temp/* web/
mv /tmp/drupal-temp/.* web/ 2>/dev/null || true

# Restore sites directory structure if needed
if [ -d "web/sites.backup" ]; then
    echo "Restoring sites directory..."
    mv web/sites.backup web/sites
fi

# Ensure proper permissions
echo "Setting proper permissions..."
chown -R www-data:www-data /var/www/html/web
chmod -R 755 /var/www/html/web

echo "Drupal installation completed successfully!"