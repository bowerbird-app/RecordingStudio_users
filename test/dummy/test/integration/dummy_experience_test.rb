# frozen_string_literal: true

require "test_helper"

class DummyExperienceTest < ActionDispatch::IntegrationTest
  test "dummy defines distinct workspace and admin roots" do
    assert_includes RecordingStudio.root_recordable_types, "Workspace"
    assert_includes RecordingStudio.root_recordable_types, "AdminRoot"
    refute_equal Workspace, AdminRoot
  end

  test "sidebar and admin home expose the required navigation" do
    sidebar = Rails.root.join("app/views/layouts/flat_pack/_sidebar.html.erb").read
    admin_section = Rails.root.join("app/admin/dummy_admin.rb").read

    assert_includes sidebar, 'label: "My profile"'
    assert_includes sidebar, "profile_path"
    assert_includes sidebar, "request.path.start_with?"
    assert_includes admin_section, 'text: "Users admin"'
    assert_includes admin_section, 'admin_screen_path("users")'
  end

  test "dummy user is the engine-owned global model" do
    assert_same RecordingStudioUser::User, User
    refute_includes User.column_names, "admin"
    refute User.reflect_on_all_associations.any? { |association| association.name == :recordings }
  end
end
