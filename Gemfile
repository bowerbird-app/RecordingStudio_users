# frozen_string_literal: true

source "https://rubygems.org"

# Local development sources for Recording Studio ecosystem dependencies.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v3.0.3"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "0.3.2"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "1.2.0"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.129"

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
