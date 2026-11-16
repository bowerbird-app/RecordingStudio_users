# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class ConfirmPasswordSignup < RecordingStudio::Services::BaseService
      def initialize(user:, session:)
        super()
        @user = user
        @session = session
      end

      private

      def perform
        raise ArgumentError, "user is required" if @user.blank?
        raise ArgumentError, "email proof requires Devise confirmable" unless @user.respond_to?(:confirm)

        already_confirmed = @user.confirmed?
        PasswordConfirmation.bind(@session) { @user.confirm }
        success(user: @user.reload, already_confirmed: already_confirmed)
      end

      def service_args
        { user_id: @user&.id }
      end
    end
  end
end
