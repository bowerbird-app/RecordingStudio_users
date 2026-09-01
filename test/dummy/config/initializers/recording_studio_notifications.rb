# frozen_string_literal: true

RecordingStudioNotifications.configure do |config|
  config.deliver_later = false
  config.actor_resolver = -> { Current.actor }
  config.current_root_resolver = lambda { |controller:|
    controller.send(:current_root_recording) if controller.respond_to?(:current_root_recording, true)
  }
  config.allowed_url_hosts = %w[localhost 127.0.0.1 example.com].union(
    [Rails.application.routes.default_url_options[:host]].compact
  )

  # Dummy host type so settings can show in-app, email, and push together.
  # OTP types are registered by RecordingStudioUser when otp_enabled.
  config.notification_types.register(
    :generic,
    label: "Generic notification",
    description: "Default in-app notification",
    icon: :bell,
    default_channels: %i[in_app],
    available_channels: %i[in_app email push],
    scope: :optional_root
  )
end
