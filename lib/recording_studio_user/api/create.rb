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
        attributes = Params.create_attributes(context)
        email = attributes[:email].to_s.strip
        Errors.invalid_input!("email is required") if email.blank?

        user = Directory.create_user!(
          email: email,
          password: attributes[:password].presence,
          password_confirmation: attributes[:password_confirmation].presence,
          actor: Access.actor_for(context),
          **attributes.slice(*Directory::PROFILE_ATTRIBUTE_KEYS)
        )
        emit_registration_completed!(user)
        Serialize.user(user)
      rescue ActiveRecord::RecordInvalid => error
        Errors.from_record_invalid(error)
      rescue ArgumentError => error
        Errors.invalid_input!(error.message)
      end

      private

      attr_reader :context

      def emit_registration_completed!(user)
        method = user.respond_to?(:registered_with_otp?) && user.registered_with_otp? ? :otp : :password
        RegistrationCompleted.emit!(user_id: user.id, method: method)
      end
    end
  end
end
