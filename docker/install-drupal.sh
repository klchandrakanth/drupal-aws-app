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

# Change to web directory
cd /var/www/html/web

# Install Drupal using Composer
echo "Installing Drupal using Composer..."
composer create-project drupal/recommended-project:^10 . --no-interaction

# Handle files directory - check if EFS is mounted
if mountpoint -q /var/www/html/web/sites/default/files; then
    echo "EFS volume is mounted at sites/default/files. Using existing mount."
    # Ensure proper permissions on the mounted directory
    chown -R apache:apache sites/default/files 2>/dev/null || true
    chmod -R 755 sites/default/files 2>/dev/null || true
else
    echo "Creating files directory with proper permissions..."
    # Only try to remove if it's not a mount point and exists
    if [ -d "sites/default/files" ] && ! mountpoint -q sites/default/files; then
        rm -rf sites/default/files 2>/dev/null || echo "Could not remove files directory, continuing..."
    fi
    mkdir -p sites/default/files
    chown -R apache:apache sites/default/files
    chmod -R 755 sites/default/files
fi

# Wait for MariaDB to be available
MAX_TRIES=30
TRIES=0
until mysql -h "$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -e 'SELECT 1' "$DB_NAME" >/dev/null 2>&1; do
  TRIES=$((TRIES+1))
  if [ $TRIES -ge $MAX_TRIES ]; then
    echo "MariaDB not available after $MAX_TRIES attempts. Drupal will need to be installed manually via web interface."
    break
  fi
  echo "Waiting for MariaDB to be available... ($TRIES/$MAX_TRIES)"
  sleep 2
done

# Install Drupal using Drush (if database is available)
if command -v mysql &> /dev/null; then
    echo "Installing Drupal using Drush..."
    cd /var/www/html/web

    # Create settings.php from default
    cp sites/default/default.settings.php sites/default/settings.php

    # Install Drupal using Drush
    drush site:install --db-url="mysql://$DB_USER:$DB_PASS@$DB_HOST:3306/$DB_NAME" \
        --account-name=admin \
        --account-pass=admin123 \
        --site-name="My Drupal Site" \
        --yes

    # Create some test content
    echo "Creating test content..."
    drush en -y node_revision_delete
    drush en -y pathauto

    # Create a test article
    drush node:create --type=article --title="Welcome to Drupal on AWS" \
        --body="This is a test article created automatically during installation. Your Drupal site is now running on AWS with ECS Fargate!"

    echo "Drupal installation completed successfully!"
else
    echo "MySQL client not available. Drupal will need to be installed manually via web interface."
fi

echo "Drupal installation script completed."