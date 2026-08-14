# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "workspace home shows only the profile action" do
    user = User.find_or_create_by!(email: "root-switch-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
      record.first_name = "Root"
      record.last_name = "Switch"
      record.time_zone = "UTC"
    end

    sign_in user

    workspace = Workspace.create!(name: "Dropdown Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_access(user, root_recording)

    switch_to(root_recording)

    get "/"

    assert_response :success
    assert_select "h1", text: workspace.name, count: 1
    assert_select "#home-actions" do
      assert_select secondary_button_selector(recording_studio_users.profile_path), text: "My Profile", count: 1
      assert_select %(a[href="#{recording_studio_users.admin_path}"]), text: "Users Admin", count: 0
    end
  end

  test "admin root home shows profile and users admin actions" do
    user = User.find_or_create_by!(email: "root-switch-admin-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
      record.first_name = "Root"
      record.last_name = "Admin"
      record.time_zone = "UTC"
    end

    sign_in user

    admin_root = AdminRoot.create!(name: "Switch Admin")
    root_recording = RecordingStudio.root_recording_for(admin_root)
    grant_access(user, root_recording)

    switch_to(root_recording)

    get "/"

    assert_response :success
    assert_select "h1", text: admin_root.name, count: 1
    assert_select "#home-actions" do
      assert_select secondary_button_selector(recording_studio_users.profile_path), text: "My Profile", count: 1
      assert_select secondary_button_selector(recording_studio_users.admin_path), text: "Users Admin", count: 1
    end
  end

  test "root switch page renders with the host sidebar" do
    user = User.find_or_create_by!(email: "root-switch-page-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
      record.first_name = "Root"
      record.last_name = "Switch"
      record.time_zone = "UTC"
    end

    sign_in user

    workspace = Workspace.create!(name: "Switch Page Workspace")
    RecordingStudio.root_recording_for(workspace)

    get "/recording_studio_root_switchable/v1/root_switch?scope=roots"

    assert_response :success
    assert_includes response.body, "Install"
  end

  test "switching returns to the current page when it is a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-redirect-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
      record.first_name = "Root"
      record.last_name = "Switch"
      record.time_zone = "UTC"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Source Workspace")
    target_workspace = Workspace.create!(name: "Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    source_root_recording = RecordingStudio.root_recording_for(source_workspace)
    grant_access(user, source_root_recording)
    grant_access(user, target_root_recording)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "roots",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/docs/install"
      }
    }

    assert_redirected_to "/docs/install"
  end

  test "switching falls back to home when return_to is not a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-fallback-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
      record.first_name = "Root"
      record.last_name = "Switch"
      record.time_zone = "UTC"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Fallback Source Workspace")
    target_workspace = Workspace.create!(name: "Fallback Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    source_root_recording = RecordingStudio.root_recording_for(source_workspace)
    grant_access(user, source_root_recording)
    grant_access(user, target_root_recording)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "roots",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/not-a-real-route"
      }
    }

    assert_redirected_to "/"
  end

  private

  def grant_access(user, recording, role: :view)
    RecordingStudioAccessible::AccessCreationContext.allow do
      recording.record(RecordingStudio::Access, parent_recording: recording) do |access|
        access.actor = user
        access.role = role
      end
    end
  end

  def switch_to(root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "roots",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: "/"
      }
    }

    assert_redirected_to "/"
  end

  def secondary_button_selector(path)
    %(a[href="#{path}"][class*="--button-secondary-background-color"])
  end
end
