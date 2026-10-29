# frozen_string_literal: true

require_relative "test/support/widen_recording_studio_requirement"

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_user.gemspec
gem "devise"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.329"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.22.0"
gem "recording_studio_admin",
    github: "bowerbird-app/RecordingStudio_admin",
    tag: "v2.7.0"
gem "recording_studio_attachable",
    github: "bowerbird-app/RecordingStudio_attachable",
    tag: "v0.22.0"
gem "recording_studio_cache",
    github: "bowerbird-app/RecordingStudio_cache",
    tag: "v0.5.1"
gem "recording_studio_logs",
    github: "bowerbird-app/RecordingStudio_logs",
    tag: "v0.7.0",
    require: false
gem "recording_studio_metrics",
    github: "bowerbird-app/RecordingStudio_metrics",
    tag: "v0.6.1",
    require: false
gem "recording_studio_trashable",
    github: "bowerbird-app/RecordingStudio_trashable",
    tag: "v0.12.0",
    require: false
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
