# frozen_string_literal: true

module RecordingStudioUsers
  class Engine < ::Rails::Engine
    RECORDABLE_TYPES = %w[
      RecordingStudioUsers::UserRoot
      RecordingStudioUsers::Profile
    ].freeze

    isolate_namespace RecordingStudioUsers

    config.to_prepare do
      RECORDABLE_TYPES.each { |type_name| RecordingStudio.register_recordable_type(type_name) }
    end

    class << self
      def load_configuration(app)
        yaml = yaml_configuration(app)
        RecordingStudioUsers.configuration.merge!(yaml) if yaml.respond_to?(:each)

        rails_configuration = rails_configuration(app)
        RecordingStudioUsers.configuration.merge!(rails_configuration) if rails_configuration.respond_to?(:each)

        RecordingStudioUsers::Hooks.run(:on_configuration, RecordingStudioUsers.configuration)
      end

      def apply_model_extensions(target)
        extensions = RecordingStudioUsers.configuration.hooks.model_extensions_for(extension_keys_for(target))
        apply_extensions(target, extensions)
      end

      def apply_controller_extensions(target)
        extensions = RecordingStudioUsers.configuration.hooks.controller_extensions_for(extension_keys_for(target))
        apply_extensions(target, extensions)
      end

      private

      def yaml_configuration(app)
        return unless app.respond_to?(:config_for)
        return unless configuration_file_present?(app)

        app.config_for(:recording_studio_users)
      end

      def configuration_file_present?(app)
        return true unless app.respond_to?(:root) && app.root

        %w[yml yaml].any? do |extension|
          app.root.join("config/recording_studio_users.#{extension}").file?
        end
      end

      def rails_configuration(app)
        return unless app.config.respond_to?(:x)
        return unless app.config.x.respond_to?(:recording_studio_users)

        options = app.config.x.recording_studio_users
        return options.to_h if options.respond_to?(:to_h)
        return unless options.respond_to?(:each_pair)

        options.each_pair.to_h
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_users_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_users_applied_extensions, applied)
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
    initializer "recording_studio_users.before_initialize", before: "recording_studio_users.load_config" do |_app|
      RecordingStudioUsers::Hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_users.load_config" do |app|
      RecordingStudioUsers::Engine.load_configuration(app)
    end

    initializer "recording_studio_users.register_recordable_types",
                after: "recording_studio_users.load_config" do
      RECORDABLE_TYPES.each { |type_name| RecordingStudio.register_recordable_type(type_name) }
    end

    # Run after_initialize hooks
    initializer "recording_studio_users.after_initialize",
                after: "recording_studio_users.register_recordable_types" do |_app|
      RecordingStudioUsers::Hooks.run(:after_initialize, self)
    end

    # Apply model extensions when models are loaded
    initializer "recording_studio_users.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioUsers::Engine.apply_model_extensions(model)
        end
      end
    end

    # Apply controller extensions
    initializer "recording_studio_users.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioUsers::Engine.apply_controller_extensions(controller)
        end
      end
    end
  end
end
