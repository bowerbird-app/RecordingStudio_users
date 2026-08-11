# frozen_string_literal: true

require "test_helper"

class RecordingStudioUser::UserTest < ActiveSupport::TestCase
  test "requires profile fields and a valid Rails time zone" do
    user = RecordingStudioUser::User.new(email: "person@example.com", password: "Password123!")

    refute user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
    assert_includes user.errors[:last_name], "can't be blank"
    assert_includes user.errors[:time_zone], "can't be blank"

    user.assign_attributes(first_name: "Taylor", last_name: "Person", time_zone: "Not/AZone")
    refute user.valid?
    assert_includes user.errors[:time_zone], "is not a valid Rails time zone"

    user.time_zone = "Eastern Time (US & Canada)"
    assert user.valid?
  end

  test "provides full and fallback display names" do
    user = RecordingStudioUser::User.new(
      first_name: "Taylor",
      last_name: "Person",
      email: "person@example.com"
    )
    assert_equal "Taylor Person", user.full_name
    assert_equal "Taylor Person", user.display_name

    user.first_name = nil
    user.last_name = nil
    assert_equal "person@example.com", user.display_name
  end

  test "uses only the supported first-release Devise modules" do
    assert_equal(
      %i[database_authenticatable recoverable rememberable validatable].sort,
      RecordingStudioUser::User.devise_modules.sort
    )
  end

  test "schema has no site administration field" do
    columns = RecordingStudioUser::User.column_names

    refute_includes columns, "admin"
    refute_includes columns, "role"
    refute_includes columns, "recording_id"
    refute_includes columns, "root_recording_id"
  end
end
