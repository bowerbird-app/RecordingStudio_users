# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_user.gemspec
gem "devise"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.141"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"
gem "recording_studio_admin",
    github: "bowerbird-app/RecordingStudio_admin",
    ref: "d68f0e41e48a3266c77dd544acf6d0fc97d2b0cf"
gem "recording_studio_attachable",
    github: "bowerbird-app/RecordingStudio_attachable",
    tag: "v0.5.0"
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
