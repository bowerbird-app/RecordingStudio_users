# frozen_string_literal: true

require "test_helper"

class UsersMcpMetricsTest < ActiveSupport::TestCase
  WINDOW_ARGUMENTS = %w[end end_at from interval start start_at to].freeze
  PLAIN_METRICS = %w[users-by_method users-confirmation users-total].freeze
  SERIES_METRICS = %w[users-signups users-total_over_time].freeze

  setup do
    @staff = RecordingStudioUser.create_user!(
      email: "mcp-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Mcp",
      last_name: "Staff",
      time_zone: "UTC"
    )
    Current.actor = @staff
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    @other_admin = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Other admin"))
    grant!(@admin_root, @staff, :admin)
    grant!(@other_admin, @staff, :admin)
    Dummy::SignupTerms.ensure_live!(actor: @staff)
    @viewer_grant = operations_grant(access_point: @admin_root, role: :view, name: "Users metrics viewer")
    @denied_grant = operations_grant(access_point: @other_admin, role: :view, name: "Users metrics other admin")
  end

  teardown do
    Current.actor = nil
  end

  test "oauth migrations stay off the dummy migrate path" do
    paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
    oauth_migrate = RecordingStudioOauth::Engine.root.join("db/migrate").cleanpath
    refute paths.any? { |path| Pathname.new(path).cleanpath == oauth_migrate }

    versions = paths.flat_map { |path| Dir[File.join(path, "*.rb")] }.map { |file| File.basename(file)[/\A\d+/] }
    assert_empty versions.tally.select { |_version, count| count > 1 }
  end

  test "operations viewer sees one tool per users metric" do
    surface = RecordingStudioMcp::ToolSurface.for(access_grant: @viewer_grant)

    (PLAIN_METRICS + SERIES_METRICS).each do |name|
      assert_includes surface.tool_names, name
      assert_equal true, surface.read_only_tool?(name)
    end

    PLAIN_METRICS.each do |name|
      assert_equal [], argument_names(surface, name)
    end

    SERIES_METRICS.each do |name|
      assert_equal WINDOW_ARGUMENTS, argument_names(surface, name)
      assert_equal %w[day week month year], argument(surface, name, :interval).fetch(:enum)
    end

    (PLAIN_METRICS + SERIES_METRICS).each do |name|
      properties = argument_names(surface, name)
      refute_includes properties, "group_by"
      refute_includes properties, "filters"
    end
  end

  test "users total runs through api authorize" do
    RecordingStudioUser.create_user!(
      email: "mcp-counted-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Counted",
      last_name: "Person",
      time_zone: "UTC"
    )
    hidden = RecordingStudioMcp::ToolSurface.for(access_grant: @denied_grant)
    refute_includes hidden.tool_names, "users-total"

    result = RecordingStudioMcp::Dispatcher.call(
      tool_name: "users-total",
      arguments: {},
      access_grant: @viewer_grant
    )
    assert_equal false, result.fetch(:isError)
    assert_equal "users.total", result.dig(:structuredContent, "metric")
    assert_equal User.count, result.dig(:structuredContent, "value")

    tool = RecordingStudioMcp::CatalogMetricTools.collect(
      RecordingStudioMcp::Catalog.new(api: "operations"),
      @viewer_grant
    ).find { |candidate| candidate.name.to_s == "users-total" }
    error = assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMcp::CatalogMetricTools.execute(tool, {}, @denied_grant)
    end
    assert_equal "Not authorized to run this metric", error.message

    grouped = RecordingStudioMcp::Dispatcher.call(
      tool_name: "users-signups",
      arguments: { "group_by" => "registered_with" },
      access_grant: @viewer_grant
    )
    filtered = RecordingStudioMcp::Dispatcher.call(
      tool_name: "users-total",
      arguments: { "filters" => {} },
      access_grant: @viewer_grant
    )
    assert_equal "Unknown argument group_by", grouped.dig(:content, 0, :text)
    assert_equal "Unknown argument filters", filtered.dig(:content, 0, :text)
  end

  private

  def argument_names(surface, name)
    argument_properties(surface, name).keys.map(&:to_s).sort
  end

  def argument(surface, name, key)
    argument_properties(surface, name).fetch(key)
  end

  def argument_properties(surface, name)
    surface.tool_definitions.find { |tool| tool.fetch(:name) == name }.dig(:inputSchema, :properties)
  end

  def operations_grant(access_point:, role:, name:)
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: @staff,
      role: role,
      name: "#{name} #{SecureRandom.hex(4)}",
      api: :operations
    )
    raise result.error unless result.success?

    payload = result.value
    RecordingStudioApi::AccessGrant.new(
      api_client: payload.fetch(:api_client),
      credential: payload.fetch(:credential),
      access_recording: payload.fetch(:access_recording),
      root_recording: payload.fetch(:access_recording).root_recording
    )
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end

  def grant!(recording, actor, role)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)

    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: actor
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
