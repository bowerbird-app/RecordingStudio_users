# frozen_string_literal: true

require "recording_studio_users/version"
require "recording_studio_accessible"
require "recording_studio_users/engine"
require "recording_studio_users/configuration"
require "recording_studio_users/services/base_service"
require "recording_studio_users/services/grant_membership"
require "recording_studio_users/services/change_membership_role"
require "recording_studio_users/services/revoke_membership"

module RecordingStudioUsers
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
