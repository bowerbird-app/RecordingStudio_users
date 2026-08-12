# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "home page renders the root switch dropdown trigger" do
    user = User.find_or_create_by!(email: "root-switch-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
      record.first_name = "Root"
      record.last_name = "Switch"
      record.time_zone = "UTC"
    end

    sign_in user

    workspace = Workspace.create!(name: "Dropdown Workspace")
    grant_view_access(user, RecordingStudio.root_recording_for(workspace))

    get root_path

    assert_response :success
    assert_includes response.body, workspace.name
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
    RecordingStudio.root_recording_for(source_workspace)

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
    RecordingStudio.root_recording_for(source_workspace)

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

  def grant_view_access(user, recording)
    RecordingStudioAccessible::AccessCreationContext.allow do
      recording.record(RecordingStudio::Access, parent_recording: recording) do |access|
        access.actor = user
        access.role = :view
      end
    end
  end
end
