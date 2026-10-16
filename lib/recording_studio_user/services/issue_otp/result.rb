# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class IssueOtp
      Result = Struct.new(:challenge, :status, keyword_init: true) do
        def self.issued(challenge)
          new(challenge: challenge, status: :issued)
        end

        def self.throttled
          new(status: :throttled)
        end

        def self.suppressed
          new(status: :suppressed)
        end

        def challenge_id
          challenge&.id
        end

        def issued?
          status == :issued
        end

        def throttled?
          status == :throttled
        end

        def suppressed?
          status == :suppressed
        end
      end

      private

      def deliver!(challenge)
        RecordingStudioNotifications.notify(**notification_attributes(challenge))
        instrument!(:delivery_queued, challenge)
      end

      def notification_attributes(challenge)
        {
          notification_type: NOTIFICATION_TYPES.fetch(@purpose),
          recipient: @user,
          title: I18n.t(TITLE_KEYS.fetch(@purpose)),
          body: nil,
          url: notification_url(challenge),
          metadata: { "otp_challenge_id" => challenge.id },
          channels: requested_channels,
          idempotency_key: "otp/#{challenge.id}"
        }
      end

      def requested_channels
        Array(@channels || default_channels).map(&:to_sym)
      end

      def notification_url(challenge)
        return unless @purpose == "login"

        "#{RecordingStudioUser.config.mount_path}/otp_codes/#{challenge.id}"
      end

      def default_channels
        if @purpose == "registration"
          RecordingStudioUser.config.otp_registration_channels
        else
          RecordingStudioUser.config.otp_login_channels
        end
      end
    end
  end
end
