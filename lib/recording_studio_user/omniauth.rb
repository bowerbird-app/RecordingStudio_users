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

    def resolve_providers(assigned)
      source = assigned.present? ? assigned : providers_from_credentials
      usable_providers(source)
    end

    def providers_from_credentials(credentials = nil)
      raw = credential_omniauth_hash(credentials || credentials_store)
      return {} if raw.blank?

      usable_providers(raw)
    end

    def usable_providers(providers)
      return {} if providers.blank?

      providers.each_with_object({}) do |(name, options), memo|
        key = name.to_sym
        opts = compact_provider_options(options)
        next unless provider_ready?(key, opts)

        opts[:client_secret] = opts[:client_secret].to_s if key == :apple && !opts.key?(:client_secret)
        memo[key] = opts
      end
    end

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

    def credentials_store
      return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

      Rails.application.credentials
    rescue StandardError
      nil
    end

    def credential_omniauth_hash(credentials)
      return {} unless credentials

      raw = credentials.dig(:omniauth) || credentials.dig("omniauth")
      return {} unless raw.respond_to?(:to_h)

      raw.to_h
    end

    def compact_provider_options(options)
      return {} unless options.respond_to?(:to_h)

      options.to_h.each_with_object({}) do |(key, value), memo|
        compacted = value.is_a?(String) ? value.strip.presence : value
        memo[key.to_sym] = compacted unless compacted.nil?
      end
    end

    def provider_ready?(name, opts)
      return false if opts[:client_id].blank?

      return apple_ready?(opts) if name == :apple

      opts[:client_secret].present?
    end

    def apple_ready?(opts)
      opts[:client_secret].present? ||
        (opts[:team_id].present? && opts[:key_id].present? && opts[:pem].present?)
    end

    private_class_method :register_provider!, :credentials_store, :credential_omniauth_hash,
                         :compact_provider_options, :provider_ready?, :apple_ready?
  end
end
