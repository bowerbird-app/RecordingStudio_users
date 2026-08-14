# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminUsersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = create_user("admin-users-#{SecureRandom.hex(4)}@example.com")
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
  end

  test "registers the reusable users section and its metric" do
    assert_equal RecordingStudioUser::Admin::UsersSection, RecordingStudioAdmin.section_for("users")
    assert_equal RecordingStudioUser::Admin::UsersScreen, RecordingStudioAdmin.screen_for("recording_studio_users")
    assert RecordingStudioAdmin.widget_for("widgets.users.total")
  end

  test "rejects an actor without access and permits the site admin" do
    sign_in @admin
    get recording_studio_users.admin_path
    assert_response :forbidden

    grant_admin_access(@admin, @admin_recording)

    get recording_studio_users.admin_path
    assert_redirected_to "/admin/screens/recording_studio_users"

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Users"
    assert_includes response.body, "Total users"
    assert_select "turbo-frame#screen-chart[src*='/admin/screens/recording_studio_users/chart']", count: 1
    assert_select "turbo-frame#screen-table[src*='/admin/screens/recording_studio_users/table']", count: 1

    get "/admin/screens/recording_studio_users/chart"

    assert_response :success
    assert_includes response.body, "Users over time"
  end

  test "requires RecordingStudioAccessible permission for screen data and user details" do
    user = create_user("protected-user-#{SecureRandom.hex(4)}@example.com")
    sign_in @admin

    [
      "/admin/screens/recording_studio_users",
      "/admin/screens/recording_studio_users/chart",
      "/admin/screens/recording_studio_users/table",
      "/admin/screens/recording_studio_users/table_count",
      "/admin/screens/recording_studio_users/widgets/widgets.users.total",
      recording_studio_users.admin_user_path(user)
    ].each do |path|
      get path
      assert_response :forbidden, path
    end

    get recording_studio_users.edit_admin_user_path(user)
    assert_response :forbidden

    patch recording_studio_users.admin_user_path(user), params: { user: { first_name: "Denied" } }
    assert_response :forbidden
  end

  test "permits viewers to view users but not edit them" do
    user = create_user("viewer-target-#{SecureRandom.hex(4)}@example.com")
    viewer = create_user("viewer-#{SecureRandom.hex(4)}@example.com")
    sign_in viewer
    grant_admin_access(viewer, @admin_recording, role: :view)

    get "/admin/screens/recording_studio_users/table"

    assert_response :success
    assert_includes response.body, "View user"
    refute_includes response.body, "Edit user"

    get recording_studio_users.admin_user_path(user)
    assert_response :success

    get recording_studio_users.edit_admin_user_path(user)
    assert_response :forbidden

    patch recording_studio_users.admin_user_path(user), params: { user: { first_name: "Denied" } }
    assert_response :forbidden
    assert_equal "Admin", user.reload.first_name
  end

  test "renders mounted user links from the shared admin sidebar layout" do
    admin_surface = RecordingStudioAdmin.configuration.surface(:admin)
    original_layout = admin_surface.engine_layout
    admin_surface.engine_layout = "flat_pack_sidebar"
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    get "/admin/screens/recording_studio_users"

    assert_response :success
    assert_select %(a[href="/recording_studio_users/profile"]), count: 1
    assert_select %(a[href="/recording_studio_users/admin"]), count: 1
  ensure
    admin_surface.engine_layout = original_layout
  end

  test "builds user creation series from an ordered relation" do
    create_user("series-a-#{SecureRandom.hex(4)}@example.com")
    create_user("series-b-#{SecureRandom.hex(4)}@example.com")

    series = RecordingStudioUser::Admin.user_creation_series(User.order(created_at: :desc))

    assert series.all? { |point| point.key?(:x) && point.key?(:y) }
    assert series.all? { |point| point[:x].is_a?(String) }
    assert series.all? { |point| point[:y].is_a?(Integer) }
  end

  test "renders a view action and user details for the site admin" do
    user = create_user("view-user-#{SecureRandom.hex(4)}@example.com")
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    get "/admin/screens/recording_studio_users/table"

    assert_response :success
    assert_select %(button[aria-label="Actions for #{user.email}"]), count: 1
    assert_includes response.body, "View user"
    assert_includes response.body, "Edit user"

    get recording_studio_users.admin_user_path(user)

    assert_response :success
    assert_includes response.body, user.email
    assert_includes response.body, "User account details"

    get recording_studio_users.edit_admin_user_path(user)

    assert_response :success
    assert_includes response.body, "Update user"

    patch recording_studio_users.admin_user_path(user), params: {
      user: { first_name: "Updated", last_name: "User", time_zone: "Eastern Time (US & Canada)", email: "ignored@example.com" }
    }

    assert_redirected_to recording_studio_users.admin_user_path(user)
    user.reload
    assert_equal "Updated", user.first_name
    assert_equal "User", user.last_name
    assert_equal "Eastern Time (US & Canada)", user.time_zone
    refute_equal "ignored@example.com", user.email
  end

  test "re-renders the edit form when an admin submits invalid profile details" do
    user = create_user("invalid-edit-#{SecureRandom.hex(4)}@example.com")
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    patch recording_studio_users.admin_user_path(user), params: {
      user: { first_name: "Updated", last_name: "User", time_zone: "Invalid/Zone" }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "prevented this user from being saved"
    assert_equal "Admin", user.reload.first_name
    assert_equal "UTC", user.time_zone
  end

  test "paginates the users table" do
    51.times { |index| create_user("pagination-#{index}-#{SecureRandom.hex(4)}@example.com") }
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    get "/admin/screens/recording_studio_users/table"

    assert_response :success
    assert_select "table tbody tr", count: 50

    get "/admin/screens/recording_studio_users/table", params: { page: 2 }

    assert_response :success
    page_two_rows = css_select("table tbody tr").count
    assert_operator page_two_rows, :>, 0
    assert_operator page_two_rows, :<=, 50
  end

  private

  def create_user(email, created_at: nil)
    User.create!(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Admin",
      last_name: "User",
      time_zone: "UTC",
      created_at: created_at,
      updated_at: created_at
    )
  end

  def grant_admin_access(user, recording, role: :admin)
    RecordingStudioAccessible::AccessCreationContext.allow do
      recording.record(RecordingStudio::Access, parent_recording: recording) do |access|
        access.actor = user
        access.role = role
      end
    end
  end
end
