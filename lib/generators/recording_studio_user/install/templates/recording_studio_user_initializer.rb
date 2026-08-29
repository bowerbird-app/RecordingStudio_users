# frozen_string_literal: true

# Route configuration must load before Rails draws routes.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/recording_studio_users"
  config.profile_route_path = "profile"
  config.admin_route_path = "admin"
  config.layout = "application"
  config.additional_profile_attributes = []
  config.require_password_confirmation = true
  # OmniAuth providers. Empty hash keeps login/sign-up without provider buttons.
  # Secrets stay in host credentials / ENV — never commit real keys.
  # config.omniauth_providers = {
  #   google_oauth2: {
  #     client_id: Rails.application.credentials.dig(:google_oauth, :client_id) || ENV["GOOGLE_CLIENT_ID"],
  #     client_secret: Rails.application.credentials.dig(:google_oauth, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"]
  #   }
  # }
  config.omniauth_providers = {}
  # When false, unknown Google emails do not create a User (fail closed).
  config.omniauth_create_account = true
end

# Host Devise must route OmniAuth callbacks to Users when providers are configured:
#   devise_for :users, controllers: {
#     omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
#   }
#
# Register RecordingStudioUser::People and RecordingStudioUser::Profile in
# RecordingStudio.configure { |c| c.recordable_types = [...] }, then run:
#   bin/rails generate recording_studio_user:migrations
#   bin/rails db:migrate
