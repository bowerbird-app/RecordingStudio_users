# frozen_string_literal: true

module RecordingStudioSiteSettings
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioSiteSettings

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioSiteSettings.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_site_settings_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_site_settings_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

    # Run before_initialize hooks
    initializer "recording_studio_site_settings.before_initialize",
                before: "recording_studio_site_settings.load_config" do |_app|
      RecordingStudioSiteSettings.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_site_settings.load_config" do |app|
      RecordingStudioSiteSettings.configuration.load_from_rails_app!(app)
      RecordingStudioSiteSettings.configuration.hooks.run(
        :on_configuration,
        RecordingStudioSiteSettings.configuration
      )
    end

    initializer "recording_studio_site_settings.after_initialize",
                after: "recording_studio_site_settings.load_config" do |_app|
      RecordingStudioSiteSettings.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_site_settings.helpers" do
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioSiteSettings::ApplicationHelper
      end
    end

    initializer "recording_studio_site_settings.admin_definitions" do
      config.to_prepare { RecordingStudioSiteSettings::Admin.register! }
    end

    initializer "recording_studio_site_settings.sync_parent_types" do
      config.to_prepare { RecordingStudioSiteSettings.sync_site_setting_parent_types!(load_site_setting: true) }
    end

    # Apply model extensions when models are loaded
    initializer "recording_studio_site_settings.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioSiteSettings::Engine.apply_model_extensions(model)
        end
      end
    end

    # Apply controller extensions
    initializer "recording_studio_site_settings.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioSiteSettings::Engine.apply_controller_extensions(controller)
        end
      end
    end
  end
end
