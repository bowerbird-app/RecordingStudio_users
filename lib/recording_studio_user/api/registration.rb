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

      def already_registered?(name = USER_COUNT_ENDPOINT)
        return false unless RecordingStudioApi.respond_to?(:registered_endpoint)
        return false unless operations_api_present?

        RecordingStudioApi.registered_endpoint(name, api: USER_COUNT_API)
      end

      def operations_api_present?
        configuration = RecordingStudioApi.configuration if RecordingStudioApi.respond_to?(:configuration)
        return true unless configuration.respond_to?(:api_names)

        Array(configuration.api_names).include?("operations")
      end

      def register_index!
        register_users_endpoint!(USERS_INDEX_ENDPOINT, http_verb: :get, path: USERS_PATH, handler: Index,
                                                       summary: "List users", description: index_description)
      end

      def register_create!
        register_users_endpoint!(USERS_CREATE_ENDPOINT, http_verb: :post, path: USERS_PATH, handler: Create,
                                                        summary: "Create a user", description: create_description)
      end

      def register_show!
        register_users_endpoint!(USERS_SHOW_ENDPOINT, http_verb: :get, path: USER_PATH, handler: Show,
                                                      summary: "Show a user", description: show_description)
      end

      def register_update!
        register_users_endpoint!(USERS_UPDATE_ENDPOINT, http_verb: :patch, path: USER_PATH, handler: Update,
                                                        summary: "Update a user", description: update_description)
      end

      def register_users_endpoint!(name, http_verb:, path:, handler:, summary:, description:)
        return unless RecordingStudioApi.respond_to?(:register_endpoint)
        return if already_registered?(name)

        RecordingStudioApi.register_endpoint(
          name,
          api: USER_COUNT_API,
          http_verb: http_verb,
          path: path,
          handler: handler,
          openapi: { tags: ["Users"], summary: summary, description: description }
        )
      end

      def index_description
        "Paged users (page, per_page; same order as the Admin users screen). Requires Accessible :view on AdminRoot."
      end

      def create_description
        "Requires Accessible :edit on AdminRoot. Pass a password to call create_user! " \
          "(Devise user and People-root Profile). Omit the password when one-time codes are on " \
          "to call create_unconfirmed_user!. Omit it when they are off and the response is 422."
      end

      def show_description
        "One user. Requires Accessible :view on AdminRoot. Secrets are never returned."
      end

      def update_description
        "Updates profile fields via record_profile!. Email cannot be changed. Requires Accessible :edit on AdminRoot."
      end
    end
  end
end
