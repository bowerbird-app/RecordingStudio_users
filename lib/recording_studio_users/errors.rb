# frozen_string_literal: true

module RecordingStudioUsers
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class AuthorizationError < Error; end
  class TopologyError < Error; end
end
