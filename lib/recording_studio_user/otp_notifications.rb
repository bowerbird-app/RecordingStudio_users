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

    TYPE_KEYS = {
      registration_otp: {
        label_key: "recording_studio_user.otp.registration_label",
        default_channels: %i[email],
        available_channels: %i[email]
      },
      login_otp: {
        label_key: "recording_studio_user.otp.login_label",
        default_channels: %i[email push],
        available_channels: %i[email push]
      }
    }.freeze

    module_function

    def register!
      return unless defined?(RecordingStudioNotifications)
      return if @registered

      TYPE_KEYS.each do |key, options|
        register_type!(key, **options)
        register_resolver!(key)
      end

      @registered = true
    end

    def register_type!(key, label_key:, **)
      RecordingStudioNotifications.register_notification_type(
        key,
        **SHARED_TYPE_OPTIONS,
        **,
        label: I18n.t(label_key)
      )
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
