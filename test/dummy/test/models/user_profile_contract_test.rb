# frozen_string_literal: true

require "test_helper"

class UserProfileContractTest < ActiveSupport::TestCase
  test "the host user is a Devise actor without profile columns or recordable status" do
    refute User.column_names.include?("first_name")
    refute User.column_names.include?("last_name")
    refute User.column_names.include?("time_zone")
    refute User.column_names.include?("additional_profile_attributes")
    refute User.column_names.include?("admin")
    refute User.column_names.include?("role")
    refute defined?(RecordingStudioUser::User)
    assert User < RecordingStudioUser::ProfiledUser
    assert_equal "User", RecordingStudioUser.config.user_class_name
    assert_equal User, RecordingStudioUser.config.user_class
    refute_includes RecordingStudio.configuration.recordable_types.map(&:to_s), "User"
    refute RecordingStudio.recordable_declaration_defined?(User)
    refute RecordingStudio.root_allowed?(User)
    refute RecordingStudio.shared_root_type?(User)
  end

  test "the original Devise users migration never added profile columns" do
    devise_migration = File.read(Rails.root.join("db/migrate/20260217072923_devise_create_users.rb"))

    refute_includes devise_migration, "first_name"
    refute_includes devise_migration, "last_name"
    refute_includes devise_migration, "time_zone"
    refute_includes devise_migration, "additional_profile_attributes"
    refute File.exist?(Rails.root.join("db/migrate/20260813000000_add_profile_fields_to_users.rb"))
  end

  test "display_name reads the current Profile snapshot" do
    user = RecordingStudioUser.create_user!(
      email: "ada-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Ada",
      last_name: "Lovelace",
      time_zone: "UTC"
    )

    assert_equal "Ada Lovelace", user.display_name
    assert_equal "Ada Lovelace", RecordingStudioUser.display_name_for(user)
  end

  test "display_name falls back to email when no profile exists" do
    user = User.create!(
      email: "legacy-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    assert_equal user.email, RecordingStudioUser.display_name_for(user)
  end
end
