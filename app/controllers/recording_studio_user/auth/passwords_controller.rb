# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class PasswordsController < Devise::PasswordsController
      include Rails.application.routes.mounted_helpers
      include RecordingStudio::ControllerLayout
      include RecordingStudioUser::AuthRoutesHelper
      include RecordingStudioUser::Auth::ReturnPath

      recording_studio_layout { RecordingStudioUser.configuration.layout }

      def create
        user = resource_class.find_for_database_authentication(email: resource_params[:email])
        return super if user && !user.registered_with_otp?

        set_flash_message! :notice, (Devise.paranoid ? :send_paranoid_instructions : :send_instructions)
        redirect_to after_sending_reset_password_instructions_path_for(resource_name)
      end

      def respond_with(*resources, **options)
        location = options[:location]
        if popup_password_reset?(location, resources.first)
          render_auth_popup!(location)
        else
          super
        end
      end

      private

      def resource_class
        RecordingStudioUser.config.user_class
      end

      def popup_password_reset?(location, resource)
        location.present? &&
          RecordingStudioUser::ReturnTo.popup?(session) &&
          resource.respond_to?(:errors) &&
          resource.errors.empty? &&
          resource.respond_to?(:encrypted_password)
      end

      def after_resetting_password_path_for(resource)
        stored_auth_return_path(resource)
      end

      def after_sending_reset_password_instructions_path_for(_resource_name)
        auth_sign_in_path
      end
    end
  end
end
