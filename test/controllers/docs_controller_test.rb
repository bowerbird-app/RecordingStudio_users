# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class DocsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "DocsTestPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "docs-test@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
      user.first_name = "Docs"
      user.last_name = "Tester"
      user.time_zone = "UTC"
    end

    sign_in @user
  end

  test "install page renders successfully" do
    get docs_install_path
    assert_response :success
    assert_select "h1", text: "Install"
    assert_includes response.body, 'gem "recording_studio_user"'
    assert_includes response.body, "bin/rails generate recording_studio_user:install"
    assert_includes response.body, "recording_studio_users"
    assert_includes response.body, "RecordingStudioAccessible"
    assert_includes response.body,
                    "Rerunning the installer is idempotent while the generated mount declaration remains intact."
    refute_includes response.body, "GemTemplate"
    refute_includes response.body, "Put the step instruction here"
  end

  test "config page renders successfully" do
    get docs_config_path
    assert_response :success
    assert_select "h1", text: "Config"
    assert_includes response.body, "RecordingStudioUser.configure"
    assert_includes response.body, "Pre-route configuration"
    assert_includes response.body, "before the mount declaration"
    assert_includes response.body, "Normal initializer configuration"
    assert_includes response.body, "too late to change an already mounted engine path"
    assert_includes response.body, 'config.mount_path = "/account"'
    assert_includes response.body, "config.additional_profile_attributes"
    assert_includes response.body, "current_user"
    assert_includes response.body, "Devise-compatible Active Record model"
    assert_includes response.body, "UUID primary key"
    assert_includes response.body, "email"
    assert_includes response.body, "timestamps"
    assert_includes response.body, "protected"
    refute_includes response.body, "Replace this placeholder"
  end

  test "recordable types page renders configured recordables dynamically" do
    summary_data = create_recordable_type_summary_data

    get docs_recordable_types_path
    response_text = response.body.gsub(/\s+/, " ").strip

    assert_response :success
    assert_select "h1", text: "Recordable types"
    assert_includes(
      response.body,
      "Diagnostic data from RecordingStudio.recordable_declarations and v3 parent/root introspection."
    )
    assert_includes response.body, "does not make profiles recording-backed"
    assert_includes response.body, "Workspace"
    assert_includes response.body, "Folder"
    assert_includes response.body, "Page"
    assert_includes response_text, "Root recordable"
    assert_includes response_text, "Child recordable"
    assert_includes response_text, "Allowed parents: Workspace, Folder"
    assert_includes response_text, summary_data[:workspace]
    assert_includes response_text, summary_data[:folder]
  end

  test "recordable types page includes dummy app defaults" do
    get docs_recordable_types_path

    assert_response :success
    assert_includes response.body, "Workspace"
    assert_includes response.body, "Folder"
    assert_includes response.body, "Page"
  end

  test "recordings tree page renders successfully" do
    workspace = Workspace.create!(name: "Tree Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.create!(name: "Reference")
    folder_recording = record_child(folder, root_recording, root_recording)
    page = Page.create!(title: "API")
    record_child(page, root_recording, folder_recording)

    get docs_recordings_tree_path

    assert_response :success
    assert_select "h1", text: "Recordings tree"
    assert_includes response.body, "Workspace: Tree Workspace"
    assert_includes response.body, "Folder: Reference"
    assert_includes response.body, "Page: API"
    assert_includes response.body, "does not make profiles recording-backed"
    assert_includes response.body, "includes recordings regardless of trash state"
    refute_includes response.body, "active dummy-app recordings"
    assert_select "div[role='tree']", count: 1
    assert_select "[role='treeitem']", minimum: 3
    refute_includes response.body, "Current structure"
    refute_includes response.body, "This tree is generated from RecordingStudio::Recording records"
  end

  test "gem_views page renders successfully" do
    get docs_gem_views_path
    assert_response :success
    assert_select "h1", text: "Gem Views"
    assert_select "table", minimum: 1
    assert_includes response.body, "app/views/recording_studio_user/profiles/show.html.erb"
    assert_includes response.body, "does not make profiles recording-backed"
  end

  test "methods page renders successfully" do
    get docs_methods_path
    assert_response :success
    assert_select "h1", text: "Routes and integrations"
    assert_includes response.body, "RecordingStudioUser.configure"
    assert_includes response.body, "recording_studio_users.profile_path"
    assert_includes response.body, "widgets.users.total"
    assert_includes response.body, "RecordingStudioAccessible"
    refute_includes response.body, "recordingstudio_addon.example_method"
  end

  test "sidebar includes documentation links" do
    get docs_install_path

    assert_includes response.body, "RecordingStudioUser"
    assert_select %(a[href="#{docs_install_path}"]), text: /Install/
    assert_select %(a[href="#{docs_config_path}"]), text: /Config/
    assert_select %(a[href="#{docs_recordable_types_path}"]), text: /Diagnostics: Recordable types/
    assert_select %(a[href="#{docs_recordings_tree_path}"]), text: /Diagnostics: Recordings tree/
    assert_select %(a[href="#{docs_gem_views_path}"]), text: /Diagnostics: Gem Views/
    assert_select %(a[href="#{docs_methods_path}"]), text: /Routes and integrations/
    assert_select %(a[href="#{recording_studio_users.profile_path}"]), text: /My profile/
    assert_select %(a[href="#{recording_studio_users.admin_path}"]), text: /Admin/
  end

  test "home page describes RecordingStudioUser workflows" do
    get root_path

    assert_response :success
    assert_select "h1", text: "RecordingStudioUser"
    assert_includes response.body, "Each signed-in user manages only their own global profile."
    assert_includes response.body, "access-controlled users reporting"
    assert_includes response.body, "Workspace roots and the Admin root are separate"
    assert_includes response.body, "Diagnostics do not make profiles recording-backed"
    refute_includes response.body, "Template Demo"
    refute_includes response.body, "rename_gem"
  end

  private

  def create_recordable_type_summary_data
    workspace_recordings_before = RecordingStudio::Recording.where(recordable_type: "Workspace").count
    workspaces_before = Workspace.count
    folder_recordings_before = RecordingStudio::Recording.where(recordable_type: "Folder").count
    folders_before = Folder.count

    workspace = Workspace.create!(name: "Counted Workspace")
    2.times do
      RecordingStudio.root_recording_for(Workspace.create!(name: "Counted Workspace #{SecureRandom.hex(4)}"))
    end

    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.create!(name: "Counted Folder")
    record_child(folder, root_recording, root_recording)

    {
      workspace: recordable_type_summary(
        workspace_recordings_before + 3,
        workspaces_before + 3
      ),
      folder: recordable_type_summary(
        folder_recordings_before + 1,
        folders_before + 1
      )
    }
  end

  def recordable_type_summary(recording_count, recordable_count)
    "#{ActionController::Base.helpers.pluralize(recording_count, 'recording')} point to this type " \
      "• #{ActionController::Base.helpers.pluralize(recordable_count, 'recordable')} in the database"
  end

  def record_child(recordable, root_recording, parent_recording)
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording
    ).recording
  end
end
