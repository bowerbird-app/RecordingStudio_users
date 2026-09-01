# frozen_string_literal: true

RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.layout = "recording_studio/default_layout"
  config.otp_enabled = true
  config.otp_login_enabled = true
  config.otp_registration_enabled = true
  config.registration_authentication_methods = %i[password otp]
  config.password_registration_confirmation = :existing_policy
end
