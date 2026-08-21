# frozen_string_literal: true

require "test_helper"

class UserProfileContractTest < ActiveSupport::TestCase
  test "the host user has profile fields and does not have an admin role field" do
    assert User.column_names.include?("first_name")
    assert User.column_names.include?("last_name")
    assert User.column_names.include?("time_zone")
    refute User.column_names.include?("admin")
    refute User.column_names.include?("role")
    refute defined?(RecordingStudioUser::User)
    assert User < RecordingStudioUser::ProfiledUser
    assert_equal "User", RecordingStudioUser.config.user_class_name
    assert_equal User, RecordingStudioUser.config.user_class
  end

  test "the original Devise users migration is preserved and profile fields are additive" do
    devise_migration = File.read(Rails.root.join("db/migrate/20260217072923_devise_create_users.rb"))
    profile_migration = File.read(Rails.root.join("db/migrate/20260813000000_add_profile_fields_to_users.rb"))

    refute_includes devise_migration, "first_name"
    refute_includes devise_migration, "last_name"
    refute_includes devise_migration, "time_zone"
    assert_includes profile_migration, "add_column :users, :first_name"
    assert_includes profile_migration, "add_column :users, :last_name"
    assert_includes profile_migration, "add_column :users, :time_zone"
  end

  test "display_name falls back through name and email" do
    user = User.new(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
    assert_equal "Ada Lovelace", user.display_name

    incomplete = User.new(first_name: "", last_name: "", email: "legacy@example.com")
    assert_equal "legacy@example.com", RecordingStudioUser.display_name_for(incomplete)
  end

  test "profile fields require a valid Rails time zone" do
    user = User.new(
      email: "invalid-zone@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Invalid",
      last_name: "Zone",
      time_zone: "Not/AZone"
    )

    refute user.valid?
    assert_includes user.errors[:time_zone], "is not included in the list"
  end
end
