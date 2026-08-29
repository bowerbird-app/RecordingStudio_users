# frozen_string_literal: true

require "omniauth"
require "omniauth-google-oauth2"
require "omniauth/rails_csrf_protection"

module RecordingStudioUser
  # OmniAuth registration, find-or-create, connect, and disconnect for host Users.
  module Omniauth
    class Error < StandardError; end
    class MissingEmailError < Error; end
    class AccountCreationDisabledError < Error; end
    class IdentityTakenError < Error; end
    class LastSignInMethodError < Error; end

    PROVIDER_LABELS = {
      google_oauth2: "Google"
    }.freeze

    # Default Google mark for Flatpack List::Item `icon:` (inline SVG string).
    GOOGLE_LOGO_SVG = <<~SVG.squish.freeze
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="32" height="32" aria-hidden="true">
        <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.4-.4-3.5z"/>
        <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 16.1 19 13 24 13c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 16.3 4 9.6 8.3 6.3 14.7z"/>
        <path fill="#4CAF50" d="M24 44c5.2 0 10-2 13.6-5.2l-6.3-5.3C29.3 35.3 26.8 36 24 36c-5.3 0-9.7-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/>
        <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.1-4 5.5l.1.1 6.3 5.3C39.2 37.3 44 32 44 24c0-1.2-.1-2.4-.4-3.5z"/>
      </svg>
    SVG

    module_function

    def register_providers!
      providers = RecordingStudioUser.config.omniauth_providers
      return if providers.blank?

      Devise.setup { |config| providers.each { |name, options| register_provider!(config, name, options) } }
    end

    def ensure_omniauthable!(user_class)
      providers = RecordingStudioUser.config.omniauth_provider_names
      return if providers.empty? || user_class.devise_modules.include?(:omniauthable)

      user_class.devise :omniauthable, omniauth_providers: providers
    end

    def find_or_create_user!(auth)
      identity = Identity.find_by(provider: auth.provider, uid: auth.uid.to_s)
      return identity.user if identity

      email = normalized_email(auth)
      existing = RecordingStudioUser.config.user_class.find_by(email: email)
      return create_identity!(existing, auth) && existing if existing

      raise AccountCreationDisabledError, "Account creation from this provider is disabled" unless
        RecordingStudioUser.config.omniauth_create_account?

      create_user_from_auth!(auth, email)
    end

    def connect!(user, auth)
      existing = Identity.find_by(provider: auth.provider, uid: auth.uid.to_s)
      return existing if existing&.user_id == user.id
      raise IdentityTakenError, "That Google account is already linked to another user" if existing

      create_identity!(user, auth)
    end

    def disconnect!(user, provider)
      identity = user.identities.find_by!(provider: provider.to_s)
      if user.identities.one? && !password_set?(user)
        raise LastSignInMethodError, "Connect another sign-in method or set a password before disconnecting"
      end

      identity.destroy!
    end

    def password_set?(user)
      user.respond_to?(:encrypted_password) && user.encrypted_password.present?
    end

    def provider_label(provider)
      PROVIDER_LABELS.fetch(provider.to_sym) { provider.to_s.humanize }
    end

    def register_provider!(config, name, options)
      opts = (options || {}).to_h.symbolize_keys
      config.omniauth(name.to_sym, opts.fetch(:client_id), opts.fetch(:client_secret),
                      **opts.except(:client_id, :client_secret))
    end

    def normalized_email(auth)
      email = auth.info&.email.to_s.strip.downcase
      raise MissingEmailError, "Email is required from the provider" if email.blank?

      email
    end

    def create_identity!(user, auth)
      user.identities.create!(provider: auth.provider.to_s, uid: auth.uid.to_s, email: auth.info&.email)
    end

    def create_user_from_auth!(auth, email)
      password = Devise.friendly_token[0, 32]
      first_name, last_name = name_parts_from(auth)

      ActiveRecord::Base.transaction do
        user = Directory.create_user!(
          email: email, password: password, password_confirmation: password,
          first_name: first_name, last_name: last_name, time_zone: "UTC"
        )
        create_identity!(user, auth)
        clear_oauth_password!(user)
      end
    end

    def clear_oauth_password!(user)
      # Google-only: blank digest so disconnect lockout checks and password_required? work.
      user.update_column(:encrypted_password, "")
      user
    end

    def name_parts_from(auth)
      info = auth.info
      first = present_name(info&.first_name)
      last = present_name(info&.last_name)
      first, last = present_name(info&.name).to_s.split(/\s+/, 2) if first.blank? && last.blank?
      [first.presence || "User", last.presence || "Account"]
    end

    def present_name(value)
      value.to_s.strip.presence
    end

    private_class_method :register_provider!, :normalized_email, :create_identity!,
                         :create_user_from_auth!, :clear_oauth_password!, :name_parts_from, :present_name
  end
end
