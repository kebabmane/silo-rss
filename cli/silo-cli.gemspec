# frozen_string_literal: true

require_relative "lib/silo/version"

Gem::Specification.new do |spec|
  spec.name = "silo-cli"
  spec.version = Silo::VERSION
  spec.authors = [ "Silo Contributors" ]
  spec.email = [ "support@example.com" ]

  spec.summary = "CLI for Silo RSS Reader"
  spec.description = "Command-line interface and MCP server for the Silo RSS feed reader"
  spec.homepage = "https://github.com/example/silo"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "httparty", "~> 0.21"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
