# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class OpenCodeSignIn < RecordingStudio::Services::BaseService
      def initialize(token:, current_user: nil)
        super()
        @token = token
        @current_user = current_user
      end

      private

      def perform
        claim = CodeSignInToken.read(@token)
        user = user_for(claim)
        return success(kind: :rejected) unless usable?(claim, user)

        if same_person?(user)
          success(kind: :continue, user: user, return_to: claim.return_to, same_session: true)
        elsif @current_user.present?
          success(kind: :other_account, user: user, return_to: claim.return_to)
        else
          success(kind: :continue, user: user, return_to: claim.return_to, same_session: false)
        end
      end

      def usable?(claim, user)
        claim && user && claim.matches?(user) && sign_in_allowed?(user)
      end

      def user_for(claim)
        return if claim.blank?

        RecordingStudioUser.config.user_class.find_by(id: claim.user_id)
      end

      def same_person?(user)
        @current_user.present? && @current_user.id.to_s == user.id.to_s
      end

      def sign_in_allowed?(user)
        config = RecordingStudioUser.config
        return false unless config.otp_enabled? && config.otp_login_enabled?
        return false unless user.confirmed?
        return false if user.respond_to?(:active_for_authentication?) && !user.active_for_authentication?

        true
      end

      def service_args
        {}
      end
    end
  end
end
