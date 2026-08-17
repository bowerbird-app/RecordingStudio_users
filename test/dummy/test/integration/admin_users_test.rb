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
    assert_equal :site, RecordingStudioUser::Admin::UsersScreen.blast_radius
    assert_equal :site, RecordingStudioUser::Admin::UsersSection.blast_radius
  end

  test "section and widget links use the mounted admin helper" do
    assert_equal "/recording_studio_users/admin", RecordingStudioUser.mounted_admin_path
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

  test "requires RecordingStudioAccessible permission for screen data" do
    sign_in @admin

    [
      "/admin/screens/recording_studio_users",
      "/admin/screens/recording_studio_users/chart",
      "/admin/screens/recording_studio_users/table",
      "/admin/screens/recording_studio_users/table_count",
      "/admin/screens/recording_studio_users/widgets/widgets.users.total"
    ].each do |path|
      get path
      assert_response :forbidden, path
    end
  end

  test "renders the read-only users table for an authorized actor" do
    user = create_user("view-user-#{SecureRandom.hex(4)}@example.com")
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    get "/admin/screens/recording_studio_users/table"

    assert_response :success
    assert_includes response.body, user.email
    assert_includes response.body, "Name"
    assert_includes response.body, "Email"
    assert_includes response.body, "Time zone"
    assert_includes response.body, "Created at"
    refute_includes response.body, "Edit user"
    refute_includes response.body, "Admin status"
    refute_includes response.body, "Role"
  end

  test "renders mounted profile links from the shared admin sidebar layout" do
    admin_surface = RecordingStudioAdmin.configuration.surface(:admin)
    original_layout = admin_surface.engine_layout
    admin_surface.engine_layout = "flat_pack_sidebar"
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    get "/admin/screens/recording_studio_users"

    assert_response :success
    assert_select %(a[href="/recording_studio_users/profile"]), count: 1
    assert_select %(a[href="/recording_studio_users/admin"]), count: 0
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

  test "the gem does not add an outer card around the admin screen" do
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    get recording_studio_users.admin_path
    follow_redirect!

    refute_includes File.read(RecordingStudioUser::Engine.root.join("lib/recording_studio_user/admin.rb")),
                    "FlatPack::Card::Component"
    refute_includes File.read(RecordingStudioUser::Engine.root.join("app/controllers/recording_studio_user/admin/users_controller.rb")),
                    "FlatPack::Card::Component"
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
