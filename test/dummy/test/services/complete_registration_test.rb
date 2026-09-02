# frozen_string_literal: true

require "test_helper"

class CompleteRegistrationTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
  end

  test "create_unconfirmed_user leaves OTP user unconfirmed" do
    email = "service-unconfirmed-#{SecureRandom.hex(4)}@example.com"

    user = RecordingStudioUser.create_unconfirmed_user!(email: email)

    assert user.registered_with_otp?
    refute user.confirmed?
    assert_nil user.confirmed_at
    assert_nil RecordingStudioUser.profile_for(user)
  end

  test "complete_registration confirms OTP user and creates profile" do
    email = "service-confirmed-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_unconfirmed_user!(email: email)
    challenge = RecordingStudioUser.issue_otp!(user: user, purpose: :registration).challenge
    code = challenge.decrypt_delivery_code!
    result = RecordingStudioUser.verify_otp!(
      challenge_id: challenge.id,
      code: code,
      purpose: "registration",
      session: { otp_challenge_id: challenge.id, otp_purpose: "registration" }
    )

    RecordingStudioUser.complete_registration!(user: result.user, challenge: result.challenge)

    user.reload
    assert user.confirmed?
    assert_not_nil user.confirmed_at
    assert RecordingStudioUser.profile_for(user)
    assert user.active_for_authentication?
  end
end
