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

# Check if web directory is empty (excluding . and ..)
if [ "$(ls -A /var/www/html/web 2>/dev/null | grep -v '^\.$' | grep -v '^\.\.$' | wc -l)" -gt 0 ]; then
    echo "Web directory is not empty. Cleaning it before installation..."
    rm -rf /var/www/html/web/*
    rm -rf /var/www/html/web/.[^.]* 2>/dev/null || true
fi

# Wait for MariaDB to be ready (max 5 minutes)
echo "Waiting for MariaDB to be ready..."
for i in {1..60}; do
    if mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD:-root}" --silent; then
        echo "MariaDB is ready!"
        break
    fi
    echo "Waiting for MariaDB... (attempt $i/60)"
    sleep 5
done

# Check if MariaDB is accessible
if ! mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD:-root}" --silent; then
    echo "ERROR: MariaDB is not accessible after 5 minutes"
    exit 1
fi

# Change to web directory
cd /var/www/html/web
echo "Changed to web directory: $(pwd)"

# Install Drupal with increased timeout and memory limit
echo "Installing Drupal using Composer..."
export COMPOSER_MEMORY_LIMIT=-1
export COMPOSER_PROCESS_TIMEOUT=600

# Check if composer is available
if ! command -v composer &> /dev/null; then
    echo "ERROR: Composer is not available"
    exit 1
fi

echo "Composer version: $(composer --version)"

# Run composer create-project with verbose output and error handling
echo "Running composer create-project..."
if ! composer create-project drupal/recommended-project:^10 . --no-interaction --prefer-dist --verbose; then
    echo "ERROR: Composer create-project failed"
    exit 1
fi

echo "Drupal installation completed successfully!"

# Set proper permissions
echo "Setting permissions..."
chown -R apache:apache /var/www/html/web
chmod -R 755 /var/www/html/web/sites/default/files

echo "Drupal installation script completed."