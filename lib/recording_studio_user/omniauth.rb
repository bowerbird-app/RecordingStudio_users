# frozen_string_literal: true

require "omniauth"
require "omniauth-google-oauth2"
require "omniauth_microsoft_graph"
require "omniauth-apple"
require "omniauth-linkedin-openid"
require "omniauth-instagram-api"
require "omniauth/rails_csrf_protection"
require_relative "omniauth/provider_logos"
require_relative "omniauth/identity_flow"

module RecordingStudioUser
  # OmniAuth registration, find-or-create, connect, and disconnect for host Users.
  module Omniauth
    class Error < StandardError; end
    class MissingEmailError < Error; end
    class UnverifiedEmailError < Error; end
    class UnconfirmedEmailError < Error; end
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

    GOOGLE_LOGO_SVG = ProviderLogos::GOOGLE
    MICROSOFT_LOGO_SVG = ProviderLogos::MICROSOFT
    APPLE_LOGO_SVG = ProviderLogos::APPLE
    LINKEDIN_LOGO_SVG = ProviderLogos::LINKEDIN
    INSTAGRAM_LOGO_SVG = ProviderLogos::INSTAGRAM
    DEFAULT_LOGOS = ProviderLogos::BY_PROVIDER

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
      IdentityFlow.find_or_create_user!(auth)
    end

    def connect!(user, auth)
      IdentityFlow.connect!(user, auth)
    end

    def disconnect!(user, provider)
      IdentityFlow.disconnect!(user, provider)
    end

    def password_set?(user)
      IdentityFlow.password_set?(user)
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

    private_class_method :register_provider!
  end
end
