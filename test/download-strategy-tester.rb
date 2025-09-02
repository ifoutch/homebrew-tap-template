#!/usr/bin/env ruby

require 'optparse'
require 'tempfile'
require 'fileutils'
require 'digest'
require 'net/http'
require 'uri'
require 'json'

class DownloadStrategyTester
  VERSION = "1.0.0"
  
  STRATEGIES = {
    'github-raw' => 'GitHubPrivateRepoDownloadStrategy',
    'github-release' => 'GitHubReleaseDownloadStrategy',
    'gitlab-raw' => 'GitLabPrivateRepoDownloadStrategy',
    'gitlab-release' => 'GitLabReleaseDownloadStrategy',
    's3' => 'S3DownloadStrategy',
    's3-public' => 'S3PublicDownloadStrategy',
    'authenticated' => 'AuthenticatedDownloadStrategy'
  }

  def initialize
    @results = []
    @verbose = false
    @config_file = nil
  end

  def run(args)
    parse_options(args)
    
    if @config_file
      load_config(@config_file)
    end
    
    if @list_strategies
      list_strategies
      return
    end
    
    if @check_env
      check_environment
      return
    end
    
    if @test_strategy
      test_single_strategy(@test_strategy)
    elsif @test_all
      test_all_strategies
    else
      puts "No test specified. Use --help for usage information."
      exit 1
    end
    
    print_results
  end

  private

  def parse_options(args)
    OptionParser.new do |opts|
      opts.banner = "Usage: download-strategy-tester [options]"
      
      opts.on("-s", "--strategy STRATEGY", "Test a specific strategy") do |s|
        @test_strategy = s
      end
      
      opts.on("-a", "--all", "Test all strategies") do
        @test_all = true
      end
      
      opts.on("-c", "--config FILE", "Load test configuration from file") do |f|
        @config_file = f
      end
      
      opts.on("-l", "--list", "List available strategies") do
        @list_strategies = true
      end
      
      opts.on("-e", "--check-env", "Check environment variables") do
        @check_env = true
      end
      
      opts.on("-v", "--verbose", "Verbose output") do
        @verbose = true
      end
      
      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
      
      opts.on("--version", "Show version") do
        puts "Download Strategy Tester v#{VERSION}"
        exit
      end
    end.parse!(args)
  end

  def load_config(file)
    unless File.exist?(file)
      puts "Error: Config file '#{file}' not found"
      exit 1
    end
    
    require 'yaml'
    @config = YAML.load_file(file)
    puts "Loaded configuration from #{file}" if @verbose
  end

  def list_strategies
    puts "\nAvailable Download Strategies:"
    puts "-" * 40
    STRATEGIES.each do |key, class_name|
      puts "  #{key.ljust(20)} => #{class_name}"
    end
    puts "\nEnvironment Variables Required:"
    puts "-" * 40
    puts "  GitHub:"
    puts "    - HOMEBREW_GITHUB_API_TOKEN"
    puts "  GitLab:"
    puts "    - HOMEBREW_GITLAB_API_TOKEN or GITLAB_PRIVATE_TOKEN"
    puts "  AWS S3:"
    puts "    - AWS_ACCESS_KEY_ID"
    puts "    - AWS_SECRET_ACCESS_KEY"
    puts "    - AWS_REGION (optional)"
    puts "  Generic Auth:"
    puts "    - HOMEBREW_BEARER_TOKEN (for bearer auth)"
    puts "    - HOMEBREW_API_KEY (for API key auth)"
    puts "    - HOMEBREW_AUTH_USER + HOMEBREW_AUTH_PASSWORD (for basic auth)"
  end

  def check_environment
    puts "\nEnvironment Variable Status:"
    puts "-" * 40
    
    env_vars = {
      'GitHub' => ['HOMEBREW_GITHUB_API_TOKEN'],
      'GitLab' => ['HOMEBREW_GITLAB_API_TOKEN', 'GITLAB_PRIVATE_TOKEN'],
      'AWS S3' => ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION'],
      'Generic Auth' => ['HOMEBREW_BEARER_TOKEN', 'HOMEBREW_API_KEY', 'HOMEBREW_AUTH_USER', 'HOMEBREW_AUTH_PASSWORD']
    }
    
    env_vars.each do |service, vars|
      puts "\n#{service}:"
      vars.each do |var|
        value = ENV[var]
        if value
          masked = value[0..3] + ('*' * [value.length - 4, 0].max)
          puts "  ✓ #{var} = #{masked}"
        else
          puts "  ✗ #{var} = (not set)"
        end
      end
    end
  end

  def test_single_strategy(strategy_key)
    unless STRATEGIES.key?(strategy_key)
      puts "Error: Unknown strategy '#{strategy_key}'"
      puts "Use --list to see available strategies"
      exit 1
    end
    
    puts "\nTesting #{strategy_key} strategy..." if @verbose
    
    case strategy_key
    when 'github-raw'
      test_github_raw
    when 'github-release'
      test_github_release
    when 'gitlab-raw'
      test_gitlab_raw
    when 'gitlab-release'
      test_gitlab_release
    when 's3'
      test_s3
    when 's3-public'
      test_s3_public
    when 'authenticated'
      test_authenticated
    end
  end

  def test_all_strategies
    STRATEGIES.keys.each do |strategy|
      test_single_strategy(strategy)
    end
  end

  def test_github_raw
    return unless check_github_env
    
    test_url = @config&.dig('github', 'raw_url') || 
               'https://raw.githubusercontent.com/octocat/Hello-World/master/README'
    
    result = create_test_formula('github-raw', test_url, 'GitHubPrivateRepoDownloadStrategy')
    @results << { strategy: 'github-raw', success: result, url: test_url }
  end

  def test_github_release
    return unless check_github_env
    
    test_url = @config&.dig('github', 'release_url') || 
               'https://github.com/cli/cli/releases/download/v2.0.0/gh_2.0.0_macOS_amd64.tar.gz'
    
    result = create_test_formula('github-release', test_url, 'GitHubReleaseDownloadStrategy')
    @results << { strategy: 'github-release', success: result, url: test_url }
  end

  def test_gitlab_raw
    return unless check_gitlab_env
    
    test_url = @config&.dig('gitlab', 'raw_url') || 
               'https://gitlab.com/gitlab-org/gitlab/-/raw/master/README.md'
    
    result = create_test_formula('gitlab-raw', test_url, 'GitLabPrivateRepoDownloadStrategy')
    @results << { strategy: 'gitlab-raw', success: result, url: test_url }
  end

  def test_gitlab_release
    return unless check_gitlab_env
    
    test_url = @config&.dig('gitlab', 'release_url') || 
               'https://gitlab.com/myorg/myproject/-/releases/v1.0.0/downloads/myfile.tar.gz'
    
    result = create_test_formula('gitlab-release', test_url, 'GitLabReleaseDownloadStrategy')
    @results << { strategy: 'gitlab-release', success: result, url: test_url }
  end

  def test_s3
    return unless check_s3_env
    
    test_url = @config&.dig('s3', 'url') || 
               's3://my-bucket/path/to/file.tar.gz'
    
    result = create_test_formula('s3', test_url, 'S3DownloadStrategy')
    @results << { strategy: 's3', success: result, url: test_url }
  end

  def test_s3_public
    test_url = @config&.dig('s3', 'public_url') || 
               'https://s3.amazonaws.com/public-bucket/file.tar.gz'
    
    result = create_test_formula('s3-public', test_url, 'S3PublicDownloadStrategy')
    @results << { strategy: 's3-public', success: result, url: test_url }
  end

  def test_authenticated
    test_url = @config&.dig('authenticated', 'url') || 
               'https://api.example.com/downloads/file.tar.gz'
    
    auth_type = detect_auth_type
    return unless auth_type
    
    result = create_test_formula('authenticated', test_url, 'AuthenticatedDownloadStrategy', auth_type: auth_type)
    @results << { strategy: 'authenticated', success: result, url: test_url, auth_type: auth_type }
  end

  def check_github_env
    if ENV['HOMEBREW_GITHUB_API_TOKEN']
      true
    else
      puts "  ⚠️  Skipping github strategies - HOMEBREW_GITHUB_API_TOKEN not set" if @verbose
      false
    end
  end

  def check_gitlab_env
    if ENV['HOMEBREW_GITLAB_API_TOKEN'] || ENV['GITLAB_PRIVATE_TOKEN']
      true
    else
      puts "  ⚠️  Skipping gitlab strategies - HOMEBREW_GITLAB_API_TOKEN not set" if @verbose
      false
    end
  end

  def check_s3_env
    if ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
      true
    else
      puts "  ⚠️  Skipping S3 strategy - AWS credentials not set" if @verbose
      false
    end
  end

  def detect_auth_type
    if ENV['HOMEBREW_BEARER_TOKEN']
      :bearer
    elsif ENV['HOMEBREW_API_KEY']
      :api_key
    elsif ENV['HOMEBREW_AUTH_USER'] && ENV['HOMEBREW_AUTH_PASSWORD']
      :basic
    else
      puts "  ⚠️  Skipping authenticated strategy - no auth credentials set" if @verbose
      nil
    end
  end

  def create_test_formula(name, url, strategy_class, **options)
    Dir.mktmpdir do |dir|
      formula_file = File.join(dir, "test_#{name}.rb")
      
      # Generate test formula
      formula_content = generate_formula(name, url, strategy_class, options)
      File.write(formula_file, formula_content)
      
      puts "  Testing download from: #{url}" if @verbose
      
      # Try to run brew fetch to test the download
      success = test_brew_fetch(formula_file)
      
      if success
        puts "  ✓ #{name} strategy test passed" if @verbose
      else
        puts "  ✗ #{name} strategy test failed" if @verbose
      end
      
      success
    end
  end

  def generate_formula(name, url, strategy_class, options = {})
    lib_path = File.expand_path('../../download_strategies', __FILE__)
    
    strategy_file = case strategy_class
    when 'GitHubPrivateRepoDownloadStrategy'
      'github_private_repo_download_strategy'
    when 'GitHubReleaseDownloadStrategy'
      'github_release_download_strategy'
    when /GitLab/
      'gitlab_private_repo_download_strategy'
    when /S3/
      's3_download_strategy'
    when 'AuthenticatedDownloadStrategy'
      'authenticated_download_strategy'
    end
    
    auth_options = if options[:auth_type]
      ",\n      auth_type: :#{options[:auth_type]}"
    else
      ""
    end
    
    <<~RUBY
      require_relative "#{lib_path}/#{strategy_file}"
      
      class Test#{name.gsub('-', '').capitalize} < Formula
        desc "Test formula for #{strategy_class}"
        homepage "https://example.com"
        url "#{url}",
            using: #{strategy_class}#{auth_options}
        version "1.0.0"
        
        def install
          mkdir_p prefix/"test"
          (prefix/"test/result.txt").write "Download successful"
        end
      end
    RUBY
  end

  def test_brew_fetch(formula_file)
    # Run brew fetch in a subprocess
    output = `brew fetch --retry --formula #{formula_file} 2>&1`
    success = $?.success?
    
    if @verbose && !success
      puts "  Brew output: #{output}"
    end
    
    success
  end

  def print_results
    puts "\n" + "=" * 50
    puts "Test Results Summary"
    puts "=" * 50
    
    if @results.empty?
      puts "No tests were run."
      return
    end
    
    passed = @results.count { |r| r[:success] }
    failed = @results.count { |r| !r[:success] }
    
    @results.each do |result|
      status = result[:success] ? "✓ PASS" : "✗ FAIL"
      puts "#{status.ljust(10)} #{result[:strategy]}"
      if result[:auth_type]
        puts "           Auth Type: #{result[:auth_type]}"
      end
      if @verbose
        puts "           URL: #{result[:url]}"
      end
    end
    
    puts "\nTotal: #{passed} passed, #{failed} failed out of #{@results.size} tests"
    
    exit(failed > 0 ? 1 : 0)
  end
end

# Run the tester if this file is executed directly
if __FILE__ == $0
  tester = DownloadStrategyTester.new
  tester.run(ARGV)
end