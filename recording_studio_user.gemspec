# frozen_string_literal: true

require_relative "lib/recording_studio_user/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_user"
  spec.version     = RecordingStudioUser::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_users"
  spec.summary     = "Devise actors, shared People, and Profile recordings for Recording Studio"
  spec.description = "A mountable Rails engine that keeps host Users as Devise actors and owns " \
                     "the shared People root plus Profile snapshots for Recording Studio."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "devise", "~> 5.0"
  spec.add_dependency "flat_pack", "~> 0.1"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible", "~> 0.7"
  spec.add_dependency "recording_studio_admin", "~> 2.0"
  spec.add_dependency "recording_studio_attachable", "~> 0.5"
end
