# frozen_string_literal: true

module RecordingStudioUser
  module Omniauth
    # Find-or-create, connect, and disconnect for OmniAuth identities.
    module IdentityFlow
      module_function

      def find_or_create_user!(auth)
        identity = Identity.find_by(provider: auth.provider, uid: auth.uid.to_s)
        return identity.user if identity

        email = normalized_email(auth)
        existing = find_user_by_email(email)
        raise UnconfirmedEmailError, "Existing email is not confirmed" if existing && !email_confirmed?(existing)
        return create_identity!(existing, auth) && existing if existing

        raise AccountCreationDisabledError, "Account creation from this provider is disabled" unless
          RecordingStudioUser.config.omniauth_create_account?

        create_user_from_auth!(auth, email)
      end

      def connect!(user, auth)
        existing = Identity.find_by(provider: auth.provider, uid: auth.uid.to_s)
        return existing if existing&.user_id == user.id

        ensure_identity_available!(user, auth, existing)

        # Connect while signed in does not invent an email. Instagram often has none;
        # Apple may omit it after the first consent. Identity.email stays blank.
        create_identity!(user, auth)
      end

      def disconnect!(user, provider)
        identity = user.identities.find_by!(provider: provider.to_s)
        if !other_usable_identity?(user, identity) && !password_set?(user)
          raise LastSignInMethodError,
                "Connect another sign-in method or set a password before disconnecting"
        end

        identity.destroy!
      end

      # Identities for providers the host dropped are not a fallback sign-in method.
      def other_usable_identity?(user, identity)
        user.identities.for_configured_providers.where.not(id: identity.id).exists?
      end

      def password_set?(user)
        user.respond_to?(:encrypted_password) && user.encrypted_password.present?
      end

      def ensure_identity_available!(user, auth, existing)
        if existing
          raise IdentityTakenError,
                "That #{provider_label(auth.provider)} account is already linked to another user"
        end
        return unless user.identity_for(auth.provider)

        raise IdentityTakenError,
              "A #{provider_label(auth.provider)} account is already linked to this user"
      end

      def normalized_email(auth)
        email = auth.info&.email.to_s.strip.downcase
        raise MissingEmailError, "Email is required from the provider" if email.blank?
        raise UnverifiedEmailError, "Email was not verified by the provider" if email_explicitly_unverified?(auth)

        email
      end

      def email_explicitly_unverified?(auth)
        value = auth.info&.email_verified
        value = auth.extra&.raw_info&.email_verified if value.nil?
        value == false || value.to_s.casecmp?("false")
      end

      def create_identity!(user, auth)
        user.identities.create!(
          provider: auth.provider.to_s,
          uid: auth.uid.to_s,
          email: auth.info&.email.to_s.strip.downcase.presence
        )
      end

      def find_user_by_email(email)
        RecordingStudioUser.config.user_class.find_by("LOWER(email) = ?", email)
      end

      def email_confirmed?(user)
        !user.respond_to?(:confirmed?) || user.confirmed?
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

      def provider_label(provider)
        Omniauth.provider_label(provider)
      end
    end
  end
end
