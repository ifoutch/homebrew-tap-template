# homebrew-tap-template

Template repository for creating private homebrew taps with support for multiple download strategies.

## Features

This tap template supports downloading from various sources:

- **GitHub** - Private repositories and release assets
- **GitLab** - Private repositories and releases  
- **AWS S3** - Private buckets with IAM/credential authentication
- **Generic URLs** - With Bearer tokens, API keys, Basic auth, or custom headers

## Setup

### Option 1: GitHub Web Interface

1. Click "Use this template" to create a new repository from this template
2. Name your new repository `homebrew-<your-tap-name>`
3. Clone your new repository locally
4. Update formulas in the `Formula/` directory
5. Set required environment variables for authentication

### Option 2: Command Line (GitHub CLI)

```bash
# Create a new repository from this template
gh repo create homebrew-<your-tap-name> --template yourusername/homebrew-tap-template --private

# Clone your new repository
git clone https://github.com/yourusername/homebrew-<your-tap-name>
cd homebrew-<your-tap-name>

# Update formulas and set environment variables as needed
```

### Next Steps

After creating your repository:
1. Update formulas in the `Formula/` directory
2. Set required environment variables for authentication
3. Test your formulas using the included test suite

## Environment Variables

Different download strategies require different environment variables:

### GitHub

**Option 1: Personal Access Token**
- `HOMEBREW_GITHUB_API_TOKEN` - GitHub personal access token with `repo` scope

**Option 2: GitHub CLI Authentication**
- Authenticate with `gh auth login` - the strategies will automatically use your `gh` credentials
- No environment variable needed if `gh` is authenticated

> **Note**: SSH keys alone are not sufficient for download strategies. The strategies need API access to download raw files and release assets, which requires either a personal access token or GitHub CLI authentication. SSH keys are only used for git operations (clone, push, pull).

### GitLab

**Option 1: Personal Access Token**
- `HOMEBREW_GITLAB_API_TOKEN` or `GITLAB_PRIVATE_TOKEN` - GitLab personal access token with `api` scope

**Option 2: GitLab CLI Authentication**
- Authenticate with `glab auth login` - the strategies will automatically use your `glab` credentials
- Also supports `GITLAB_TOKEN` environment variable that `glab` uses

### AWS S3
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `AWS_SESSION_TOKEN` - (Optional) For temporary credentials
- `AWS_REGION` or `AWS_DEFAULT_REGION` - AWS region

### Generic Authentication
- `HOMEBREW_BEARER_TOKEN` - Bearer token
- `HOMEBREW_API_KEY` - API key
- `HOMEBREW_AUTH_USER` and `HOMEBREW_AUTH_PASSWORD` - Basic auth credentials
- `HOMEBREW_AUTH_HEADER` and `HOMEBREW_AUTH_VALUE` - Custom header auth

## Usage Examples

### Installing from your tap

```bash
# Add the tap
brew tap yourusername/yourtap

# Install a formula
brew install yourusername/yourtap/yourformula
```

### Creating a Formula

See `Formula/examples.rb` for complete examples. Here's a simple GitHub private repo formula:

```ruby
require_relative "../download_strategies/github_private_repo_download_strategy"

class MyTool < Formula
  desc "My private tool"
  homepage "https://github.com/myorg/mytool"
  url "https://raw.githubusercontent.com/myorg/mytool/main/releases/mytool-v1.0.0.tar.gz",
      using: GitHubPrivateRepoDownloadStrategy
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end
```

## Available Download Strategies

1. **GitHubPrivateRepoDownloadStrategy** - Raw files from private GitHub repos
2. **GitHubReleaseDownloadStrategy** - GitHub release assets
3. **GitLabPrivateRepoDownloadStrategy** - Raw files from private GitLab repos
4. **GitLabReleaseDownloadStrategy** - GitLab release assets
5. **S3DownloadStrategy** - AWS S3 private buckets
6. **S3PublicDownloadStrategy** - AWS S3 public buckets
7. **AuthenticatedDownloadStrategy** - Generic authenticated URLs

## Testing

### Testing Formulas

Test your formulas locally:

```bash
brew install --verbose --debug Formula/yourformula.rb
```

### Testing Download Strategies

This tap includes a comprehensive test suite for validating all download strategies:

#### Quick Setup

1. Install the test utility:
```bash
brew install Formula/download-strategy-tester.rb
```

2. Run tests:
```bash
# Check your environment setup
download-strategy-tester --check-env

# Test all strategies
download-strategy-tester --all

# Test a specific strategy
download-strategy-tester --strategy github-raw
```

#### Using Custom Test URLs

1. Copy the example config:
```bash
cp test/test-config.example.yml test/test-config.yml
```

2. Edit `test/test-config.yml` with your actual repository URLs

3. Run tests with config:
```bash
download-strategy-tester --all --config test/test-config.yml
```

#### Automated Test Runner

Use the included test runner script:

```bash
./test/run-tests.sh
```

This will check prerequisites, validate environment variables, and run all tests.

## Security Notes

- Never commit tokens or credentials to the repository
- Use environment variables for all authentication
- Consider using GitHub Secrets for CI/CD workflows
- Rotate tokens regularly

## License

This template is released under the Unlicense (public domain).