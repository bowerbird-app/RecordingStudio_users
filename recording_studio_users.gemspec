# frozen_string_literal: true

require_relative "lib/recording_studio_users/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_users"
  spec.version     = RecordingStudioUsers::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_users"
  spec.summary     = "User profiles, identity, and avatars for Recording Studio"
  spec.description = "A Rails engine that integrates Devise users with private Recording Studio profile roots, " \
                     "revisioned profiles, authorized avatars, FlatPack, and RecordingStudioAdmin."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "devise", "~> 5.0"
  spec.add_dependency "flat_pack", "~> 0.1.129"
  spec.add_dependency "recording_studio", "~> 3.0"
  spec.add_dependency "recording_studio_accessible", "~> 0.4"
  spec.add_dependency "recording_studio_admin", "~> 1.1"
  spec.add_dependency "recording_studio_attachable", "~> 0.2"
end
