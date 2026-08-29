# frozen_string_literal: true

require "omniauth"
require "omniauth-google-oauth2"
require "omniauth_microsoft_graph"
require "omniauth-apple"
require "omniauth-linkedin-openid"
require "omniauth-instagram-api"
require "omniauth/rails_csrf_protection"

module RecordingStudioUser
  # OmniAuth registration, find-or-create, connect, and disconnect for host Users.
  module Omniauth
    class Error < StandardError; end
    class MissingEmailError < Error; end
    class AccountCreationDisabledError < Error; end
    class IdentityTakenError < Error; end
    class LastSignInMethodError < Error; end

    # Strategy keys hosts put in `omniauth_providers`. Labels are user-facing.
    PROVIDER_LABELS = {
      google_oauth2: "Google",
      microsoft_graph: "Microsoft",
      apple: "Apple",
      linkedin: "LinkedIn",
      instagram: "Instagram"
    }.freeze

    # Users-only option keys stripped before Devise/OmniAuth strategy registration.
    HOST_ONLY_OPTIONS = %i[logo].freeze

    # Default marks for Flatpack List::Item `icon:` (inline SVG strings).
    GOOGLE_LOGO_SVG = <<~SVG.squish.freeze
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="32" height="32" aria-hidden="true">
        <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.4-.4-3.5z"/>
        <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 16.1 19 13 24 13c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 16.3 4 9.6 8.3 6.3 14.7z"/>
        <path fill="#4CAF50" d="M24 44c5.2 0 10-2 13.6-5.2l-6.3-5.3C29.3 35.3 26.8 36 24 36c-5.3 0-9.7-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/>
        <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.1-4 5.5l.1.1 6.3 5.3C39.2 37.3 44 32 44 24c0-1.2-.1-2.4-.4-3.5z"/>
      </svg>
    SVG

    MICROSOFT_LOGO_SVG = <<~SVG.squish.freeze
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 23 23" width="32" height="32" aria-hidden="true">
        <path fill="#f35325" d="M1 1h10v10H1z"/>
        <path fill="#81bc06" d="M12 1h10v10H12z"/>
        <path fill="#05a6f0" d="M1 12h10v10H1z"/>
        <path fill="#ffba08" d="M12 12h10v10H12z"/>
      </svg>
    SVG

    APPLE_LOGO_SVG = <<~SVG.squish.freeze
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32" aria-hidden="true" fill="currentColor">
        <path d="M16.4 12.6c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.7-1.3-.1-2.5.8-3.1.8-.6 0-1.6-.7-2.7-.7-1.4 0-2.7.8-3.4 2.1-1.5 2.5-.4 6.3 1 8.4.7 1 1.5 2.2 2.6 2.1 1 0 1.4-.7 2.7-.7s1.6.7 2.7.7c1.1 0 1.9-1 2.6-2 .8-1.1 1.1-2.2 1.1-2.3-.1 0-2.1-.8-2.1-3.3zM14.5 5.9c.6-.7 1-1.7.9-2.7-.9 0-1.9.6-2.5 1.3-.6.6-1.1 1.7-.9 2.6 1 .1 1.9-.5 2.5-1.2z"/>
      </svg>
    SVG

    LINKEDIN_LOGO_SVG = <<~SVG.squish.freeze
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32" aria-hidden="true">
        <path fill="#0A66C2" d="M20.5 2h-17A1.5 1.5 0 002 3.5v17A1.5 1.5 0 003.5 22h17a1.5 1.5 0 001.5-1.5v-17A1.5 1.5 0 0020.5 2zM8 19H5v-9h3zM6.5 8.3A1.8 1.8 0 116.5 4.7a1.8 1.8 0 010 3.6zM19 19h-3v-4.7c0-1.1 0-2.6-1.6-2.6s-1.8 1.2-1.8 2.5V19h-3v-9h2.9v1.2h.1c.4-.8 1.4-1.6 2.9-1.6 3.1 0 3.7 2 3.7 4.7V19z"/>
      </svg>
    SVG

    INSTAGRAM_LOGO_SVG = <<~SVG.squish.freeze
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32" aria-hidden="true">
        <linearGradient id="ig" x1="0%" y1="100%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#fdf497"/>
          <stop offset="50%" stop-color="#fd5949"/>
          <stop offset="100%" stop-color="#d6249f"/>
        </linearGradient>
        <path fill="url(#ig)" d="M7 2h10a5 5 0 015 5v10a5 5 0 01-5 5H7a5 5 0 01-5-5V7a5 5 0 015-5zm5 5a5 5 0 100 10 5 5 0 000-10zm6.5-.9a1.1 1.1 0 11-2.2 0 1.1 1.1 0 012.2 0zM12 9a3 3 0 110 6 3 3 0 010-6z"/>
      </svg>
    SVG

    DEFAULT_LOGOS = {
      google_oauth2: GOOGLE_LOGO_SVG,
      microsoft_graph: MICROSOFT_LOGO_SVG,
      apple: APPLE_LOGO_SVG,
      linkedin: LINKEDIN_LOGO_SVG,
      instagram: INSTAGRAM_LOGO_SVG
    }.freeze

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
      if existing
        raise IdentityTakenError,
              "That #{provider_label(auth.provider)} account is already linked to another user"
      end

      # Connect while signed in does not invent an email. Instagram often has none;
      # Apple may omit it after the first consent. Identity.email stays blank.
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

    def default_logo(provider)
      DEFAULT_LOGOS[provider.to_sym]
    end

    def register_provider!(config, name, options)
      opts = (options || {}).to_h.symbolize_keys
      client_id = opts.fetch(:client_id)
      # Apple often passes "" and builds a client secret JWT from team_id / key_id / pem.
      client_secret = opts.fetch(:client_secret)
      strategy_opts = opts.except(:client_id, :client_secret, *HOST_ONLY_OPTIONS)
      config.omniauth(name.to_sym, client_id, client_secret, **strategy_opts)
    end

    def normalized_email(auth)
      email = auth.info&.email.to_s.strip.downcase
      raise MissingEmailError, "Email is required from the provider" if email.blank?

      email
    end

    def create_identity!(user, auth)
      user.identities.create!(
        provider: auth.provider.to_s,
        uid: auth.uid.to_s,
        email: auth.info&.email.presence
      )
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
      # Provider-only accounts: blank digest so disconnect lockout and password_required? work.
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
