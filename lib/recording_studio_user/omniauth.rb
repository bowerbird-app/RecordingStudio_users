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

    module_function

    def register_providers!
      providers = RecordingStudioUser.config.omniauth_providers
      return if providers.blank?

      Devise.setup do |config|
        providers.each do |name, options|
          opts = (options || {}).to_h.symbolize_keys
          client_id = opts.fetch(:client_id)
          client_secret = opts.fetch(:client_secret)
          extra = opts.except(:client_id, :client_secret)
          config.omniauth(name.to_sym, client_id, client_secret, **extra)
        end
      end
    end

    def ensure_omniauthable!(user_class)
      providers = RecordingStudioUser.config.omniauth_provider_names
      return if providers.empty?
      return if user_class.devise_modules.include?(:omniauthable)

      user_class.devise :omniauthable, omniauth_providers: providers
    end

    def find_or_create_user!(auth)
      identity = Identity.find_by(provider: auth.provider, uid: auth.uid.to_s)
      return identity.user if identity

      email = auth.info&.email.to_s.strip.downcase
      raise MissingEmailError, "Email is required from the provider" if email.blank?

      user = RecordingStudioUser.config.user_class.find_by(email: email)
      if user
        create_identity!(user, auth)
        return user
      end

      unless RecordingStudioUser.config.omniauth_create_account?
        raise AccountCreationDisabledError, "Account creation from this provider is disabled"
      end

      create_user_from_auth!(auth, email)
    end

    def connect!(user, auth)
      existing = Identity.find_by(provider: auth.provider, uid: auth.uid.to_s)
      if existing
        raise IdentityTakenError, "That Google account is already linked to another user" if existing.user_id != user.id

        return existing
      end

      create_identity!(user, auth)
    end

    def disconnect!(user, provider)
      identity = user.identities.find_by!(provider: provider.to_s)
      if user.identities.count == 1 && !password_set?(user)
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

    def create_identity!(user, auth)
      user.identities.create!(
        provider: auth.provider.to_s,
        uid: auth.uid.to_s,
        email: auth.info&.email
      )
    end

    def create_user_from_auth!(auth, email)
      password = Devise.friendly_token[0, 32]
      first_name, last_name = name_parts_from(auth)
      user = nil

      ActiveRecord::Base.transaction do
        user = Directory.create_user!(
          email: email,
          password: password,
          password_confirmation: password,
          first_name: first_name,
          last_name: last_name,
          time_zone: "UTC"
        )
        create_identity!(user, auth)
        # Google-only: keep a blank digest so disconnect lockout checks work and
        # password_required? stays false while an identity is present.
        user.update_column(:encrypted_password, "")
      end

      user
    end

    def name_parts_from(auth)
      info = auth.info
      first = info&.first_name.to_s.strip
      last = info&.last_name.to_s.strip
      if first.blank? && last.blank?
        parts = info&.name.to_s.strip.split(/\s+/, 2)
        first = parts[0].to_s
        last = parts[1].to_s
      end
      first = "User" if first.blank?
      last = "Account" if last.blank?
      [first, last]
    end
    private_class_method :create_identity!, :create_user_from_auth!, :name_parts_from
  end
end
