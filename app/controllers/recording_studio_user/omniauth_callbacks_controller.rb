# frozen_string_literal: true

module RecordingStudioUser
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    include Rails.application.routes.mounted_helpers

    # Devise routes each configured provider to a same-named action.
    Omniauth::PROVIDER_LABELS.each_key do |provider|
      define_method(provider) { handle_omniauth }
    end

    private

    def handle_omniauth
      run_omniauth_callback
    rescue Omniauth::MissingEmailError
      redirect_to_failure(
        "#{provider_label_for(request.env["omniauth.auth"])} did not return an email address."
      )
    rescue Omniauth::AccountCreationDisabledError
      redirect_to_failure(
        "No account exists for that #{provider_label_for(request.env["omniauth.auth"])} email, and new accounts are disabled."
      )
    rescue Omniauth::IdentityTakenError => error
      redirect_to after_connect_path, alert: error.message
    end

    def run_omniauth_callback
      auth = request.env["omniauth.auth"]
      user_signed_in? ? connect_current_user!(auth) : sign_in_from_omniauth!(auth)
    end

    def connect_current_user!(auth)
      Omniauth.connect!(current_user, auth)
      redirect_to after_connect_path, notice: "#{Omniauth.provider_label(auth.provider)} connected."
    end

    def sign_in_from_omniauth!(auth)
      sign_in_and_redirect Omniauth.find_or_create_user!(auth), event: :authentication
    end

    def after_sign_in_path_for(_resource)
      main_app.root_path
    end

    def after_connect_path
      recording_studio_users.sign_in_methods_profile_path
    end

    def redirect_to_failure(message)
      redirect_to main_app.new_user_session_path, alert: message
    end

    def provider_label_for(auth)
      Omniauth.provider_label(auth&.provider || "provider")
    end
  end
end
