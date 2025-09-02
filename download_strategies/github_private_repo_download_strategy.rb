require "download_strategy"

class GitHubPrivateRepoDownloadStrategy < CurlDownloadStrategy
  require "utils/github"
  require "utils/shell"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    unless match = url.match(%r{https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/(.+)})
      raise ArgumentError, "Invalid URL for GitHubPrivateRepoDownloadStrategy: #{url}"
    end

    _, @owner, @repo, @filepath = *match
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

  private

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
    curl_download download_url, "--header", "Authorization: token #{@github_token}", to: temporary_path, timeout: timeout
  end

  def download_url
    "https://raw.githubusercontent.com/#{@owner}/#{@repo}/#{@filepath}"
  end
end