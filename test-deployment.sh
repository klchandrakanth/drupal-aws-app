#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if ALB DNS name is provided
if [ -z "$1" ]; then
    print_error "Please provide the ALB DNS name as an argument"
    echo "Usage: $0 <alb-dns-name>"
    echo "Example: $0 production-drupal-alb-123456789.us-east-1.elb.amazonaws.com"
    exit 1
fi

ALB_DNS_NAME=$1
APP_URL="http://$ALB_DNS_NAME"

print_status "Testing Drupal application deployment..."
print_status "Application URL: $APP_URL"

# Test 1: Check if ALB is responding
print_status "Test 1: Checking ALB response..."
if curl -s -f "$APP_URL" > /dev/null; then
    print_status "✅ ALB is responding"
else
    print_error "❌ ALB is not responding"
    exit 1
fi

# Test 2: Check if Drupal is accessible
print_status "Test 2: Checking Drupal accessibility..."
if curl -s "$APP_URL" | grep -q "Drupal"; then
    print_status "✅ Drupal is accessible"
else
    print_warning "⚠️  Drupal might not be fully loaded yet"
fi

# Test 3: Check HTTP status code
print_status "Test 3: Checking HTTP status code..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL")
if [ "$HTTP_STATUS" = "200" ]; then
    print_status "✅ HTTP status: $HTTP_STATUS"
else
    print_warning "⚠️  HTTP status: $HTTP_STATUS (might be normal during initial setup)"
fi

# Test 4: Check response time
print_status "Test 4: Checking response time..."
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$APP_URL")
print_status "Response time: ${RESPONSE_TIME}s"

# Test 5: Check if admin page is accessible
print_status "Test 5: Checking admin page..."
if curl -s "$APP_URL/user/login" | grep -q "Drupal"; then
    print_status "✅ Admin login page is accessible"
else
    print_warning "⚠️  Admin login page might not be ready yet"
fi

# Test 6: Check for common Drupal elements
print_status "Test 6: Checking for Drupal elements..."
if curl -s "$APP_URL" | grep -q "Welcome to Drupal AWS App"; then
    print_status "✅ Test content is present"
else
    print_warning "⚠️  Test content might not be loaded yet"
fi

# Test 7: Check HTTPS redirect (if configured)
print_status "Test 7: Checking HTTPS support..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$ALB_DNS_NAME" 2>/dev/null || echo "000")
if [ "$HTTPS_STATUS" != "000" ]; then
    print_status "✅ HTTPS is accessible (status: $HTTPS_STATUS)"
else
    print_warning "⚠️  HTTPS might not be configured yet"
fi

print_status "Testing completed!"
print_status "Application URL: $APP_URL"
print_status "Admin URL: $APP_URL/user/login"
print_status "Admin credentials: admin / admin123"

echo
print_warning "Note: If some tests show warnings, the application might still be initializing."
print_warning "Wait a few minutes and run the tests again if needed."