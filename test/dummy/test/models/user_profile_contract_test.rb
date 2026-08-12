# frozen_string_literal: true

require "test_helper"

class UserProfileContractTest < ActiveSupport::TestCase
  test "the host user has profile fields and does not have an admin role field" do
    assert User.column_names.include?("first_name")
    assert User.column_names.include?("last_name")
    assert User.column_names.include?("time_zone")
    refute User.column_names.include?("admin")
    refute User.column_names.include?("role")
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
