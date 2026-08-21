# frozen_string_literal: true

require_relative "lib/recording_studio_users/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_users"
  spec.version     = RecordingStudioUsers::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_users"
  spec.summary     = "Identity, invitations, membership, and operating roles for Recording Studio"
  spec.description = "Adds Devise host installation, Accessible-backed people workflows, " \
                     "workspace onboarding, and demotion-only operating roles to Recording Studio."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_users"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_users/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "devise"
  spec.add_dependency "flat_pack", ">= 0.1.129"
  spec.add_dependency "rails", ">= 8.1", "< 9"
  spec.add_dependency "recording_studio", ">= 4.1.0", "< 5"
  spec.add_dependency "recording_studio_accessible", ">= 0.6.1", "< 1"
  spec.add_dependency "recording_studio_root_switchable", ">= 0.5.0", "< 1"
end
