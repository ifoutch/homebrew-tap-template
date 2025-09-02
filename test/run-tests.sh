#!/bin/bash

# Test runner script for download strategies
# This script sets up a test environment and runs the download strategy tests

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Download Strategy Test Runner"
echo "=========================================="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "Checking prerequisites..."

if ! command_exists brew; then
    echo -e "${RED}✗ Homebrew is not installed${NC}"
    echo "  Please install Homebrew from https://brew.sh"
    exit 1
else
    echo -e "${GREEN}✓ Homebrew found${NC}"
fi

if ! command_exists ruby; then
    echo -e "${RED}✗ Ruby is not installed${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Ruby found${NC}"
fi

# Check for test config
CONFIG_FILE="${SCRIPT_DIR}/test-config.yml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}! No test-config.yml found${NC}"
    echo "  Creating from example..."
    cp "${SCRIPT_DIR}/test-config.example.yml" "$CONFIG_FILE"
    echo -e "${GREEN}  Created test-config.yml${NC}"
    echo -e "${YELLOW}  Please edit ${CONFIG_FILE} with your test URLs${NC}"
fi

# Check environment variables
echo ""
echo "Checking environment variables..."

check_env() {
    local var_name=$1
    local service=$2
    if [ -n "${!var_name}" ]; then
        echo -e "${GREEN}✓ ${var_name} is set${NC}"
        return 0
    else
        echo -e "${YELLOW}! ${var_name} is not set (required for ${service})${NC}"
        return 1
    fi
}

ENV_OK=true

# GitHub
if ! check_env "HOMEBREW_GITHUB_API_TOKEN" "GitHub"; then
    ENV_OK=false
fi

# GitLab
if [ -z "$HOMEBREW_GITLAB_API_TOKEN" ] && [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
    echo -e "${YELLOW}! HOMEBREW_GITLAB_API_TOKEN or GITLAB_PRIVATE_TOKEN not set (required for GitLab)${NC}"
    ENV_OK=false
else
    echo -e "${GREEN}✓ GitLab token is set${NC}"
fi

# AWS S3
if ! check_env "AWS_ACCESS_KEY_ID" "AWS S3"; then
    ENV_OK=false
fi
if ! check_env "AWS_SECRET_ACCESS_KEY" "AWS S3"; then
    ENV_OK=false
fi

# Generic auth (at least one should be set)
if [ -z "$HOMEBREW_BEARER_TOKEN" ] && \
   [ -z "$HOMEBREW_API_KEY" ] && \
   [ -z "$HOMEBREW_AUTH_USER" ]; then
    echo -e "${YELLOW}! No generic auth credentials set${NC}"
    echo "  Set one of: HOMEBREW_BEARER_TOKEN, HOMEBREW_API_KEY, or HOMEBREW_AUTH_USER+PASSWORD"
fi

if [ "$ENV_OK" = false ]; then
    echo ""
    echo -e "${YELLOW}Warning: Some environment variables are missing.${NC}"
    echo "Tests for those strategies will be skipped."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run the tests
echo ""
echo "Running download strategy tests..."
echo "=========================================="

# Direct Ruby execution for testing
ruby "${SCRIPT_DIR}/download-strategy-tester.rb" \
    --all \
    --config "$CONFIG_FILE" \
    --verbose

TEST_RESULT=$?

echo ""
echo "=========================================="

if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}Some tests failed.${NC}"
    echo "Check the output above for details."
fi

exit $TEST_RESULT