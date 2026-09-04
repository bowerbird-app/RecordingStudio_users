# frozen_string_literal: true

require_relative "lib/recording_studio_site_settings/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_site_settings"
  spec.version     = RecordingStudioSiteSettings::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_site_settings"
  spec.summary     = "Site name and logos for Recording Studio"
  spec.description = "Recording Studio addon that holds one site name, a square logo, a wide logo, " \
                     "and an optional favicon per site. Other gems read them from this gem, not from " \
                     "the root and not from Attachable."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "flat_pack", ">= 0.1.144"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible", "~> 0.8"
  spec.add_dependency "recording_studio_admin", "~> 2.0"
  spec.add_dependency "recording_studio_attachable", "~> 0.5"
end
