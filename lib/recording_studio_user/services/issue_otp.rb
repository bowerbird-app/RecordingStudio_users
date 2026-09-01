# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class IssueOtp
      Result = Struct.new(:challenge, :issued, keyword_init: true)

      NOTIFICATION_TYPES = { "registration" => :registration_otp, "login" => :login_otp }.freeze
      TITLES = { "registration" => "Verify your email", "login" => "Your sign-in code" }.freeze

      def self.call(...)
        new(...).call
      end

      def initialize(user:, purpose:, request: nil, session: nil, channels: nil, rate_limit_scope: :issue)
        @user = user
        @purpose = purpose.to_s
        @request = request
        @session = session
        @channels = channels
        @rate_limit_scope = rate_limit_scope.to_sym
      end

      def call
        OtpSetup.validate_schema!
        validate_user!
        apply_rate_limits!

        challenge = issue_challenge!
        store_session!(challenge)
        deliver!(challenge)
        instrument!(:issued, challenge)

        Result.new(challenge: challenge, issued: true)
      end

      private

      def issue_challenge!
        ActiveRecord::Base.transaction do
          revoke_existing!
          OtpChallenge.issue_for!(user: @user, purpose: @purpose)
        end
      end

      def validate_user!
        raise ArgumentError, "unknown purpose" unless OtpChallenge::PURPOSES.include?(@purpose)

        @purpose == "registration" ? validate_registration_user! : validate_login_user!
      end

      def validate_registration_user!
        raise ArgumentError, "registration OTP requires an OTP user" unless @user.otp_authentication_method?
        raise ArgumentError, "registration OTP requires an unconfirmed user" if @user.confirmed?
      end

      def validate_login_user!
        raise ArgumentError, "login OTP requires a confirmed user" unless @user.confirmed?
        raise ArgumentError, "user is not active for authentication" unless @user.active_for_authentication?
      end

      def apply_rate_limits!
        keys = [normalized_email, @request&.remote_ip, @session&.id].compact_blank
        keys.each { |key| OtpRateLimiter.allow_request!(scope: @rate_limit_scope, key: key) }
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

      def deliver!(challenge)
        RecordingStudioNotifications.notify(
          notification_type: NOTIFICATION_TYPES.fetch(@purpose),
          recipient: @user,
          title: TITLES.fetch(@purpose),
          body: nil,
          metadata: { "otp_challenge_id" => challenge.id },
          channels: requested_channels,
          idempotency_key: "otp/#{challenge.id}"
        )
        instrument!(:delivery_queued, challenge)
      end

      def requested_channels
        Array(@channels || default_channels).map(&:to_sym)
      end

      def default_channels
        if @purpose == "registration"
          RecordingStudioUser.config.otp_registration_channels
        else
          RecordingStudioUser.config.otp_login_channels
        end
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
