# frozen_string_literal: true

require "devise"
require "flat_pack"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_root_switchable"

require "recording_studio_users/version"
require "recording_studio_users/configuration"
require "recording_studio_users/authorization"
require "recording_studio_users/current_context"
require "recording_studio_users/result"
require "recording_studio_users/services/create_first_root"
require "recording_studio_users/services/create_invitation"
require "recording_studio_users/services/accept_invitation"
require "recording_studio_users/engine"

module RecordingStudioUsers
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    delegate :authorize!,
             :authorized_operating?,
             :current_operating_role,
             :set_operating_role!,
             to: Authorization
  end
end
