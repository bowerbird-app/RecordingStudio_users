# frozen_string_literal: true

module RecordingStudioUser
  module OtpNotifications
    module_function

    def register!
      return unless defined?(RecordingStudioNotifications)
      return if @registered

      RecordingStudioNotifications.register_notification_type(
        :registration_otp,
        label: "Registration code",
        category: :security,
        default_channels: %i[email],
        required_channels: %i[email],
        available_channels: %i[email],
        allowed_cadences: %i[individual],
        required_cadence: :individual,
        scope: :global
      )

      RecordingStudioNotifications.register_notification_type(
        :login_otp,
        label: "Login code",
        category: :security,
        default_channels: %i[email push],
        required_channels: %i[email],
        available_channels: %i[email push],
        allowed_cadences: %i[individual],
        required_cadence: :individual,
        scope: :global
      )

      RecordingStudioNotifications.register_delivery_payload_resolver(:registration_otp) do |notification:, delivery:|
        RecordingStudioUser::OtpDeliveryPayload.call(
          challenge_id: notification.metadata.fetch("otp_challenge_id"),
          delivery: delivery
        )
      end

      RecordingStudioNotifications.register_delivery_payload_resolver(:login_otp) do |notification:, delivery:|
        RecordingStudioUser::OtpDeliveryPayload.call(
          challenge_id: notification.metadata.fetch("otp_challenge_id"),
          delivery: delivery
        )
      end

      @registered = true
    end
  end
end
