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
    challenge = RecordingStudioUser.request_otp!(
      email: user.email,
      purpose: :registration,
      request: nil,
      session: nil
    ).challenge
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

  test "otp registration emits a signup source once and the next registration in that session gets none" do
    session = {}
    RecordingStudioUser.remember_signup_source!(
      request: Struct.new(:session).new(session),
      source: { kind: "press_contact", recording_id: 11, early: false }
    )
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(
      RecordingStudioUser::RegistrationCompleted::EVENT
    ) do |_name, _start, _finish, _id, payload|
      events << payload
    end

    first = register_otp_user!("source-once")
    RecordingStudioUser.complete_registration!(user: first.user, challenge: first.challenge, session: session)

    assert_equal({ kind: "press_contact", recording_id: 11, early: false }, events.last[:source])
    assert_nil session[RecordingStudioUser::SignupSource::SESSION_KEY]
    refute_includes first.user.reload.attributes.keys, "signup_source"
    refute_includes first.challenge.reload.attributes.keys, "signup_source"

    second = register_otp_user!("source-none")
    RecordingStudioUser.complete_registration!(user: second.user, challenge: second.challenge, session: session)

    refute events.last.key?(:source)
    assert_equal second.user.id, events.last[:user_id]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "a failed registration event leaves the signup source in the session" do
    session = {}
    RecordingStudioUser.remember_signup_source!(
      request: Struct.new(:session).new(session),
      source: { recording_id: 0 }
    )
    registered = register_otp_user!("source-kept")
    original_emit = RecordingStudioUser::RegistrationCompleted.method(:emit!)

    assert_raises(ArgumentError) do
      begin
        RecordingStudioUser::RegistrationCompleted.define_singleton_method(:emit!) { |**| raise ArgumentError, "emit failed" }
        RecordingStudioUser.complete_registration!(
          user: registered.user, challenge: registered.challenge, session: session
        )
      ensure
        RecordingStudioUser::RegistrationCompleted.define_singleton_method(:emit!, original_emit)
      end
    end

    assert_equal({ recording_id: 0 }, RecordingStudioUser::SignupSource.read(session))
  end

  private

  def register_otp_user!(label)
    email = "#{label}-#{SecureRandom.hex(4)}@example.com"
    user = RecordingStudioUser.create_unconfirmed_user!(email: email)
    challenge = RecordingStudioUser.request_otp!(
      email: user.email,
      purpose: :registration,
      request: nil,
      session: nil
    ).challenge
    code = challenge.decrypt_delivery_code!
    result = RecordingStudioUser.verify_otp!(
      challenge_id: challenge.id,
      code: code,
      purpose: "registration",
      session: { otp_challenge_id: challenge.id, otp_purpose: "registration" }
    )
    Struct.new(:user, :challenge).new(result.user, result.challenge)
  end
end
