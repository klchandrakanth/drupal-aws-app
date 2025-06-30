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
EOF
    fi
    chown apache:apache sites/default/settings.php
    chmod 644 sites/default/settings.php
fi

echo "Drupal configuration completed successfully!"