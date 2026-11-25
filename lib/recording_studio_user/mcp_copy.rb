# frozen_string_literal: true

require_relative "mcp_copy/copy"

module RecordingStudioUser
  # Registers Users named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  # Catalog metrics are not register_tool targets. Hosts include them by name.
  module McpCopy
    OPERATIONS_METRIC_NAMES = %w[
      users-total
      users-signups
      users-total_over_time
      users-by_method
      users-confirmation
      otp_challenges-failed_over_time
    ].freeze
    ENDPOINT_NAMES = %w[users users_create users_show users_update].freeze
    ENDPOINTS = {
      "users" => :users,
      "users_create" => :users_create,
      "users_show" => :users_show,
      "users_update" => :users_update
    }.freeze

    module_function

    def mcp_available?
      defined?(::RecordingStudioMcp) && ::RecordingStudioMcp.respond_to?(:register_tool)
    end

    def mcp
      ::RecordingStudioMcp
    end

    def register!
      return unless mcp_available?

      register_tools(ENDPOINT_NAMES)
    end

    def tool_names(api: nil)
      case api&.to_sym
      when :public then []
      else OPERATIONS_METRIC_NAMES
      end
    end

    def register_tools(names)
      names.each { |name| register_named_tool(name) }
    end

    def register_named_tool(name)
      mcp.register_tool(**tool_registration(name))
    end

    def tool_registration(name)
      {
        name: name,
        endpoint: ENDPOINTS.fetch(name),
        title: Copy::TITLES.fetch(name),
        description: Copy::DESCRIPTIONS.fetch(name),
        input: Copy::INPUTS.fetch(name),
        output: Copy::OUTPUTS.fetch(name)
      }
    end
  end
end
