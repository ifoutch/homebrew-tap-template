require "download_strategy"

class AuthenticatedDownloadStrategy < CurlDownloadStrategy
  require "utils/shell"

  def initialize(url, name, version, **meta)
    super
    setup_authentication
  end

  def setup_authentication
    @auth_type = @meta[:auth_type] || detect_auth_type
    
    case @auth_type
    when :bearer
      setup_bearer_auth
    when :basic
      setup_basic_auth
    when :header
      setup_custom_header
    when :api_key
      setup_api_key
    else
      raise CurlDownloadStrategyError, "Unknown authentication type: #{@auth_type}"
    end
  end

  def detect_auth_type
    # Try to auto-detect based on available environment variables
    if ENV["HOMEBREW_BEARER_TOKEN"]
      :bearer
    elsif ENV["HOMEBREW_API_KEY"]
      :api_key
    elsif ENV["HOMEBREW_AUTH_USER"] && ENV["HOMEBREW_AUTH_PASSWORD"]
      :basic
    elsif ENV["HOMEBREW_AUTH_HEADER"]
      :header
    else
      raise CurlDownloadStrategyError, "Could not detect authentication type. Please set auth_type in formula."
    end
  end

  def setup_bearer_auth
    @token = ENV["HOMEBREW_BEARER_TOKEN"] || @meta[:token]
    unless @token
      raise CurlDownloadStrategyError, "Bearer token required. Set HOMEBREW_BEARER_TOKEN environment variable."
    end
  end

  def setup_basic_auth
    @username = ENV["HOMEBREW_AUTH_USER"] || @meta[:username]
    @password = ENV["HOMEBREW_AUTH_PASSWORD"] || @meta[:password]
    
    unless @username && @password
      raise CurlDownloadStrategyError, "Username and password required. Set HOMEBREW_AUTH_USER and HOMEBREW_AUTH_PASSWORD environment variables."
    end
  end

  def setup_custom_header
    @custom_header = ENV["HOMEBREW_AUTH_HEADER"] || @meta[:header]
    @custom_value = ENV["HOMEBREW_AUTH_VALUE"] || @meta[:header_value]
    
    unless @custom_header && @custom_value
      raise CurlDownloadStrategyError, "Custom header and value required. Set HOMEBREW_AUTH_HEADER and HOMEBREW_AUTH_VALUE environment variables."
    end
  end

  def setup_api_key
    @api_key = ENV["HOMEBREW_API_KEY"] || @meta[:api_key]
    @api_key_header = ENV["HOMEBREW_API_KEY_HEADER"] || @meta[:api_key_header] || "X-API-Key"
    
    unless @api_key
      raise CurlDownloadStrategyError, "API key required. Set HOMEBREW_API_KEY environment variable."
    end
  end

  def _fetch(url:, resolved_url:, timeout:)
    args = build_curl_args
    curl_download url, *args, to: temporary_path, timeout: timeout
  end

  private

  def build_curl_args
    args = ["--location"]
    
    case @auth_type
    when :bearer
      args += ["--header", "Authorization: Bearer #{@token}"]
    when :basic
      args += ["--user", "#{@username}:#{@password}"]
    when :header
      args += ["--header", "#{@custom_header}: #{@custom_value}"]
    when :api_key
      args += ["--header", "#{@api_key_header}: #{@api_key}"]
    end
    
    # Add any additional headers from meta
    if @meta[:headers]
      @meta[:headers].each do |key, value|
        args += ["--header", "#{key}: #{value}"]
      end
    end
    
    args
  end
end