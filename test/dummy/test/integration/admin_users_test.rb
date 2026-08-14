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

  def grant_admin_access(user, recording)
    RecordingStudioAccessible::AccessCreationContext.allow do
      recording.record(RecordingStudio::Access, parent_recording: recording) do |access|
        access.actor = user
        access.role = :admin
      end
    end
  end
end
