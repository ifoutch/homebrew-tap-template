require "download_strategy"
require "cgi"

class GitLabPrivateRepoDownloadStrategy < CurlDownloadStrategy
  require "utils/shell"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_gitlab_token
  end

  def parse_url_pattern
    # Support various GitLab URL patterns
    if match = url.match(%r{https://gitlab\.com/([^/]+)/([^/]+)/-/raw/([^/]+)/(.+)})
      _, @namespace, @project, @ref, @filepath = *match
      @gitlab_host = "gitlab.com"
    elsif match = url.match(%r{https://([^/]+)/([^/]+)/([^/]+)/-/raw/([^/]+)/(.+)})
      _, @gitlab_host, @namespace, @project, @ref, @filepath = *match
    elsif match = url.match(%r{https://gitlab\.com/api/v4/projects/([^/]+)/repository/files/([^/]+)/raw})
      _, @project_id, @filepath = *match
      @gitlab_host = "gitlab.com"
      @use_api = true
    elsif match = url.match(%r{https://([^/]+)/api/v4/projects/([^/]+)/repository/files/([^/]+)/raw})
      _, @gitlab_host, @project_id, @filepath = *match
      @use_api = true
    else
      raise ArgumentError, "Invalid URL for GitLabPrivateRepoDownloadStrategy: #{url}"
    end
  end

  def set_gitlab_token
    @gitlab_token = ENV["HOMEBREW_GITLAB_API_TOKEN"] || ENV["GITLAB_PRIVATE_TOKEN"]
    
    # Fallback to GitLab CLI authentication if available
    unless @gitlab_token
      @gitlab_token = get_glab_token
    end
    
    unless @gitlab_token
      raise CurlDownloadStrategyError, "GitLab authentication required. Set HOMEBREW_GITLAB_API_TOKEN/GITLAB_PRIVATE_TOKEN or authenticate with 'glab auth login'."
    end
  end

  private

  def get_glab_token
    # Check if glab CLI is available and can get config
    return nil unless system("which glab > /dev/null 2>&1")
    
    # Try to get token from glab config
    token_output = Utils.safe_popen_read("glab", "config", "get", "token")
    return token_output.strip if $?.success? && !token_output.strip.empty?
    
    # Fallback to environment variable that glab uses
    ENV["GITLAB_TOKEN"]
  rescue
    nil
  end

  def _fetch(url:, resolved_url:, timeout:)
    curl_download download_url,
      "--header", "PRIVATE-TOKEN: #{@gitlab_token}",
      "--location",
      to: temporary_path,
      timeout: timeout
  end

  private

  def download_url
    if @use_api
      # API-based URL
      ref = @ref || "main"
      "https://#{@gitlab_host}/api/v4/projects/#{@project_id}/repository/files/#{CGI.escape(@filepath)}/raw?ref=#{ref}"
    else
      # Direct raw file URL - convert to API URL for private repos
      project_path = "#{@namespace}/#{@project}"
      encoded_path = CGI.escape(project_path)
      encoded_filepath = CGI.escape(@filepath)
      
      "https://#{@gitlab_host}/api/v4/projects/#{encoded_path}/repository/files/#{encoded_filepath}/raw?ref=#{@ref}"
    end
  end
end

class GitLabReleaseDownloadStrategy < CurlDownloadStrategy
  require "utils/shell"
  require "json"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_gitlab_token
  end

  def parse_url_pattern
    # Support GitLab release assets
    if match = url.match(%r{https://gitlab\.com/([^/]+)/([^/]+)/-/releases/([^/]+)/downloads/(.+)})
      _, @namespace, @project, @tag, @filename = *match
      @gitlab_host = "gitlab.com"
    elsif match = url.match(%r{https://([^/]+)/([^/]+)/([^/]+)/-/releases/([^/]+)/downloads/(.+)})
      _, @gitlab_host, @namespace, @project, @tag, @filename = *match
    else
      raise ArgumentError, "Invalid URL for GitLabReleaseDownloadStrategy: #{url}"
    end
  end

  def set_gitlab_token
    @gitlab_token = ENV["HOMEBREW_GITLAB_API_TOKEN"] || ENV["GITLAB_PRIVATE_TOKEN"]
    
    # Fallback to GitLab CLI authentication if available
    unless @gitlab_token
      @gitlab_token = get_glab_token
    end
    
    unless @gitlab_token
      raise CurlDownloadStrategyError, "GitLab authentication required. Set HOMEBREW_GITLAB_API_TOKEN/GITLAB_PRIVATE_TOKEN or authenticate with 'glab auth login'."
    end
  end

  def get_glab_token
    # Check if glab CLI is available and can get config
    return nil unless system("which glab > /dev/null 2>&1")
    
    # Try to get token from glab config
    token_output = Utils.safe_popen_read("glab", "config", "get", "token")
    return token_output.strip if $?.success? && !token_output.strip.empty?
    
    # Fallback to environment variable that glab uses
    ENV["GITLAB_TOKEN"]
  rescue
    nil
  end

  def _fetch(url:, resolved_url:, timeout:)
    # GitLab release assets require finding the direct link via API
    project_path = "#{@namespace}/#{@project}"
    encoded_path = CGI.escape(project_path)
    
    # Get release info
    release_api_url = "https://#{@gitlab_host}/api/v4/projects/#{encoded_path}/releases/#{@tag}"
    
    output = Utils.safe_popen_read("curl", 
                                   "-H", "PRIVATE-TOKEN: #{@gitlab_token}",
                                   "-s", release_api_url)
    
    release_data = JSON.parse(output)
    
    # Find the asset URL
    asset_link = release_data["assets"]["links"].find { |link| link["name"] == @filename || link["url"].end_with?(@filename) }
    
    if asset_link.nil?
      raise CurlDownloadStrategyError, "Asset #{@filename} not found in release #{@tag}"
    end
    
    curl_download asset_link["url"],
      "--header", "PRIVATE-TOKEN: #{@gitlab_token}",
      "--location",
      to: temporary_path,
      timeout: timeout
  end
end