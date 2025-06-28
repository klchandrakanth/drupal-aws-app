#!/bin/bash

# Exit on any error
set -e

echo "Starting Drupal installation..."

# Check if Drupal is already installed
if [ -f "/var/www/html/web/sites/default/settings.php" ]; then
    echo "Drupal is already installed. Skipping installation."
    exit 0
fi

# Clean up /var/www/html before installing Drupal
rm -rf /var/www/html/*

# Install Drupal using Composer
composer create-project drupal/recommended-project:^10 /var/www/html --no-interaction

# Set proper permissions for Apache (CentOS uses apache user)
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Create settings.php from default
cp /var/www/html/web/sites/default/default.settings.php /var/www/html/web/sites/default/settings.php
chmod 644 /var/www/html/web/sites/default/settings.php

# Ensure sites/default and settings.php are writable before install
chown -R apache:apache /var/www/html/web/sites/default
chmod 775 /var/www/html/web/sites/default
if [ -f /var/www/html/web/sites/default/settings.php ]; then
  chmod 664 /var/www/html/web/sites/default/settings.php
fi

# Configure database settings (for local development)
cat >> /var/www/html/web/sites/default/settings.php << 'EOF'

// Database configuration for local development
$databases['default']['default'] = [
  'database' => getenv('DB_NAME') ?: 'drupal',
  'username' => getenv('DB_USER') ?: 'drupal',
  'password' => getenv('DB_PASS') ?: 'drupal123',
  'prefix' => '',
  'host' => getenv('DB_HOST') ?: 'drupal-mariadb',
  'port' => '3306',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
  'pdo' => [
    PDO::ATTR_PERSISTENT => FALSE,
  ],
];

// Trusted host patterns
$settings['trusted_host_patterns'] = [
  '^localhost$',
  '^.*\\.amazonaws\\.com$',
  '^.*\\.elasticbeanstalk\\.com$',
];

// File system settings
$settings['file_public_path'] = 'sites/default/files';
$settings['file_private_path'] = 'sites/default/files/private';

// Performance settings
$settings['cache']['bins']['render'] = 'cache.backend.memory';
$settings['cache']['bins']['dynamic_page_cache'] = 'cache.backend.memory';
$settings['cache']['bins']['page'] = 'cache.backend.memory';

// Error reporting
$config['system.logging']['error_level'] = 'verbose';
EOF

# Create files directory
mkdir -p /var/www/html/web/sites/default/files
chown -R apache:apache /var/www/html/web/sites/default/files
chmod -R 755 /var/www/html/web/sites/default/files

# Wait for MariaDB to be available
# MAX_TRIES=30
# TRIES=0
# until mysql -h "$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -e 'SELECT 1' "$DB_NAME" >/dev/null 2>&1; do
#   TRIES=$((TRIES+1))
#   if [ $TRIES -ge $MAX_TRIES ]; then
#     echo "MariaDB not available after $MAX_TRIES attempts. Drupal will need to be installed manually via web interface."
#     break
#   fi
#   echo "Waiting for MariaDB to be available... ($TRIES/$MAX_TRIES)"
#   sleep 2
# done

# Install Drupal using Drush (if database is available)
# if command -v mysql &> /dev/null; then
#     echo "Installing Drupal using Drush..."
#     cd /var/www/html/web
#
#     # Install Drupal with default settings
#     drush site:install --db-url=mysql://${DB_USER:-drupal}:${DB_PASS:-drupal123}@${DB_HOST:-localhost}/${DB_NAME:-drupal} \
#         --account-name=admin \
#         --account-pass=admin123 \
#         --account-mail=admin@example.com \
#         --site-name="Drupal AWS App" \
#         --site-mail=admin@example.com \
#         --yes
#
#     # Enable additional modules
#     drush en -y admin_toolbar admin_toolbar_tools admin_toolbar_search
#
#     # Import test content
#     echo "Creating test content..."
#
#     # Create test pages
#     drush node:create --type=page --title="Welcome to Drupal AWS App" \
#         --body="This is a test page for the Drupal AWS application. This page demonstrates that the application is working correctly."
#
#     drush node:create --type=page --title="About Us" \
#         --body="This is a sample about us page. You can customize this content according to your needs."
#
#     drush node:create --type=page --title="Contact Information" \
#         --body="Contact us at admin@example.com for any questions or support."
#
#     # Create test articles
#     drush node:create --type=article --title="Getting Started with Drupal" \
#         --body="Drupal is a powerful content management system that allows you to build amazing websites and applications."
#
#     drush node:create --type=article --title="AWS Deployment Guide" \
#         --body="This article explains how to deploy Drupal applications on AWS using ECS Fargate and other serverless services."
#
#     # Clear cache
#     drush cr
#
#     echo "Drupal installation completed successfully!"
# else
#     echo "MariaDB not available. Drupal will need to be installed manually via web interface."
#     echo "Database settings have been configured in settings.php"
# fi

# After installation, lock down permissions for security
chmod 644 /var/www/html/web/sites/default/settings.php
chmod 755 /var/www/html/web/sites/default

echo "Drupal installation script completed."