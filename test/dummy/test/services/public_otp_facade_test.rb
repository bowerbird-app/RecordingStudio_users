# frozen_string_literal: true

require "test_helper"

class PublicOtpFacadeTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
  end

  test "request_otp result exposes challenge_id without dropping challenge" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("issued"))
    session = {}

    issued = request_registration!(user, session: session)

    assert issued.issued?
    assert_equal issued.challenge.id, issued.challenge_id
    assert_equal issued.challenge_id, session[:otp_challenge_id]
  end

  test "otp_proof returns purpose and hides secrets" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("proof"))
    issued = request_registration!(user)

    proof = RecordingStudioUser.otp_proof(issued.challenge_id)

    assert_equal "registration", proof.purpose
    refute proof.respond_to?(:code_digest)
    refute proof.respond_to?(:delivery_code_ciphertext)
    refute_includes proof.to_h.stringify_keys.keys, "code_digest"
  end

  test "otp_proof is nil when the challenge is missing consumed or revoked" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("unusable"))
    issued = request_registration!(user)
    session = { otp_challenge_id: issued.challenge_id, otp_purpose: "registration" }
    code = otp_code(issued.challenge_id)

    assert_nil RecordingStudioUser.otp_proof(SecureRandom.uuid)

    RecordingStudioUser.verify_otp!(
      challenge_id: issued.challenge_id,
      code: code,
      purpose: "registration",
      session: session
    )
    assert_nil RecordingStudioUser.otp_proof(issued.challenge_id)

    later = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("revoked"))
    revoked = request_registration!(later)
    revoked.challenge.revoke!
    assert_nil RecordingStudioUser.otp_proof(revoked.challenge_id)
  end

  test "otp_message returns the code body for a live challenge" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("message"))
    issued = request_registration!(user)
    message = RecordingStudioUser.otp_message(issued.challenge_id)

    assert_match(/\d{6}/, message.fetch(:body))
    refute_includes message.fetch(:body), issued.challenge.code_digest
    assert_nil RecordingStudioUser.otp_message(SecureRandom.uuid)
  end

  test "resend_otp issues a new challenge and rate-limits a second resend" do
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("resend"))
    session = {}
    first = request_registration!(user, session: session)

    resent = RecordingStudioUser.resend_otp!(user: user, purpose: :registration, session: session)

    refute_equal first.challenge_id, resent.challenge_id
    assert_equal resent.challenge.id, resent.challenge_id
    assert resent.issued?
    assert_equal "registration", RecordingStudioUser.otp_proof(resent.challenge_id).purpose
    assert_nil RecordingStudioUser.otp_proof(first.challenge_id)

    digest = RecordingStudioUser::Services::OtpRateLimiter.email_key(user.email)
    assert_equal 1, Rails.cache.read("recording_studio_user:otp:rl:resend:#{digest}")
    assert_nil Rails.cache.read("recording_studio_user:otp:rl:resend:#{user.email}")

    again = RecordingStudioUser.resend_otp!(user: user, purpose: :registration, session: session)
    assert again.throttled?
    assert_nil again.challenge
  ensure
    Rails.cache = previous_cache
  end

  test "complete_email_proof confirms a new otp user and stores the submitted name" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("ada"))
    result = verify_registration!(user)

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: result.challenge.id,
      profile_attributes: { first_name: "Ada", last_name: "Lovelace" }
    )

    user.reload
    assert user.confirmed?
    assert_equal "otp", user.registered_with
    profile = RecordingStudioUser.profile_for(user)
    assert_equal "Ada", profile.first_name
    assert_equal "Lovelace", profile.last_name
    assert_nil profile.time_zone
  end

  test "complete_email_proof stores a one-word name without a surname or time zone" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("madonna"))
    result = verify_registration!(user)

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: result.challenge.id,
      profile_attributes: { first_name: "Madonna", last_name: nil }
    )

    profile = RecordingStudioUser.profile_for(user.reload)
    assert_equal "Madonna", profile.first_name
    assert_nil profile.last_name
    assert_nil profile.time_zone
    assert_equal "Madonna", RecordingStudioUser.display_name_for(user)
  end

  test "complete_email_proof confirms an unconfirmed password user without changing the password" do
    user = User.create!(
      email: unique_email("password"),
      password: "Password123!",
      password_confirmation: "Password123!",
      registered_with: "password"
    )
    user.update_column(:confirmed_at, nil)
    RecordingStudioUser.record_profile!(
      user,
      actor: user,
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "Eastern Time (US & Canada)"
    )
    result = verify_registration!(user)

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: result.challenge.id,
      profile_attributes: { first_name: "Someone", last_name: "Else" }
    )

    user.reload
    assert user.confirmed?
    assert_equal "password", user.registered_with
    assert user.valid_password?("Password123!")
    profile = RecordingStudioUser.profile_for(user)
    assert_equal "Casey", profile.first_name
    assert_equal "Patron", profile.last_name
    assert_equal "Eastern Time (US & Canada)", profile.time_zone
  end

  test "complete_email_proof leaves a confirmed login account profile alone" do
    user = User.create!(
      email: unique_email("login"),
      password: "Password123!",
      password_confirmation: "Password123!",
      registered_with: "password",
      confirmed_at: Time.current
    )
    RecordingStudioUser.record_profile!(
      user,
      actor: user,
      first_name: "Casey",
      last_name: "Patron",
      time_zone: "UTC"
    )
    session = {}
    issued = RecordingStudioUser.request_otp!(
      email: user.email,
      purpose: :login,
      request: nil,
      session: session
    )
    result = RecordingStudioUser.verify_otp!(
      challenge_id: issued.challenge_id,
      code: otp_code(issued.challenge_id),
      purpose: "login",
      session: session
    )
    assert result.success?

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: issued.challenge_id,
      profile_attributes: { first_name: "Someone", last_name: "Else" }
    )

    user.reload
    assert user.confirmed?
    profile = RecordingStudioUser.profile_for(user)
    assert_equal "Casey", profile.first_name
    assert_equal "Patron", profile.last_name
  end

  test "complete_email_proof raises when the challenge was not verified" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("unverified"))
    issued = request_registration!(user)

    assert_raises(ArgumentError) do
      RecordingStudioUser.complete_email_proof!(
        user: user,
        challenge_id: issued.challenge_id,
        profile_attributes: { first_name: "Ada", last_name: "Lovelace" }
      )
    end
    refute user.reload.confirmed?
    assert_nil RecordingStudioUser.profile_for(user)
  end

  test "verify_otp still reports success and user" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("verify"))
    result = verify_registration!(user)

    assert result.success?
    assert_equal user.id, result.user.id
  end

  test "create_unconfirmed_user still leaves an otp account unconfirmed" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("unconfirmed"))

    assert user.registered_with_otp?
    refute user.confirmed?
    assert_nil RecordingStudioUser.profile_for(user)
  end

  private

  def unique_email(label)
    "#{label}-#{SecureRandom.hex(4)}@example.com"
  end

  def otp_code(challenge_id)
    RecordingStudioUser.otp_message(challenge_id).fetch(:body)[/\d{6}/]
  end

  def request_registration!(user, session: nil)
    RecordingStudioUser.request_otp!(
      email: user.email,
      purpose: :registration,
      request: nil,
      session: session
    )
  end

  def verify_registration!(user)
    session = {}
    issued = RecordingStudioUser::Services::IssueOtp.call(
      user: user,
      purpose: :registration,
      session: session,
      checked_keys: []
    )
    RecordingStudioUser.verify_otp!(
      challenge_id: issued.challenge_id,
      code: otp_code(issued.challenge_id),
      purpose: "registration",
      session: session
    )
  end
end
