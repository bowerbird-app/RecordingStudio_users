# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module PendingEmail
      extend ActiveSupport::Concern

      AUTH_EMAIL_KEY = :auth_email

      private

      def submitted_email_from_params
        params.dig(:user, :email).to_s.strip.downcase
      end

      def pending_auth_email
        session[AUTH_EMAIL_KEY].presence || submitted_email_from_params.presence
      end

      def store_pending_auth_email!(email)
        session[AUTH_EMAIL_KEY] = email
      end

      def clear_pending_auth_email!
        session.delete(AUTH_EMAIL_KEY)
      end

      def finish_sign_in!(user)
        clear_pending_auth_email!
        sign_in_user!(user)
        redirect_to after_sign_in_path_for(user)
      end

      def finish_sign_up!(user)
        clear_pending_auth_email!
        sign_in_user!(user)
        redirect_to after_sign_up_path_for(user)
      end
    end
  end
end
