# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Registration
      module_function

      def register!
        register_user_count!
      end

      def register_user_count!
        return unless RecordingStudioApi.respond_to?(:register_endpoint)
        return if already_registered?

        RecordingStudioApi.register_endpoint(
          USER_COUNT_ENDPOINT,
          api: USER_COUNT_API,
          http_verb: :get,
          path: USER_COUNT_PATH,
          handler: UserCount
        )
      end

      def already_registered?
        return false unless RecordingStudioApi.respond_to?(:registered_endpoint)
        return false unless operations_api_present?

        RecordingStudioApi.registered_endpoint(USER_COUNT_ENDPOINT, api: USER_COUNT_API)
      end

      def operations_api_present?
        configuration = RecordingStudioApi.configuration if RecordingStudioApi.respond_to?(:configuration)
        return true unless configuration.respond_to?(:api_names)

        Array(configuration.api_names).include?("operations")
      end
    end
  end
end
