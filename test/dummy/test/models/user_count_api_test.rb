# frozen_string_literal: true

require "test_helper"

class UserCountApiTest < ActiveSupport::TestCase
  test "user_count uses the configured user class count" do
    before = RecordingStudioUser.config.user_class.count
    assert_equal User.count, before
    assert_equal({ count: before }, RecordingStudioUser::Api::UserCount.call(nil))

    User.create!(
      email: "user-count-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      registered_with: "password"
    )

    after = RecordingStudioUser.config.user_class.count
    assert_equal before + 1, after
    assert_equal({ count: after }, RecordingStudioUser::Api::UserCount.call(nil))
  end
end
