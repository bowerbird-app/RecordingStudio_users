# frozen_string_literal: true

require_relative "lib/recording_studio_notifications_push/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_notifications_push"
  spec.version     = RecordingStudioNotificationsPush::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_notifications_push"
  spec.summary     = "Firebase Cloud Messaging push channel for Recording Studio notifications"
  spec.description = "A Rails engine that registers a :push delivery channel with " \
                     "RecordingStudioNotifications, stores device installations, and sends " \
                     "FCM HTTP v1 messages."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_notifications", ">= 0.3.0", "< 1"
end
