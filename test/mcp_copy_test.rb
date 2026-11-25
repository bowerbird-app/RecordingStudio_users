# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  FORBIDDEN = [
    "RecordingStudio::", "Accessible", ":edit", ":view", "permission", "role",
    "AdminRoot", "staff", "operations token"
  ].freeze

  OPERATIONS_METRICS = %w[
    users-total
    users-signups
    users-total_over_time
    users-by_method
    users-confirmation
    otp_challenges-failed_over_time
  ].freeze

  ENDPOINTS = %w[users users_create users_show users_update].freeze

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    refute Object.const_defined?(:RecordingStudioMcp, false)
    assert_nil RecordingStudioUser::McpCopy.register!
  end

  def test_register_is_a_no_op_when_register_tool_is_missing
    fake = Module.new
    Object.const_set(:RecordingStudioMcp, fake)
    refute_respond_to fake, :register_tool
    assert_nil RecordingStudioUser::McpCopy.register!
  ensure
    Object.send(:remove_const, :RecordingStudioMcp) if Object.const_defined?(:RecordingStudioMcp, false)
  end

  def test_register_declares_named_endpoint_tools
    RecordingMcp.reset!
    Object.const_set(:RecordingStudioMcp, RecordingMcp)
    RecordingStudioUser::McpCopy.register!
    RecordingStudioUser::McpCopy.register!

    assert_equal ENDPOINTS, RecordingMcp.tools.keys
    ENDPOINTS.each do |name|
      tool = RecordingMcp.tools.fetch(name)
      assert_equal RecordingStudioUser::McpCopy::ENDPOINTS.fetch(name), tool[:endpoint]
      assert_equal RecordingStudioUser::McpCopy::Copy::TITLES.fetch(name), tool[:title]
      assert_equal RecordingStudioUser::McpCopy::Copy::DESCRIPTIONS.fetch(name), tool[:description]
      assert_equal RecordingStudioUser::McpCopy::Copy::INPUTS.fetch(name), tool[:input]
      assert_equal RecordingStudioUser::McpCopy::Copy::OUTPUTS.fetch(name), tool[:output]
      refute tool.key?(:type)
      refute tool.key?(:operation)
      refute tool.key?(:action)
      FORBIDDEN.each { |phrase| refute_includes tool[:description], phrase }
    end

    OPERATIONS_METRICS.each { |name| refute RecordingMcp.tools.key?(name) }
  ensure
    Object.send(:remove_const, :RecordingStudioMcp) if Object.const_defined?(:RecordingStudioMcp, false)
  end

  def test_tool_names_returns_every_operations_metric
    names = RecordingStudioUser::McpCopy.tool_names(api: :operations)

    assert_equal OPERATIONS_METRICS, names
    assert_equal names, RecordingStudioUser::McpCopy.tool_names
    assert_empty RecordingStudioUser::McpCopy.tool_names(api: :public)
    ENDPOINTS.each { |name| refute_includes names, name }
    names.each { |name| assert_match(/\A[A-Za-z][A-Za-z0-9_.-]*\z/, name) }
  end

  def test_mcp_copy_has_endpoint_wording_and_access
    copy = RecordingStudioUser::McpCopy::Copy

    ENDPOINTS.each do |name|
      title = copy::TITLES.fetch(name)
      description = copy::DESCRIPTIONS.fetch(name)
      output = copy::OUTPUTS.fetch(name)
      assert_kind_of String, title
      refute_empty title, name
      assert_kind_of String, description
      refute_empty description, name
      assert_kind_of String, output
      refute_empty output, name
      FORBIDDEN.each do |phrase|
        refute_includes description, phrase
        refute_includes title, phrase
      end
    end

    OPERATIONS_METRICS.each do |name|
      refute copy::TITLES.key?(name), name
      refute copy::DESCRIPTIONS.key?(name), name
      refute copy::OUTPUTS.key?(name), name
    end

    assert_includes copy::DESCRIPTIONS.fetch("users"), "page, per_page"
    assert_includes copy::DESCRIPTIONS.fetch("users"), "view access to the admin area"
    assert_includes copy::DESCRIPTIONS.fetch("users_create"), "record_profile!"
    assert_includes copy::DESCRIPTIONS.fetch("users_create"), "edit access to the admin area"
    assert_includes copy::DESCRIPTIONS.fetch("users_show"), "view access to the admin area"
    assert_includes copy::DESCRIPTIONS.fetch("users_update"), "record_profile!"
    assert_includes copy::DESCRIPTIONS.fetch("users_update"), "edit access to the admin area"
    registration = File.read(File.expand_path("../lib/recording_studio_user/api/registration.rb", __dir__))
    refute_includes registration, "record_profile!"
    refute_includes registration, "Requires Accessible"
    assert_includes registration, "Requires view access to the admin area"
    assert_includes registration, "Requires edit access to the admin area"
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_user.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_user/engine.rb", __dir__))

    refute_includes gemspec, "recording_studio_mcp"
    refute_includes entry, 'require "recording_studio_mcp"'
    assert_includes engine, 'require_relative "mcp_copy"'
    assert_includes engine, 'initializer "recording_studio_user.mcp", after: "recording_studio_user.api"'
    assert_includes engine, "McpCopy.register!"
  end

  class RecordingMcp
    class << self
      attr_reader :tools

      def reset!
        @tools = {}
      end

      def register_tool(**registration)
        @tools ||= {}
        @tools[registration.fetch(:name)] = registration
      end
    end
  end
end
