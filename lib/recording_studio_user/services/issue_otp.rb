# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class IssueOtp
      Result = Struct.new(:challenge, :issued, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(user:, purpose:, request: nil, session: nil, channels: nil)
        @user = user
        @purpose = purpose.to_s
        @request = request
        @session = session
        @channels = channels
      end

      def call
        OtpSetup.validate_schema!
        validate_user!
        apply_rate_limits!

        challenge = nil
        ActiveRecord::Base.transaction do
          revoke_existing!
          challenge = OtpChallenge.issue_for!(user: @user, purpose: @purpose)
        end

        store_session!(challenge)
        enqueue_notification_after_commit!(challenge)
        instrument!(:issued, challenge)

        Result.new(challenge: challenge, issued: true)
      end

      private

      def validate_user!
        raise ArgumentError, "unknown purpose" unless OtpChallenge::PURPOSES.include?(@purpose)

        if @purpose == "registration"
          raise ArgumentError, "registration OTP requires an OTP user" unless @user.otp_authentication_method?
          raise ArgumentError, "registration OTP requires an unconfirmed user" if @user.confirmed?
        elsif @purpose == "login"
          raise ArgumentError, "login OTP requires an OTP user" unless @user.otp_authentication_method?
          raise ArgumentError, "login OTP requires a confirmed user" unless @user.confirmed?
          raise ArgumentError, "user is not active for authentication" unless @user.active_for_authentication?
        end
      end

      def apply_rate_limits!
        keys = [
          normalized_email,
          @request&.remote_ip,
          @session&.id
        ].compact_blank
        keys.each { |key| OtpRateLimiter.allow_request!(scope: :issue, key: key) }
      end

      def revoke_existing!
        OtpChallenge.where(user: @user, purpose: @purpose, consumed_at: nil, revoked_at: nil).find_each(&:revoke!)
      end

      def store_session!(challenge)
        return unless @session

        @session[:otp_challenge_id] = challenge.id
        @session[:otp_purpose] = @purpose
      end

      def enqueue_notification_after_commit!(challenge)
        notification_type = @purpose == "registration" ? :registration_otp : :login_otp
        selected_channels = Array(@channels || default_channels).map(&:to_sym)

        ActiveRecord::Base.connection.after_transaction_commit do
          RecordingStudioNotifications.notify(
            notification_type: notification_type,
            recipient: @user,
            title: notification_title,
            body: nil,
            metadata: { "otp_challenge_id" => challenge.id },
            channels: selected_channels,
            idempotency_key: "otp/#{challenge.id}",
            deliver_later: true
          )
          instrument!(:delivery_queued, challenge)
        end
      end

      def default_channels
        if @purpose == "registration"
          RecordingStudioUser.config.otp_registration_channels
        else
          RecordingStudioUser.config.otp_login_channels
        end
      end

      def notification_title
        @purpose == "registration" ? "Verify your email" : "Your sign-in code"
      end

      def normalized_email
        @user.email.to_s.strip.downcase
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
