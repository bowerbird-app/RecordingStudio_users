# frozen_string_literal: true

module RecordingStudioUser
  module Directory
    # Devise row writes for Directory.create_user!
    module Accounts
      module_function

      def create_devise_user!(email, password, password_confirmation, attributes)
        user = RecordingStudioUser.config.user_class.new(
          email: email,
          password: password,
          password_confirmation: password_confirmation,
          **devise_user_attributes(attributes)
        )
        skip_confirmation_for_password_account(user)
        user.save!
        user
      end

      def create_passwordless_user!(email, attributes)
        klass = RecordingStudioUser.config.user_class
        attrs = attributes.symbolize_keys.except(:password, :password_confirmation)
        attrs = attrs.merge(registered_with: "otp") if klass.column_names.include?("registered_with")
        user = klass.new(email: email, **attrs)
        user.skip_confirmation_notification! if user.respond_to?(:skip_confirmation_notification!)
        user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
        user.save!
        user
      end

      def devise_user_attributes(attributes)
        attrs = attributes.symbolize_keys
        return attrs unless RecordingStudioUser.config.user_class.column_names.include?("registered_with")

        attrs.merge(registered_with: "password")
      end

      def skip_confirmation_for_password_account(user)
        return unless RecordingStudioUser.config.password_registration_confirmation == :existing_policy
        return unless user.respond_to?(:skip_confirmation!)

        user.skip_confirmation!
      end
    end
  end
end
