# frozen_string_literal: true

require_relative "lib/moonraker/bosun/version"

Gem::Specification.new do |spec|
  spec.name = "moonraker-bosun"
  spec.version = Moonraker::Bosun::VERSION
  spec.authors = ["akira yamada"]
  spec.email = ["akira@arika.org"]

  spec.summary = "Track Klipper configuration files on a Moonraker host with git"
  spec.description = <<~TEXT.tr("\n", " ").strip
    bosun fetches configuration files and Moonraker database contents from a Klipper host
    through the Moonraker API, records them in a dedicated git branch, and pushes local
    changes back to the host after checking that nothing has changed there.
  TEXT
  spec.homepage = "https://github.com/arika/moonraker-bosun"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["lib/**/*.rb", "exe/*", "docs/*.md", "README.md", "README.ja.md", "CHANGELOG.md", "LICENSE"]
  spec.bindir = "exe"
  spec.executables = ["bosun"]
  spec.require_paths = ["lib"]
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
end
