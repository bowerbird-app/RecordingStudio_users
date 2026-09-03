# frozen_string_literal: true

module RecordingStudioUser
  module OtpNotifications
    SHARED_TYPE_OPTIONS = {
      category: :security,
      required_channels: %i[email],
      allowed_cadences: %i[individual],
      required_cadence: :individual,
      scope: :global
    }.freeze

    TYPES = {
      registration_otp: {
        label: "Registration code",
        default_channels: %i[email],
        available_channels: %i[email]
      },
      login_otp: {
        label: "Login code",
        default_channels: %i[email push],
        available_channels: %i[email push]
      }
    }.freeze

    module_function

    def register!
      return unless defined?(RecordingStudioNotifications)
      return if @registered

      TYPES.each do |key, options|
        register_type!(key, **options)
        register_resolver!(key)
      end

      @registered = true
    end

    def register_type!(key, **)
      RecordingStudioNotifications.register_notification_type(key, **SHARED_TYPE_OPTIONS, **)
    end

    def register_resolver!(key)
      RecordingStudioNotifications.register_delivery_payload_resolver(key) do |notification:, delivery:|
        RecordingStudioUser::OtpDeliveryPayload.call(
          challenge_id: notification.metadata.fetch("otp_challenge_id"),
          delivery: delivery
        )
      end
    end
  end
end
