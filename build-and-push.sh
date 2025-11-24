#!/bin/bash

# ============================================================================
# DOCKER BUILD AND PUSH SCRIPT
# ============================================================================
# This script builds your Docker image and pushes it to Docker Hub
# Usage: ./build-and-push.sh v1.0
# ============================================================================

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# CONFIGURATION - YOUR DOCKER HUB USERNAME
# ============================================================================
DOCKER_USERNAME="nyeinthunaing"
IMAGE_NAME="codedetect"
# ============================================================================

# Check if version provided
if [ -z "$1" ]; then
    print_error "Please provide a version tag!"
    echo "Usage: $0 <version>"
    echo "Example: $0 v1.0"
    exit 1
fi

VERSION=$1
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Docker Build and Push Script"
print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Image: $FULL_IMAGE_NAME"
print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Check if logged in to Docker Hub
if ! docker info 2>/dev/null | grep -q "Username: $DOCKER_USERNAME"; then
    print_info "Not logged in to Docker Hub. Logging in..."
    docker login
fi

# Step 1: Build the image
print_info "Step 1/4: Building Docker image..."
print_info "This may take 5-10 minutes (only needed once per version)..."
echo ""

docker build -t $FULL_IMAGE_NAME -t $LATEST_IMAGE_NAME .

if [ $? -eq 0 ]; then
    print_success "Docker image built successfully!"
else
    print_error "Docker build failed!"
    exit 1
fi

echo ""

# Step 2: Test the image locally
print_info "Step 2/4: Testing image locally..."
print_info "Starting container for health check..."

# Stop any existing test container
docker rm -f codedetect-test 2>/dev/null || true

# Run test container
docker run -d \
    --name codedetect-test \
    -p 5001:5000 \
    -e DATABASE_URL=sqlite:////app/instance/codedetect.db \
    $FULL_IMAGE_NAME

# Wait for container to be ready
print_info "Waiting for container to start..."
sleep 10

# Health check
if curl -f http://localhost:5001/api/health > /dev/null 2>&1; then
    print_success "Health check passed! ✓"
    docker logs codedetect-test --tail 10
else
    print_error "Health check failed!"
    print_info "Container logs:"
    docker logs codedetect-test
    docker rm -f codedetect-test
    exit 1
fi

# Cleanup test container
docker rm -f codedetect-test

echo ""

# Step 3: Push to Docker Hub
print_info "Step 3/4: Pushing image to Docker Hub..."
print_info "Pushing: $FULL_IMAGE_NAME"

docker push $FULL_IMAGE_NAME

if [ $? -eq 0 ]; then
    print_success "Version $VERSION pushed successfully!"
else
    print_error "Docker push failed!"
    exit 1
fi

# Also push latest tag
print_info "Pushing: $LATEST_IMAGE_NAME"
docker push $LATEST_IMAGE_NAME

echo ""

# Step 4: Summary
print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "BUILD AND PUSH COMPLETE!"
print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Image: $FULL_IMAGE_NAME"
print_info "Latest: $LATEST_IMAGE_NAME"
print_info ""
print_info "View on Docker Hub:"
print_info "https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}"
print_info ""
print_info "To pull this image on any machine:"
print_info "  docker pull $FULL_IMAGE_NAME"
print_info ""
print_info "To run this image:"
print_info "  docker run -p 5000:5000 $FULL_IMAGE_NAME"
print_info ""
print_info "Next steps:"
print_info "1. Deploy to AWS using: cd terraform && ./blue-green-deploy.sh"
print_info "2. Or manually: terraform apply -var='docker_tag=$VERSION'"
print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
