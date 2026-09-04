# frozen_string_literal: true

module RecordingStudioSiteSettings
  class Configuration
    attr_accessor :site_root_resolver
    attr_reader :site_root_types, :hooks

    def initialize
      @site_root_types = ["Workspace"]
      @site_root_resolver = default_site_root_resolver
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        site_root_types: site_root_types,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def site_root_types=(types)
      @site_root_types = Array(types)
      RecordingStudioSiteSettings.sync_site_setting_parent_types!
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    def load_from_rails_app!(app)
      merge_x_config(app)
    end

    private

    def merge_x_config(app)
      xcfg = x_config_for(app)
      return if xcfg.blank?

      merge!(xcfg)
    rescue StandardError
      nil
    end

    def x_config_for(app)
      return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_site_settings)

      xcfg = app.config.x.recording_studio_site_settings
      return xcfg.to_h if xcfg.respond_to?(:to_h)
      return unless xcfg.respond_to?(:each_pair)

      xcfg.each_pair.with_object({}) { |(key, value), hash| hash[key] = value }
    end

    def default_site_root_resolver
      lambda do |context|
        controller = context.respond_to?(:controller) ? context.controller : context
        return unless controller.respond_to?(:current_root_recording)

        recording = controller.current_root_recording
        recording if RecordingStudioSiteSettings.site_root?(recording)
      end
    end
  end
end
