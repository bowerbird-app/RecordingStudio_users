# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_notifications_push.gemspec
gemspec

# Parent gems are not published to RubyGems; resolve from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_notifications",
    github: "bowerbird-app/RecordingStudio_notifications",
    branch: "cursor/otp-delivery-payload-78f4"

# Temporary vendored email channel with recording_studio ~> 4.2 until upstream
# RecordingStudio_notifications_email bumps its gemspec off < 4. Override with
# RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH if needed (see MIGRATION_NOTES.md).
email_path = ENV.fetch("RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH", nil)
email_path = "vendor/recording_studio_notifications_email" if email_path.nil? || email_path.strip.empty?
gem "recording_studio_notifications_email", path: email_path

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.133"
gem "recording_studio_accessible",
    github: "bowerbird-app/RecordingStudio_accessible",
    tag: "v0.7.0"
gem "recording_studio_pwa",
    github: "bowerbird-app/RecordingStudio_PWA",
    branch: "cursor/pwa-service-worker-seam-453c"

gem "devise"
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
