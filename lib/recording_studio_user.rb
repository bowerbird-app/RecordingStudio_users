# frozen_string_literal: true

require "recording_studio_user/version"
require "recording_studio_user/configuration"
require "recording_studio"
require "flat_pack"
require "devise"
require "recording_studio_admin"
require "recording_studio_user/admin"
require "recording_studio_user/engine"

module RecordingStudioUser
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def user_class
      configuration.user_model.to_s.constantize
    end

    def register_admin!
      Admin.register!
    end
  end
end
