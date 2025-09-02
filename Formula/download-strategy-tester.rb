class DownloadStrategyTester < Formula
  desc "Test utility for validating Homebrew download strategies"
  homepage "https://github.com/yourusername/homebrew-tap-template"
  url "file://#{File.expand_path("../../test/download-strategy-tester.rb", __FILE__)}"
  version "1.0.0"
  sha256 "placeholder"

  def install
    # Install the test script
    libexec.install "download-strategy-tester.rb"
    
    # Create a wrapper script
    (bin/"download-strategy-tester").write <<~EOS
      #!/bin/bash
      exec ruby "#{libexec}/download-strategy-tester.rb" "$@"
    EOS
    
    # Make it executable
    chmod 0755, bin/"download-strategy-tester"
    
    # Install test configuration template
    (share/"download-strategy-tester").install_metafiles
    
    # Create example config file
    (share/"download-strategy-tester/test-config.example.yml").write <<~YAML
      # Example configuration file for download strategy tester
      # Copy this to test-config.yml and customize with your test URLs
      
      github:
        # URL to a file in a private GitHub repository (raw content)
        raw_url: "https://raw.githubusercontent.com/yourusername/private-repo/main/test-file.txt"
        # URL to a GitHub release asset
        release_url: "https://github.com/yourusername/private-repo/releases/download/v1.0.0/asset.tar.gz"
      
      gitlab:
        # URL to a file in a private GitLab repository
        raw_url: "https://gitlab.com/yourusername/private-repo/-/raw/main/test-file.txt"
        # URL to a GitLab release asset
        release_url: "https://gitlab.com/yourusername/private-repo/-/releases/v1.0.0/downloads/asset.tar.gz"
      
      bitbucket:
        # URL to a file in a private Bitbucket repository
        url: "https://bitbucket.org/yourusername/private-repo/raw/main/test-file.txt"
      
      s3:
        # S3 bucket URL (private)
        url: "s3://your-private-bucket/path/to/file.tar.gz"
        # S3 public bucket URL
        public_url: "https://s3.amazonaws.com/public-bucket/file.tar.gz"
      
      authenticated:
        # Generic authenticated URL
        url: "https://api.example.com/downloads/file.tar.gz"
    YAML
  end

  def caveats
    <<~EOS
      Download Strategy Tester has been installed!
      
      To test your download strategies:
        download-strategy-tester --help
      
      Quick start:
        # Check your environment variables
        download-strategy-tester --check-env
        
        # List available strategies
        download-strategy-tester --list
        
        # Test a specific strategy
        download-strategy-tester --strategy github-raw
        
        # Test all strategies
        download-strategy-tester --all
        
        # Use a config file for custom test URLs
        cp #{share}/download-strategy-tester/test-config.example.yml ~/test-config.yml
        # Edit ~/test-config.yml with your test URLs
        download-strategy-tester --all --config ~/test-config.yml
      
      Required environment variables:
        GitHub:   HOMEBREW_GITHUB_API_TOKEN
        GitLab:   HOMEBREW_GITLAB_API_TOKEN
        Bitbucket: HOMEBREW_BITBUCKET_USER, HOMEBREW_BITBUCKET_TOKEN
        AWS S3:   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
        Generic:  Various (see --check-env)
    EOS
  end

  test do
    output = shell_output("#{bin}/download-strategy-tester --version")
    assert_match "Download Strategy Tester v1.0.0", output
    
    output = shell_output("#{bin}/download-strategy-tester --list")
    assert_match "github-raw", output
    assert_match "GitHubPrivateRepoDownloadStrategy", output
  end
end