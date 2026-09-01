# frozen_string_literal: true

require "test_helper"

class OtpChallengeTest < ActiveSupport::TestCase
  setup do
    @user = User.new(
      email: "otp-test-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      authentication_method: "otp"
    )
    @user.skip_confirmation_notification! if @user.respond_to?(:skip_confirmation_notification!)
    @user.save!(validate: false)
  end

  test "generates six digit codes with leading zeros" do
    codes = 50.times.map { RecordingStudioUser::OtpChallenge.generate_code }
    assert codes.all? { |code| code.match?(/\A\d{6}\z/) }
  end

  test "digest verifies correct code and rejects incorrect code" do
    code = "042815"
    challenge = RecordingStudioUser::OtpChallenge.issue_for!(user: @user, purpose: "registration", code: code)
    assert challenge.verify_code!(code)
    refute challenge.verify_code!("000000")
  end

  test "consume clears delivery ciphertext" do
    challenge = RecordingStudioUser::OtpChallenge.issue_for!(user: @user, purpose: "registration", code: "123456")
    assert challenge.delivery_code_ciphertext.present?
    challenge.consume!
    assert_nil challenge.reload.delivery_code_ciphertext
  end

  test "revoke invalidates active challenge" do
    challenge = RecordingStudioUser::OtpChallenge.issue_for!(user: @user, purpose: "registration", code: "123456")
    challenge.revoke!
    refute challenge.active?
    refute challenge.deliverable?
  end

  test "consumed challenge is not deliverable" do
    challenge = RecordingStudioUser::OtpChallenge.issue_for!(user: @user, purpose: "registration", code: "123456")
    challenge.consume!
    refute challenge.deliverable?
  end
end
