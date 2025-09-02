require "download_strategy"
require "json"

class GitHubReleaseDownloadStrategy < CurlDownloadStrategy
  require "utils/github"
  require "utils/shell"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    # Support both API URLs and standard GitHub release URLs
    if match = url.match(%r{https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)})
      _, @owner, @repo, @tag, @filename = *match
      @use_api = false
    elsif match = url.match(%r{https://api\.github\.com/repos/([^/]+)/([^/]+)/releases/assets/([^/]+)})
      _, @owner, @repo, @asset_id = *match
      @use_api = true
    elsif match = url.match(%r{https://github\.com/([^/]+)/([^/]+)/releases/latest/download/(.+)})
      _, @owner, @repo, @filename = *match
      @tag = "latest"
      @use_api = false
    else
      raise ArgumentError, "Invalid URL for GitHubReleaseDownloadStrategy: #{url}"
    end
  end

  def set_github_token
    @github_token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    
    # Fallback to GitHub CLI authentication if available
    unless @github_token
      @github_token = get_gh_token
    end
    
    unless @github_token
      raise CurlDownloadStrategyError, "GitHub authentication required. Set HOMEBREW_GITHUB_API_TOKEN or authenticate with 'gh auth login'."
    end
  end

  def get_gh_token
    # Check if gh CLI is available and authenticated
    return nil unless system("which gh > /dev/null 2>&1")
    return nil unless system("gh auth status > /dev/null 2>&1")
    
    # Get token from gh CLI
    token_output = Utils.safe_popen_read("gh", "auth", "token")
    token_output.strip if $?.success? && !token_output.strip.empty?
  rescue
    nil
  end

  def _fetch(url:, resolved_url:, timeout:)
    if @use_api
      # For API URLs, we need to use the Accept header for the actual asset
      curl_download asset_url, 
        "--header", "Authorization: token #{@github_token}",
        "--header", "Accept: application/octet-stream",
        "--location",
        to: temporary_path, 
        timeout: timeout
    else
      # For direct release URLs
      curl_download download_url,
        "--header", "Authorization: token #{@github_token}",
        "--location",
        to: temporary_path,
        timeout: timeout
    end
  end

  private

  def asset_url
    "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{@asset_id}"
  end

  def download_url
    if @tag == "latest"
      # First get the latest release tag
      latest_release_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/latest"
      
      output = Utils.safe_popen_read("curl", "-H", "Authorization: token #{@github_token}", 
                                     "-H", "Accept: application/vnd.github.v3+json",
                                     "-s", latest_release_url)
      
      release_data = JSON.parse(output)
      actual_tag = release_data["tag_name"]
      
      "https://github.com/#{@owner}/#{@repo}/releases/download/#{actual_tag}/#{@filename}"
    else
      "https://github.com/#{@owner}/#{@repo}/releases/download/#{@tag}/#{@filename}"
    end
  end
end