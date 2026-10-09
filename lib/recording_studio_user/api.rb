# frozen_string_literal: true

require "active_record"
require_relative "api/access"
require_relative "api/errors"
require_relative "api/params"
require_relative "api/query"
require_relative "api/serialize"
require_relative "api/user_count"
require_relative "api/index"
require_relative "api/show"
require_relative "api/create"
require_relative "api/update"
require_relative "api/registration"

module RecordingStudioUser
  module Api
    OPERATIONS_API = :operations
    USER_COUNT_ENDPOINT = :user_count
    USER_COUNT_PATH = "users/count"
    USER_COUNT_API = :operations
    USERS_INDEX_ENDPOINT = :users
    USERS_CREATE_ENDPOINT = :users_create
    USERS_SHOW_ENDPOINT = :users_show
    USERS_UPDATE_ENDPOINT = :users_update
    USERS_PATH = "users"
    USER_PATH = "users/:id"

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
