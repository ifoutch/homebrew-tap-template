require "download_strategy"

class S3DownloadStrategy < CurlDownloadStrategy
  require "utils/shell"
  require "time"
  require "openssl"
  require "base64"
  require "uri"

  def initialize(url, name, version, **meta)
    super
    parse_s3_url
    setup_aws_credentials
  end

  def parse_s3_url
    # Support both S3 URLs and s3:// protocol
    if match = url.match(%r{^s3://([^/]+)/(.+)$})
      _, @bucket, @key = *match
      @region = @meta[:region] || ENV["AWS_REGION"] || ENV["AWS_DEFAULT_REGION"] || "us-east-1"
      @use_path_style = false
    elsif match = url.match(%r{https://([^.]+)\.s3\.([^.]+)\.amazonaws\.com/(.+)})
      _, @bucket, @region, @key = *match
      @use_path_style = false
    elsif match = url.match(%r{https://s3\.([^.]+)\.amazonaws\.com/([^/]+)/(.+)})
      _, @region, @bucket, @key = *match
      @use_path_style = true
    elsif match = url.match(%r{https://([^/]+)/([^/]+)/(.+)})
      # Custom S3-compatible endpoint
      _, @endpoint, @bucket, @key = *match
      @region = @meta[:region] || "us-east-1"
      @use_custom_endpoint = true
    else
      raise ArgumentError, "Invalid S3 URL: #{url}"
    end
  end

  def setup_aws_credentials
    @access_key = ENV["AWS_ACCESS_KEY_ID"] || @meta[:access_key]
    @secret_key = ENV["AWS_SECRET_ACCESS_KEY"] || @meta[:secret_key]
    @session_token = ENV["AWS_SESSION_TOKEN"] || @meta[:session_token]
    
    # Check for IAM role credentials from EC2 instance metadata
    if !@access_key && !@secret_key && ec2_instance?
      fetch_ec2_credentials
    elsif !@access_key || !@secret_key
      raise CurlDownloadStrategyError, "AWS credentials required. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
    end
  end

  def ec2_instance?
    # Check if running on EC2 by trying to access instance metadata
    begin
      Utils.safe_popen_read("curl", "-s", "-m", "1", "http://169.254.169.254/latest/meta-data/")
      true
    rescue
      false
    end
  end

  def fetch_ec2_credentials
    # Fetch credentials from EC2 instance metadata
    role = Utils.safe_popen_read("curl", "-s", "http://169.254.169.254/latest/meta-data/iam/security-credentials/")
    creds_json = Utils.safe_popen_read("curl", "-s", "http://169.254.169.254/latest/meta-data/iam/security-credentials/#{role.strip}")
    
    require "json"
    creds = JSON.parse(creds_json)
    
    @access_key = creds["AccessKeyId"]
    @secret_key = creds["SecretAccessKey"]
    @session_token = creds["Token"]
  end

  def _fetch(url:, resolved_url:, timeout:)
    if presigned_url_available?
      # Use presigned URL if available
      curl_download @meta[:presigned_url], "--location", to: temporary_path, timeout: timeout
    else
      # Generate signed request
      signed_headers = generate_signed_request
      
      curl_args = ["--location"]
      signed_headers.each do |key, value|
        curl_args += ["--header", "#{key}: #{value}"]
      end
      
      curl_download s3_url, *curl_args, to: temporary_path, timeout: timeout
    end
  end

  private

  def presigned_url_available?
    @meta[:presigned_url] || ENV["HOMEBREW_S3_PRESIGNED_URL"]
  end

  def s3_url
    if @use_custom_endpoint
      "https://#{@endpoint}/#{@bucket}/#{@key}"
    elsif @use_path_style
      "https://s3.#{@region}.amazonaws.com/#{@bucket}/#{@key}"
    else
      "https://#{@bucket}.s3.#{@region}.amazonaws.com/#{@key}"
    end
  end

  def generate_signed_request
    # AWS Signature Version 4 signing process
    now = Time.now.utc
    datestamp = now.strftime("%Y%m%d")
    timestamp = now.strftime("%Y%m%dT%H%M%SZ")
    
    # Canonical request
    http_method = "GET"
    canonical_uri = "/#{@key}"
    canonical_querystring = ""
    
    if @use_path_style
      host = "s3.#{@region}.amazonaws.com"
    elsif @use_custom_endpoint
      host = @endpoint
    else
      host = "#{@bucket}.s3.#{@region}.amazonaws.com"
    end
    
    canonical_headers = "host:#{host}\nx-amz-date:#{timestamp}\n"
    signed_headers_str = "host;x-amz-date"
    
    if @session_token
      canonical_headers += "x-amz-security-token:#{@session_token}\n"
      signed_headers_str += ";x-amz-security-token"
    end
    
    payload_hash = "UNSIGNED-PAYLOAD"
    
    canonical_request = [
      http_method,
      canonical_uri,
      canonical_querystring,
      canonical_headers,
      signed_headers_str,
      payload_hash
    ].join("\n")
    
    # String to sign
    algorithm = "AWS4-HMAC-SHA256"
    credential_scope = "#{datestamp}/#{@region}/s3/aws4_request"
    string_to_sign = [
      algorithm,
      timestamp,
      credential_scope,
      OpenSSL::Digest::SHA256.hexdigest(canonical_request)
    ].join("\n")
    
    # Calculate signature
    signing_key = get_signature_key(@secret_key, datestamp, @region, "s3")
    signature = OpenSSL::HMAC.hexdigest("SHA256", signing_key, string_to_sign)
    
    # Authorization header
    authorization = "#{algorithm} Credential=#{@access_key}/#{credential_scope}, " \
                   "SignedHeaders=#{signed_headers_str}, Signature=#{signature}"
    
    headers = {
      "Authorization" => authorization,
      "x-amz-date" => timestamp,
      "x-amz-content-sha256" => payload_hash
    }
    
    headers["x-amz-security-token"] = @session_token if @session_token
    
    headers
  end

  def get_signature_key(key, date_stamp, region_name, service_name)
    k_date = OpenSSL::HMAC.digest("SHA256", "AWS4" + key, date_stamp)
    k_region = OpenSSL::HMAC.digest("SHA256", k_date, region_name)
    k_service = OpenSSL::HMAC.digest("SHA256", k_region, service_name)
    OpenSSL::HMAC.digest("SHA256", k_service, "aws4_request")
  end
end

class S3PublicDownloadStrategy < CurlDownloadStrategy
  # Simple strategy for public S3 buckets that don't require authentication
  def initialize(url, name, version, **meta)
    super
  end

  def _fetch(url:, resolved_url:, timeout:)
    curl_download url, "--location", to: temporary_path, timeout: timeout
  end
end