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
  # Devise login page heading (host sessions#new). Default "Welcome back".
  # config.login_title = "Welcome back"
  # OmniAuth providers. Empty hash keeps login/sign-up without provider buttons.
  # Secrets stay in host credentials / ENV — never commit real keys.
  #
  # Email caveats (Users requires email on first login — MissingEmailError fail-closed):
  # - Instagram often returns no email. Connect while signed in still works; do not invent emails.
  # - Apple may send email only once (or a private relay). Later visits match Identity by uid.
  # Instagram uses omniauth-instagram-api (Instagram Login client id/secret).
  # Apple often uses client_secret: "" with team_id / key_id / pem options.
  # config.omniauth_providers = {
  #   google_oauth2: {
  #     client_id: Rails.application.credentials.dig(:google_oauth, :client_id) || ENV["GOOGLE_CLIENT_ID"],
  #     client_secret: Rails.application.credentials.dig(:google_oauth, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"],
  #     logo: "https://example.com/google.svg" # optional; gem ships default SVGs
  #   },
  #   microsoft_graph: {
  #     client_id: ENV["MICROSOFT_CLIENT_ID"],
  #     client_secret: ENV["MICROSOFT_CLIENT_SECRET"]
  #   },
  #   apple: {
  #     client_id: ENV["APPLE_CLIENT_ID"],
  #     client_secret: "",
  #     team_id: ENV["APPLE_TEAM_ID"],
  #     key_id: ENV["APPLE_KEY_ID"],
  #     pem: ENV["APPLE_PEM"],
  #     scope: "email name"
  #   },
  #   linkedin: {
  #     client_id: ENV["LINKEDIN_CLIENT_ID"],
  #     client_secret: ENV["LINKEDIN_CLIENT_SECRET"]
  #   },
  #   instagram: {
  #     client_id: ENV["INSTAGRAM_CLIENT_ID"],
  #     client_secret: ENV["INSTAGRAM_CLIENT_SECRET"]
  #   }
  # }
  config.omniauth_providers = {}
  # When false, unknown provider emails do not create a User (fail closed).
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
