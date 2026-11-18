# frozen_string_literal: true

# Dummy-only. Production Users does not load or depend on this gem.
require Rails.root.join("lib/dummy/signup_terms")

RecordingStudioTermsAndConditions.configure do |config|
  config.app_name = "Studio"
end

RecordingStudioUser.configure do |config|
  config.signup_notice_partials = ["dummy/signup_terms_notice"]
  config.after_registration ->(user:, method:) {
    Dummy::SignupTerms.accept_on_signup!(user, method: method)
  }
end
