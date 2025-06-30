#!/bin/bash

# Exit on any error
set -e

echo "Setting up Drupal configuration..."

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

# Ensure the files directory exists and has proper permissions
echo "Setting up files directory..."
cd /var/www/html/web

# Create files directory if it doesn't exist
if [ ! -d "sites/default/files" ]; then
    mkdir -p sites/default/files
fi

# Set proper permissions for the files directory
chown -R apache:apache sites/default/files
chmod -R 755 sites/default/files

# Check if settings.php exists, if not create a basic one
if [ ! -f "sites/default/settings.php" ]; then
    echo "Creating basic settings.php..."
    if [ -f "sites/default/default.settings.php" ]; then
        cp sites/default/default.settings.php sites/default/settings.php
    else
        echo "default.settings.php not found, creating minimal settings.php..."
        cat > sites/default/settings.php << 'EOF'
<?php

/**
 * @file
 * Drupal site-specific configuration file.
 */

$databases['default']['default'] = [
  'database' => $_ENV['DB_NAME'],
  'username' => $_ENV['DB_USER'],
  'password' => $_ENV['DB_PASS'],
  'host' => '127.0.0.1',
  'port' => '3306',
  'driver' => 'mysql',
  'prefix' => '',
];

$settings['hash_salt'] = 'drupal-hash-salt-' . uniqid();
$settings['config_sync_directory'] = '../config/sync';

// Trusted host patterns
$settings['trusted_host_patterns'] = [
  '^.*\.amazonaws\.com$',
  '^.*\.elb\.amazonaws\.com$',
];

// File system settings
$settings['file_public_path'] = 'sites/default/files';
$settings['file_private_path'] = 'sites/default/files/private';

// Skip file permissions check
$settings['skip_permissions_hardening'] = TRUE;
EOF
    fi
    chown apache:apache sites/default/settings.php
    chmod 644 sites/default/settings.php
fi

# Check if Drupal is already installed
echo "Checking if Drupal is installed..."
if php core/scripts/drupal status bootstrap 2>/dev/null; then
    echo "Drupal appears to be installed, but forcing reinstallation..."
fi

echo "Installing Drupal using Drush..."

# Install Drupal using Drush
vendor/bin/drush site:install standard \
    --db-url="mysql://${DB_USER}:${DB_PASS}@127.0.0.1:3306/${DB_NAME}" \
    --account-name=admin \
    --account-pass=admin123 \
    --account-mail=admin@example.com \
    --site-name="Drupal on AWS" \
    --site-mail=admin@example.com \
    --yes

echo "Drupal installation completed!"

echo "Drupal configuration completed successfully!"