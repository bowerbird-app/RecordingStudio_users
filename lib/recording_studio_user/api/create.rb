# frozen_string_literal: true

module RecordingStudioUser
  module Api
    class Create
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Access.authorize_edit!(context)
        user = persist_user!
        emit_registration_completed!(user)
        Serialize.user(user)
      rescue ActiveRecord::RecordInvalid => e
        Errors.from_record_invalid(e)
      rescue ArgumentError => e
        Errors.invalid_input!(e.message)
      end

      private

      attr_reader :context

      def persist_user!
        attributes = Params.create_attributes(context)
        email = required_email(attributes)
        profile = attributes.slice(*Directory::PROFILE_ATTRIBUTE_KEYS)
        build_user(email, attributes, profile)
      end

      def required_email(attributes)
        email = attributes[:email].to_s.strip
        Errors.invalid_input!("email is required") if email.blank?

        email
      end

      def build_user(email, attributes, profile)
        actor = Access.actor_for(context)
        password = attributes[:password].presence
        return passwordless_user!(email, actor, profile) if password.blank?

        password_user!(email, password, attributes, actor, profile)
      end

      def password_user!(email, password, attributes, actor, profile)
        RecordingStudioUser.create_user!(
          email: email,
          password: password,
          password_confirmation: attributes[:password_confirmation].presence,
          actor: actor,
          **profile
        )
      end

      def passwordless_user!(email, actor, profile)
        Directory.create_passwordless_user!(email: email, actor: actor, **profile)
      end

      def emit_registration_completed!(user)
        method = user.respond_to?(:registered_with_otp?) && user.registered_with_otp? ? :otp : :password
        RegistrationCompleted.emit!(user_id: user.id, method: method)
      end
    end
  end
end
