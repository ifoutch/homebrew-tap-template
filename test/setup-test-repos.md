# Setting Up Test Repositories

This guide helps you create the test repositories needed for validating download strategies.

## Why Service-Specific Repositories?

Each platform has unique characteristics that need testing:

- **GitHub**: Token format, raw.githubusercontent.com, Releases API
- **GitLab**: PRIVATE-TOKEN header, /-/raw/ paths, release links
- **S3**: AWS signatures, IAM permissions, bucket policies

Using service-specific repos ensures you catch platform-specific issues.

## Quick Setup Guide

### 1. GitHub Test Repository

```bash
# Create private repository
gh repo create homebrew-test-github --private

# Clone and add test files
git clone https://github.com/yourusername/homebrew-test-github
cd homebrew-test-github

# Add test file
cat << EOF > test-file.txt
Homebrew GitHub test file
Version: 1.0.0
Purpose: Download strategy testing
EOF

echo "# Homebrew Test Repo for GitHub" > README.md

# Create test archive
tar czf test-archive.tar.gz test-file.txt README.md

# Commit and push
git add .
git commit -m "Add test files"
git push

# Create a release with the archive
gh release create v1.0.0 test-archive.tar.gz \
  --title "Test Release v1.0.0" \
  --notes "Test release for Homebrew download strategies"
```

### 2. GitLab Test Repository

```bash
# Create via GitLab CLI (glab) or web interface
glab repo create homebrew-test-gitlab --private

# Clone and add test files
git clone https://gitlab.com/yourusername/homebrew-test-gitlab
cd homebrew-test-gitlab

# Add test files
cat << EOF > test-file.txt
Homebrew GitLab test file
Version: 1.0.0
Purpose: Download strategy testing
EOF

echo "# Homebrew Test Repo for GitLab" > README.md

# Create test archive
tar czf test-archive.tar.gz test-file.txt README.md

# Commit and push
git add .
git commit -m "Add test files"
git push

# Create release (via web UI or API)
# GitLab releases work differently - you need to create release links
```

### 3. S3 Test Bucket

```bash
# Create test bucket
aws s3 mb s3://homebrew-test-bucket

# Create test file
cat << EOF > test-file.txt
Homebrew AWS S3 test file
Version: 1.0.0
Purpose: Download strategy testing
EOF

echo "# Homebrew Test Repo for AWS S3" > README.md

# Create test archive
tar czf test-archive.tar.gz test-file.txt README.md

# Upload to S3
aws s3 cp test-archive.tar.gz s3://homebrew-test-bucket/test-files/
aws s3 cp test-file.txt s3://homebrew-test-bucket/test-files/
aws s3 cp README.md s3://homebrew-test-bucket/test-files/

# Set bucket policy for private access (default)
# Or create a public bucket for S3PublicDownloadStrategy testing
```

## Test File Structure

Each repository should contain:

```
homebrew-test-{platform}/
├── README.md           # Basic readme file
├── test-file.txt      # Simple text file for raw download testing
├── test-archive.tar.gz # Archive for release testing
└── releases/          # (Optional) Directory for release assets
    └── v1.0.0/
        └── test-binary
```

## Validation Content

For consistency, use these standard test contents:

**test-file.txt:**
```
Homebrew {Platform} test file
Version: 1.0.0
Purpose: Download strategy testing
```

**README.md:**
```markdown
# Homebrew Test Repository for {Platform}

This repository is used for testing Homebrew download strategies.

## Test Files
- test-file.txt: Simple text file for raw downloads
- test-archive.tar.gz: Archive for release downloads
```

## Setting Up Authentication

After creating repositories, ensure your environment variables are set:

```bash
# GitHub
export HOMEBREW_GITHUB_API_TOKEN="ghp_xxxxxxxxxxxx"

# GitLab
export HOMEBREW_GITLAB_API_TOKEN="glpat-xxxxxxxxxxxx"

# AWS S3
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxx"
export AWS_REGION="us-east-1"

# Generic Auth (choose one based on your test endpoint)
export HOMEBREW_BEARER_TOKEN="bearer_token_here"
# OR
export HOMEBREW_API_KEY="api_key_here"
# OR
export HOMEBREW_AUTH_USER="username"
export HOMEBREW_AUTH_PASSWORD="password"
```

## Updating test-config.yml

After creating your test repositories:

1. Copy the example config:
```bash
cp test/test-config.example.yml test/test-config.yml
```

2. Update with your actual URLs:
```yaml
github:
  raw_url: "https://raw.githubusercontent.com/yourusername/homebrew-test-github/main/test-file.txt"
  release_url: "https://github.com/yourusername/homebrew-test-github/releases/download/v1.0.0/test-archive.tar.gz"

gitlab:
  raw_url: "https://gitlab.com/yourusername/homebrew-test-gitlab/-/raw/main/test-file.txt"
  release_url: "https://gitlab.com/yourusername/homebrew-test-gitlab/-/releases/v1.0.0/downloads/test-archive.tar.gz"

# ... etc
```

## Running Tests

Once everything is set up:

```bash
# Run all tests
./test/run-tests.sh

# Or test individually
download-strategy-tester --strategy github-raw --config test/test-config.yml
download-strategy-tester --strategy gitlab-raw --config test/test-config.yml
```

## Troubleshooting

### Authentication Failures
- Verify tokens have correct permissions (repo access for GitHub/GitLab)
- Check token hasn't expired
- Ensure environment variables are exported, not just set

### Network Issues
- Some platforms may rate-limit; wait and retry
- Corporate networks may block certain services
- VPN may interfere with S3 region detection

### Platform-Specific Issues

**GitHub:**
- Personal access tokens need `repo` scope for private repos
- Fine-grained tokens need specific repository access

**GitLab:**
- Personal access tokens need `read_repository` scope minimum
- Self-hosted instances may have different API versions

**S3:**
- IAM user needs `s3:GetObject` permission minimum
- Check bucket policies don't override IAM permissions
- Ensure correct region is specified
