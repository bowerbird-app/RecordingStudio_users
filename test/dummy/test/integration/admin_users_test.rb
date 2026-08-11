# frozen_string_literal: true

require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Avery",
      last_name: "Admin",
      email: "admin@example.com",
      time_zone: "UTC",
      password: "Password123!"
    )
    @member = User.create!(
      first_name: "Morgan",
      last_name: "Member",
      email: "member@example.com",
      time_zone: "UTC",
      password: "Password123!"
    )
    @admin_root = AdminRoot.create!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    grant_admin_access
  end

  test "member without access cannot reach sitewide user reporting" do
    sign_in @member

    get "/admin/screens/users"

    refute_equal 200, response.status
  end

  test "actor with admin-root access sees users table and chart" do
    sign_in @admin

    get "/admin/screens/users"

    assert_response :success
    refute_includes response.body, "Administrator status"

    get "/admin/screens/users/chart"
    assert_response :success
    assert_includes response.body, "Total users"

    get "/admin/screens/users/table"
    assert_response :success
    assert_includes response.body, "Time zone"
    assert_includes response.body, @member.email
  end

  test "users section is enabled only by the host-owned admin root" do
    context = RecordingStudioAdmin::Context.new(
      current_actor: @admin,
      controller: Struct.new(:current_user).new(@admin),
      surface: RecordingStudioAdmin.configuration.surface_for(:admin)
    )

    assert_includes AdminRoot.recording_studio_admin_section_keys_for(@admin_root, @admin_recording, context), "users"
    assert_nil RecordingStudioUser::Admin::UsersSection.recordable_definition
  end

  private

  def grant_admin_access
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(recording:, **) { recording.present? }

    result = RecordingStudioAccessible.grant_access(
      recording: @admin_recording,
      actor: @admin,
      role: :admin,
      manager_actor: @admin
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
