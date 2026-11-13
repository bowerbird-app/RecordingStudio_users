# frozen_string_literal: true

require "test_helper"

class PasswordLengthTest < ActionDispatch::IntegrationTest
  setup do
    @original_minimum = RecordingStudioUser.config.minimum_password_length
    @original_devise = Devise.password_length.dup
  end

  teardown do
    RecordingStudioUser.config.minimum_password_length = @original_minimum
    Devise.password_length = @original_devise
  end

  test "profiled user rejects passwords shorter than the gem minimum" do
    Devise.password_length = 6..128
    user = new_user("elevenchars")

    refute_predicate user, :valid?
    assert user.errors.added?(:password, :too_short, count: 12)
    assert_equal 1, user.errors.where(:password, :too_short).size

    user.password = "twelvechars!"
    user.password_confirmation = "twelvechars!"
    assert_predicate user, :valid?
  end

  test "minimum length follows the gem setting" do
    Devise.password_length = 6..128
    RecordingStudioUser.config.minimum_password_length = 16
    user = new_user("twelvechars!")

    refute_predicate user, :valid?
    assert user.errors.added?(:password, :too_short, count: 16)

    user.password = "sixteen-chars-ok"
    user.password_confirmation = "sixteen-chars-ok"
    assert_predicate user, :valid?
  end

  test "reset form shows the gem minimum" do
    get edit_user_password_path(reset_password_token: "reset-token")

    assert_response :success
    assert_includes response.body, "12 characters minimum"
  end

  private

  def new_user(password)
    User.new(
      email: "length-#{SecureRandom.hex(4)}@example.com",
      password: password,
      password_confirmation: password
    )
  end
end
