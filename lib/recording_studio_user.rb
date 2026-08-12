# frozen_string_literal: true

require "recording_studio_user/version"
require "recording_studio_user/configuration"
require "recording_studio_user/engine"
require "recording_studio_user/admin"

module RecordingStudioUser
  class << self
    def config
      @config ||= Configuration.new
    end
    alias configuration config

    def configure
      yield(config) if block_given?
    end
  end
end
