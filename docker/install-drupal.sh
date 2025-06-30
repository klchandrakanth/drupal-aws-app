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
if [ "$(ls -A /var/www/html/web 2>/dev/null | grep -v '^\\.$' | grep -v '^\\.\\.$' | wc -l)" -gt 0 ]; then
    echo "Web directory is not empty. Cleaning it before installation..."

    # Handle EFS mount point first
    if [ -d "/var/www/html/web/sites/default/files" ]; then
        if mountpoint -q "/var/www/html/web/sites/default/files"; then
            echo "EFS mount detected at /var/www/html/web/sites/default/files - cleaning contents only"
            # Clean contents inside the mount instead of removing the mount point
            find /var/www/html/web/sites/default/files -mindepth 1 -delete 2>/dev/null || true
        else
            echo "Removing /var/www/html/web/sites/default/files (not a mount point)"
            rm -rf /var/www/html/web/sites/default/files
        fi
    fi

    # Remove all files and directories, but preserve the files directory if it's a mount
    if mountpoint -q "/var/www/html/web/sites/default/files" 2>/dev/null; then
        echo "Preserving EFS mount, removing other files..."
        # Remove everything except the files directory structure
        find /var/www/html/web -mindepth 1 -maxdepth 1 ! -name 'sites' -exec rm -rf {} + 2>/dev/null || true
        if [ -d "/var/www/html/web/sites" ]; then
            find /var/www/html/web/sites -mindepth 1 -maxdepth 1 ! -name 'default' -exec rm -rf {} + 2>/dev/null || true
            if [ -d "/var/www/html/web/sites/default" ]; then
                find /var/www/html/web/sites/default -mindepth 1 -maxdepth 1 ! -name 'files' -exec rm -rf {} + 2>/dev/null || true
            fi
        fi
    else
        echo "Removing all files from web directory..."
        rm -rf /var/www/html/web/*
        rm -rf /var/www/html/web/.[^.]* 2>/dev/null || true
    fi
fi

# Double-check that the directory is now empty (excluding . and ..)
if [ "$(ls -A /var/www/html/web 2>/dev/null | grep -v '^\\.$' | grep -v '^\\.\\.$' | wc -l)" -gt 0 ]; then
    echo "WARNING: Web directory is still not empty after cleanup. Forcing removal of remaining files..."
    # Force remove everything except the EFS mount
    if mountpoint -q "/var/www/html/web/sites/default/files" 2>/dev/null; then
        # Keep only the files directory structure
        find /var/www/html/web -mindepth 1 -maxdepth 1 ! -name 'sites' -exec rm -rf {} + 2>/dev/null || true
        if [ -d "/var/www/html/web/sites" ]; then
            find /var/www/html/web/sites -mindepth 1 -maxdepth 1 ! -name 'default' -exec rm -rf {} + 2>/dev/null || true
            if [ -d "/var/www/html/web/sites/default" ]; then
                find /var/www/html/web/sites/default -mindepth 1 -maxdepth 1 ! -name 'files' -exec rm -rf {} + 2>/dev/null || true
            fi
        fi
    else
        rm -rf /var/www/html/web/* 2>/dev/null || true
        rm -rf /var/www/html/web/.[^.]* 2>/dev/null || true
    fi
fi

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

# Handle the files directory properly after installation
echo "Setting up files directory..."
if [ -d "sites/default/files" ]; then
    if mountpoint -q "sites/default/files"; then
        echo "EFS mount is active at sites/default/files"
        # Ensure proper permissions on the mounted directory
        chown -R apache:apache sites/default/files 2>/dev/null || true
        chmod -R 755 sites/default/files 2>/dev/null || true
    else
        echo "Creating files directory with proper permissions"
        chown -R apache:apache sites/default/files
        chmod -R 755 sites/default/files
    fi
else
    echo "Creating files directory..."
    mkdir -p sites/default/files
    chown -R apache:apache sites/default/files
    chmod -R 755 sites/default/files
fi

# Set proper permissions for the entire web directory
echo "Setting permissions..."
chown -R apache:apache /var/www/html/web

echo "Drupal installation script completed."