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
    assert_includes response.body, "Total users"
    assert_includes response.body, "Users over time"
    refute_includes response.body, "Role"
  end

  private

  def create_user(email)
    User.create!(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Admin",
      last_name: "User",
      time_zone: "UTC"
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
