# frozen_string_literal: true

require "recording_studio_user/version"
require "recording_studio_user/engine"
require "recording_studio_user/configuration"
require "recording_studio_user/services/base_service"
require "recording_studio_user/services/example_service"

module RecordingStudioUser
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
