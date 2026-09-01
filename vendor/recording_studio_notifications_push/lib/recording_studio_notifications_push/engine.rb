# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioNotificationsPush

    initializer "recording_studio_notifications_push.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    initializer "recording_studio_notifications_push.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
    end

    initializer "recording_studio_notifications_push.load_config" do |app|
      yaml = app.config_for(:recording_studio_notifications_push) if app.respond_to?(:config_for)
      RecordingStudioNotificationsPush.configuration.merge!(yaml) if yaml.respond_to?(:each)

      options = app.config.x.recording_studio_notifications_push if app.config.respond_to?(:x)
      RecordingStudioNotificationsPush.configuration.merge!(options.to_h) if options.respond_to?(:to_h)
    rescue StandardError => e
      Rails.logger&.warn("[RecordingStudioNotificationsPush] configuration was not loaded: #{e.message}")
    end

    initializer "recording_studio_notifications_push.register_channel",
                after: "recording_studio_notifications_push.load_config" do
      config.to_prepare { RecordingStudioNotificationsPush.register! }
    end

    initializer "recording_studio_notifications_push.register_pwa_service_worker",
                after: "recording_studio_notifications_push.register_channel" do
      config.to_prepare do
        next unless defined?(RecordingStudioPwa) &&
                    RecordingStudioPwa.respond_to?(:register_service_worker_extension)

        RecordingStudioPwa.register_service_worker_extension(
          "recording_studio_notifications_push/service_worker_push"
        )
      end
    end
  end
end
