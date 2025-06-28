#!/bin/bash

# Exit on any error
set -e

# Configuration
AWS_REGION="us-east-1"
ECR_REPOSITORY="drupal-aws-app"
IMAGE_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

print_status "Starting deployment process..."

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account ID: $AWS_ACCOUNT_ID"

# Create ECR repository if it doesn't exist
print_status "Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION &> /dev/null; then
    print_status "Creating ECR repository..."
    aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
fi

# Get ECR login token
print_status "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build Docker image
print_status "Building Docker image..."
docker build -t $ECR_REPOSITORY:$IMAGE_TAG ./docker

# Tag image for ECR
ECR_IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG"
docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_IMAGE_URI

# Push image to ECR
print_status "Pushing image to ECR..."
docker push $ECR_IMAGE_URI

print_status "Docker image pushed successfully: $ECR_IMAGE_URI"

# Update terraform.tfvars with the correct image URI
print_status "Updating Terraform configuration..."
sed -i.bak "s|app_image = \".*\"|app_image = \"$ECR_IMAGE_URI\"|" terraform/terraform.tfvars

# Initialize Terraform
print_status "Initializing Terraform..."
cd terraform
terraform init

# Plan Terraform deployment
print_status "Planning Terraform deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo
print_warning "Do you want to proceed with the deployment? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    print_status "Applying Terraform configuration..."
    terraform apply tfplan

    # Get the ALB DNS name
    ALB_DNS_NAME=$(terraform output -raw alb_dns_name)
    print_status "Deployment completed successfully!"
    print_status "Your Drupal application is available at: http://$ALB_DNS_NAME"
    print_status "Admin credentials: admin / admin123"
else
    print_warning "Deployment cancelled."
    exit 0
fi

# Clean up
rm -f tfplan
rm -f terraform.tfvars.bak

print_status "Deployment script completed!"