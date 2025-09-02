# Example formulas showing how to use each download strategy

# 1. GitHub Private Repository (raw files)
require_relative "../download_strategies/github_private_repo_download_strategy"

class MyToolFromGithubRaw < Formula
  desc "Tool from private GitHub repository raw file"
  homepage "https://github.com/myorg/mytool"
  url "https://raw.githubusercontent.com/myorg/mytool/main/releases/mytool-v1.0.0.tar.gz",
      using: GitHubPrivateRepoDownloadStrategy
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 2. GitHub Release Assets
require_relative "../download_strategies/github_release_download_strategy"

class MyToolFromGithubRelease < Formula
  desc "Tool from GitHub release assets"
  homepage "https://github.com/myorg/mytool"
  url "https://github.com/myorg/mytool/releases/download/v1.0.0/mytool-darwin-amd64.tar.gz",
      using: GitHubReleaseDownloadStrategy
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 3. GitLab Private Repository
require_relative "../download_strategies/gitlab_private_repo_download_strategy"

class MyToolFromGitlab < Formula
  desc "Tool from private GitLab repository"
  homepage "https://gitlab.com/myorg/mytool"
  url "https://gitlab.com/myorg/mytool/-/raw/main/releases/mytool-v1.0.0.tar.gz",
      using: GitLabPrivateRepoDownloadStrategy
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 4. GitLab Release
require_relative "../download_strategies/gitlab_private_repo_download_strategy"

class MyToolFromGitlabRelease < Formula
  desc "Tool from GitLab release"
  homepage "https://gitlab.com/myorg/mytool"
  url "https://gitlab.com/myorg/mytool/-/releases/v1.0.0/downloads/mytool-darwin-amd64.tar.gz",
      using: GitLabReleaseDownloadStrategy
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 5. AWS S3 Private Bucket
require_relative "../download_strategies/s3_download_strategy"

class MyToolFromS3 < Formula
  desc "Tool from AWS S3 private bucket"
  homepage "https://example.com/mytool"
  url "s3://my-private-bucket/releases/mytool-v1.0.0.tar.gz",
      using: S3DownloadStrategy
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 6. Generic Authenticated URL (Bearer Token)
require_relative "../download_strategies/authenticated_download_strategy"

class MyToolWithBearerAuth < Formula
  desc "Tool requiring Bearer token authentication"
  homepage "https://example.com/mytool"
  url "https://api.example.com/downloads/mytool-v1.0.0.tar.gz",
      using: AuthenticatedDownloadStrategy,
      auth_type: :bearer
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 7. Generic Authenticated URL (API Key)
require_relative "../download_strategies/authenticated_download_strategy"

class MyToolWithApiKey < Formula
  desc "Tool requiring API key authentication"
  homepage "https://example.com/mytool"
  url "https://api.example.com/downloads/mytool-v1.0.0.tar.gz",
      using: AuthenticatedDownloadStrategy,
      auth_type: :api_key,
      api_key_header: "X-Custom-API-Key"
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 8. Generic Authenticated URL (Basic Auth)
require_relative "../download_strategies/authenticated_download_strategy"

class MyToolWithBasicAuth < Formula
  desc "Tool requiring basic authentication"
  homepage "https://example.com/mytool"
  url "https://download.example.com/mytool-v1.0.0.tar.gz",
      using: AuthenticatedDownloadStrategy,
      auth_type: :basic
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end

# 9. Custom Headers
require_relative "../download_strategies/authenticated_download_strategy"

class MyToolWithCustomHeaders < Formula
  desc "Tool requiring custom headers"
  homepage "https://example.com/mytool"
  url "https://api.example.com/downloads/mytool-v1.0.0.tar.gz",
      using: AuthenticatedDownloadStrategy,
      auth_type: :header,
      headers: {
        "X-Custom-Header" => "custom-value",
        "X-Another-Header" => "another-value"
      }
  version "1.0.0"
  sha256 "abc123..."

  def install
    bin.install "mytool"
  end
end