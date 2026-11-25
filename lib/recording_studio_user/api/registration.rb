# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Registration
      module_function

      def register!
        register_index!
        register_create!
        register_show!
        register_update!
      end

      def already_registered?(name)
        return false unless RecordingStudioApi.respond_to?(:registered_endpoint)
        return false unless operations_api_present?

        RecordingStudioApi.registered_endpoint(name, api: USERS_API)
      end

      def operations_api_present?
        configuration = RecordingStudioApi.configuration if RecordingStudioApi.respond_to?(:configuration)
        return true unless configuration.respond_to?(:api_names)

        Array(configuration.api_names).include?("operations")
      end

      def register_index!
        register_users_endpoint!(USERS_INDEX_ENDPOINT, http_verb: :get, path: USERS_PATH, handler: Index,
                                                       summary: "List users", description: index_description,
                                                       input_contract: Params.index_input_contract)
      end

      def register_create!
        register_users_endpoint!(USERS_CREATE_ENDPOINT, http_verb: :post, path: USERS_PATH, handler: Create,
                                                        summary: "Create a user", description: create_description,
                                                        input_contract: Params.create_input_contract)
      end

      def register_show!
        register_users_endpoint!(USERS_SHOW_ENDPOINT, http_verb: :get, path: USER_PATH, handler: Show,
                                                      summary: "Show a user", description: show_description,
                                                      scope_id: false)
      end

      def register_update!
        register_users_endpoint!(
          USERS_UPDATE_ENDPOINT,
          http_verb: :patch,
          path: USER_PATH,
          handler: Update,
          summary: "Update a user",
          description: update_description,
          input_contract: Params.update_input_contract,
          scope_id: false, required_role: :edit
        )
      end

      def register_users_endpoint!(name, http_verb:, path:, handler:, summary:, description:, input_contract: nil,
                                   scope_id: nil, required_role: nil)
        return unless RecordingStudioApi.respond_to?(:register_endpoint)
        return if already_registered?(name)

        options = {
          api: USERS_API, http_verb: http_verb, path: path, handler: handler,
          openapi: { tags: ["Users"], summary: summary, description: description },
          input_contract: input_contract
        }
        # These ids are user rows on the admin-only operations API, not recordings in a root.
        options[:scope_id] = scope_id unless scope_id.nil?
        options[:required_role] = required_role unless required_role.nil?
        RecordingStudioApi.register_endpoint(name, **options)
      end

      def index_description
        "Paged users. page and per_page set offset paging. Same order as the Admin users screen. " \
          "Requires view access to the admin area."
      end

      def create_description
        "Pass a password to create a confirmed Devise user and People Profile. " \
          "Omit the password when one-time codes are on to create an unconfirmed otp user. " \
          "Omit it when they are off and the response is 422. Requires edit access to the admin area."
      end

      def show_description
        "One user. Secrets are never returned. Requires view access to the admin area."
      end

      def update_description
        "Updates profile fields. Email cannot be changed. Requires edit access to the admin area."
      end
    end
  end
end
