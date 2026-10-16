# frozen_string_literal: true

require_relative "issue_otp/result"

module RecordingStudioUser
  module Services
    class IssueOtp
      NOTIFICATION_TYPES = { "registration" => :registration_otp, "login" => :login_otp }.freeze
      TITLE_KEYS = {
        "registration" => "recording_studio_user.otp.verify_your_email",
        "login" => "recording_studio_user.otp.your_sign_in_code"
      }.freeze

      def self.call(...)
        new(...).call
      end

      # +checked_keys+ are email, IP, and session buckets that the caller
      # already reserved. When they are passed, this service does not reserve
      # them again.
      def initialize(user:, purpose:, request: nil, session: nil, channels: nil, rate_limit_scope: :issue,
                     checked_keys: nil)
        @user = user
        @purpose = purpose.to_s
        @request = request
        @session = session
        @channels = channels
        @rate_limit_scope = rate_limit_scope.to_sym
        @checked_keys = checked_keys
      end

      def call
        OtpSetup.validate_schema!
        raise ArgumentError, "unknown purpose" unless OtpChallenge::PURPOSES.include?(@purpose)
        return Result.suppressed unless user_can_receive_code?
        return Result.throttled unless reserve_rate_limit!

        challenge = issue_challenge!
        store_session!(challenge)
        deliver!(challenge)
        instrument!(:issued, challenge)
        Result.issued(challenge)
      end

      private

      def user_can_receive_code?
        return false if @user.blank?
        return !@user.confirmed? if @purpose == "registration"

        @user.confirmed? && @user.active_for_authentication?
      end

      def reserve_rate_limit!
        return true if @checked_keys

        OtpRateLimiter.allow_requests!(scope: @rate_limit_scope, keys: limiter_keys)
        true
      rescue OtpRateLimiter::RateLimited
        false
      end

      def limiter_keys
        [OtpRateLimiter.email_key(normalized_email), @request&.remote_ip, session_id].compact_blank
      end

      def session_id
        return if @session.blank? || @session.is_a?(Hash) || !@session.respond_to?(:id)

        @session.id
      end

      def issue_challenge!
        ActiveRecord::Base.transaction do
          revoke_existing!
          OtpChallenge.issue_for!(user: @user, purpose: @purpose)
        end
      end

      def revoke_existing!
        OtpChallenge.where(user: @user, purpose: @purpose, consumed_at: nil, revoked_at: nil).lock.find_each(&:revoke!)
      end

      def store_session!(challenge)
        return unless @session

        @session[:otp_challenge_id] = challenge.id
        @session[:otp_purpose] = @purpose
        @session[:otp_user_id] = @user.id
      end

      def normalized_email
        OtpRateLimiter.normalize_email(@user.email)
      end

      def instrument!(event, challenge)
        ActiveSupport::Notifications.instrument(
          "otp.#{event}.recording_studio_user",
          challenge_id: challenge.id,
          user_id: @user.id,
          purpose: @purpose
        )
      end
    end
  end
end
