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
    assert_response :success
    assert_select "title", text: "User Management | Recording Studio User"
    assert_includes response.body, "User Management"
    assert_includes response.body, "Track account growth, view system metrics, and manage user details."
    assert_includes response.body, "Total users"
    assert_includes response.body, "Users over past 90 days"
    refute_includes response.body, "Users over time"
    assert_select %(main.container.mx-auto.my-28.px-5.flex.flex-col.gap-6), count: 1
    assert_select %(main > div.space-y-8:not(.mt-6)), count: 1
    assert_select %(a[aria-label="Home"][href="/"]), count: 1
    refute_includes response.body, "flat-pack-sidebar"
    refute_includes response.body, "Role"
  end

  test "builds user creation series from an ordered relation" do
    create_user("series-a-#{SecureRandom.hex(4)}@example.com")
    create_user("series-b-#{SecureRandom.hex(4)}@example.com")

    series = RecordingStudioUser::Admin.user_creation_series(User.order(created_at: :desc))

    assert series.all? { |point| point.key?(:x) && point.key?(:y) }
    assert series.all? { |point| point[:x].is_a?(String) }
    assert series.all? { |point| point[:y].is_a?(Integer) }
  end

  test "limits the chart users to the past 90 days" do
    old_user = create_user("old-chart-#{SecureRandom.hex(4)}@example.com", created_at: 91.days.ago)
    recent_user = create_user("recent-chart-#{SecureRandom.hex(4)}@example.com", created_at: 89.days.ago)
    users = User.where(id: [ old_user.id, recent_user.id ])

    chart_users = RecordingStudioUser::Admin::UsersController.new.send(:chart_users, users)

    assert_equal [ recent_user.id ], chart_users.pluck(:id)
  end

  test "paginates the users table" do
    51.times { |index| create_user("pagination-#{index}-#{SecureRandom.hex(4)}@example.com") }
    sign_in @admin
    grant_admin_access(@admin, @admin_recording)

    get recording_studio_users.admin_path

    assert_response :success
    assert_select "nav[aria-label='Pagination']", count: 1
    assert_select "table tbody tr", count: 50
    assert_select "dd", text: User.count.to_s
    assert_select "nav[aria-label='Pagination'] a[href*='page=2']"

    get recording_studio_users.admin_path, params: { page: 2 }

    assert_response :success
    page_two_rows = css_select("table tbody tr").count
    assert_operator page_two_rows, :>, 0
    assert_operator page_two_rows, :<=, 50
    assert_select "nav[aria-label='Pagination'] a[href*='page=1']"
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
