# frozen_string_literal: true

source "https://rubygems.org"

# Public ecosystem sources used by the engine test matrix.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.129"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v3.0.3"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "0.4.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "1.1.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.2.0"

gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
