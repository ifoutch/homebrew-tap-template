require_relative "../lib/github_private_repo_download_strategy"

class <formulae name> < Formula
  desc "<formulae description>"
  homepage "https://github.com/<user>/<repo>"
  url "https://raw.githubusercontent.com/<user>/<repo>/<path>",
      using: GitHubPrivateRepoDownloadStrategy
  version "<version>"
  sha256 "<sha256 sum>"

  def install
    bin.install "<file source>" => "<file target>"
  end

  test do
    assert_match "<file>", shell_output("#{bin}/<file> --help", 2)
  end
end
