# frozen_string_literal: true

require_relative "api/user_count"
require_relative "api/registration"

module RecordingStudioUser
  module Api
    USER_COUNT_ENDPOINT = :user_count
    USER_COUNT_PATH = "users/count"
    USER_COUNT_API = :operations

    class << self
      def register!
        return unless recording_studio_api_available?

        Registration.register!
        true
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_endpoint)
      end
    end
  end
end
