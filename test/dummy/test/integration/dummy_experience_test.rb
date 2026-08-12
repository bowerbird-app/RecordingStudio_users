# frozen_string_literal: true

require "test_helper"

class DummyExperienceTest < ActionDispatch::IntegrationTest
  test "dummy defines distinct workspace and admin roots" do
    assert_includes RecordingStudio.root_recordable_types, "Workspace"
    assert_includes RecordingStudio.root_recordable_types, "AdminRoot"
    refute_equal Workspace, AdminRoot
  end

  test "dummy user is the engine-owned global model" do
    assert_same RecordingStudioUser::User, User
    refute_includes User.column_names, "admin"
    refute User.reflect_on_all_associations.any? { |association| association.name == :recordings }
  end

  test "seeding outside development requires explicit passwords" do
    original_admin_password = ENV.delete("DUMMY_ADMIN_PASSWORD")
    original_user_password = ENV.delete("DUMMY_USER_PASSWORD")

    assert_raises(KeyError) { load Rails.root.join("db/seeds.rb") }
  ensure
    ENV["DUMMY_ADMIN_PASSWORD"] = original_admin_password if original_admin_password
    ENV["DUMMY_USER_PASSWORD"] = original_user_password if original_user_password
  end
end
