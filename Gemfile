# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_user.gemspec
gem "devise"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.213"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.13.0"
gem "recording_studio_admin",
    github: "bowerbird-app/RecordingStudio_admin",
    tag: "v2.1.0"
gem "recording_studio_attachable",
    github: "bowerbird-app/RecordingStudio_attachable",
    tag: "v0.13.0"
gem "recording_studio_metrics",
    github: "bowerbird-app/RecordingStudio_metrics",
    tag: "v0.2.0"
gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "bundler-audit", require: false
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
