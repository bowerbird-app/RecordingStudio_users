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
        Serialize.user(persist_user!)
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
        build_user(email, attributes)
      end

      def required_email(attributes)
        email = attributes[:email].to_s.strip
        Errors.invalid_input!("email is required") if email.blank?

        email
      end

      def build_user(email, attributes)
        password = attributes[:password].presence
        return password_user!(email, password, attributes) if password

        unconfirmed_user!(email)
      end

      def password_user!(email, password, attributes)
        RecordingStudioUser.create_user!(
          email: email,
          password: password,
          password_confirmation: attributes[:password_confirmation].presence,
          actor: Access.actor_for(context),
          **attributes.slice(*Directory::PROFILE_ATTRIBUTE_KEYS)
        )
      end

      def unconfirmed_user!(email)
        Errors.invalid_input!("password is required") unless RecordingStudioUser.config.otp_enabled?

        RecordingStudioUser.create_unconfirmed_user!(email: email)
      end
    end
  end
end
