# frozen_string_literal: true

module RecordingStudioUsers
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioUsers

    initializer "recording_studio_users.load_config" do |app|
      config_file = File.join(app.config.paths["config"].first, "recording_studio_users.yml")
      if app.respond_to?(:config_for) && File.exist?(config_file)
        yaml = app.config_for(:recording_studio_users)
        RecordingStudioUsers.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_users)
        options = app.config.x.recording_studio_users
        RecordingStudioUsers.configuration.merge!(options.to_h) if options.respond_to?(:to_h)
      end

      RecordingStudioUsers.configuration.validate!
      RecordingStudioUsers::ProvisioningAuthorization.install!
    rescue RuntimeError => e
      Rails.logger.warn("[RecordingStudioUsers] configuration load failed: #{e.class}: #{e.message}")
      raise
    end

    initializer "recording_studio_users.recordable_types" do
      RecordingStudio.register_recordable_type("RecordingStudioUsers::UserRoot")
      RecordingStudio.register_recordable_type("RecordingStudioUsers::Profile")
    end

    initializer "recording_studio_users.helpers" do
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioUsers::ApplicationHelper
      end
    end

    config.to_prepare do
      RecordingStudioUsers::ProvisioningAuthorization.install!
      if RecordingStudioUsers.configuration.admin_enabled && defined?(RecordingStudioAdmin)
        require "recording_studio_users/admin"
        RecordingStudioUsers::Admin.register!
      end
    end
  end
end
