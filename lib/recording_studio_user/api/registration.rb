# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Registration
      module_function

      def register!
        register_user_count!
        register_index!
        register_create!
        register_show!
        register_update!
      end

      def register_user_count!
        register_named!(USER_COUNT_ENDPOINT, http_verb: :get, path: USER_COUNT_PATH, handler: UserCount,
                                             openapi: users_openapi("Count users", count_description))
      end

      def register_index!
        register_named!(USERS_INDEX_ENDPOINT, http_verb: :get, path: USERS_PATH, handler: Index,
                                              openapi: users_openapi("List users", index_description))
      end

      def register_create!
        register_named!(USERS_CREATE_ENDPOINT, http_verb: :post, path: USERS_PATH, handler: Create,
                                               openapi: users_openapi("Create a user", create_description))
      end

      def register_show!
        register_named!(USERS_SHOW_ENDPOINT, http_verb: :get, path: USER_PATH, handler: Show,
                                             openapi: users_openapi("Show a user", show_description))
      end

      def register_update!
        register_named!(USERS_UPDATE_ENDPOINT, http_verb: :patch, path: USER_PATH, handler: Update,
                                               openapi: users_openapi("Update a user", update_description))
      end

      def register_named!(name, http_verb:, path:, handler:, openapi: nil)
        return unless RecordingStudioApi.respond_to?(:register_endpoint)
        return if already_registered?(name)

        RecordingStudioApi.register_endpoint(
          name,
          api: OPERATIONS_API,
          http_verb: http_verb,
          path: path,
          handler: handler,
          openapi: openapi
        )
      end

      def already_registered?(name)
        return false unless RecordingStudioApi.respond_to?(:registered_endpoint)
        return false unless operations_api_present?

        RecordingStudioApi.registered_endpoint(name, api: OPERATIONS_API)
      end

      def operations_api_present?
        configuration = RecordingStudioApi.configuration if RecordingStudioApi.respond_to?(:configuration)
        return true unless configuration.respond_to?(:api_names)

        Array(configuration.api_names).include?("operations")
      end

      def users_openapi(summary, description)
        { tags: ["Users"], summary: summary, description: description }
      end

      def count_description
        "Total number of users. Requires Accessible :view on AdminRoot."
      end

      def index_description
        "Paged users (page, per_page; same order as the Admin users screen). Requires Accessible :view on AdminRoot."
      end

      def create_description
        "Creates a Devise user and People-root Profile. Requires Accessible :edit on AdminRoot. " \
          "Omit password for a passwordless (registered_with otp) account."
      end

      def show_description
        "One user. Requires Accessible :view on AdminRoot. Secrets are never returned."
      end

      def update_description
        "Updates profile fields via Directory.record_profile!. Email cannot be changed. " \
          "Requires Accessible :edit on AdminRoot."
      end
    end
  end
end
