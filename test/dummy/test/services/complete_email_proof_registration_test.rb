# frozen_string_literal: true

require "test_helper"

class CompleteEmailProofRegistrationTest < ActiveSupport::TestCase
  EVENT = RecordingStudioUser::RegistrationCompleted::EVENT
  PROOF_EVENT = "otp.email_proof_completed.recording_studio_user"
  SOURCE_KEY = RecordingStudioUser::SignupSource::SESSION_KEY

  setup do
    ActionMailer::Base.deliveries.clear
    Rails.cache.clear
    @events = []
    @proofs = []
    @subscriber = ActiveSupport::Notifications.subscribe(EVENT) do |_name, _start, _finish, _id, payload|
      @events << payload
    end
    @proof_subscriber = ActiveSupport::Notifications.subscribe(PROOF_EVENT) do |_name, _start, _finish, _id, payload|
      @proofs << payload
    end
    @original_hooks = RecordingStudioUser.config.after_registration_hooks.dup
    RecordingStudioUser.config.after_registration_hooks.clear
  end

  teardown do
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    ActiveSupport::Notifications.unsubscribe(@proof_subscriber)
    RecordingStudioUser.config.after_registration_hooks.clear
    @original_hooks.each { |hook| RecordingStudioUser.config.after_registration_hooks << hook }
  end

  test "a new unconfirmed user emits one registration completed event" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("new"))
    result = verify_registration!(user)

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: result.challenge.id,
      profile_attributes: { first_name: "Ada", last_name: "Lovelace" }
    )

    assert user.reload.confirmed?
    assert_equal [{ user_id: user.id, method: :otp }], @events
    refute @events.first.key?(:source)
    assert_equal [{ user_id: user.id, challenge_id: result.challenge.id }], @proofs
  end

  test "a session source is copied onto the event and the key is cleared" do
    session = {}
    remember_source!(session, { kind: "press_contact", recording_id: 11, early: false })
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("sourced"))
    result = verify_registration!(user)

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: result.challenge.id,
      session: session
    )

    assert_equal(
      [{ user_id: user.id, method: :otp, source: { kind: "press_contact", recording_id: 11, early: false } }],
      @events
    )
    assert_nil session[SOURCE_KEY]
    assert_equal [{ user_id: user.id, challenge_id: result.challenge.id }], @proofs
  end

  test "omitting session emits the event without a source and leaves another session alone" do
    untouched = {}
    remember_source!(untouched, { kind: "press_contact" })
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("nosession"))
    result = verify_registration!(user)

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: result.challenge.id
    )

    assert_equal [{ user_id: user.id, method: :otp }], @events
    refute @events.first.key?(:source)
    assert_equal({ kind: "press_contact" }, RecordingStudioUser::SignupSource.read(untouched))
  end

  test "an already confirmed user does not emit registration completed" do
    user = User.create!(
      email: unique_email("signin"),
      password: "Password123!",
      password_confirmation: "Password123!",
      registered_with: "password",
      confirmed_at: Time.current
    )
    issued = RecordingStudioUser.request_otp!(
      email: user.email,
      purpose: :login,
      request: nil,
      session: {}
    )
    session = { otp_challenge_id: issued.challenge_id, otp_purpose: "login" }
    result = RecordingStudioUser.verify_otp!(
      challenge_id: issued.challenge_id,
      code: otp_code(issued.challenge_id),
      purpose: "login",
      session: session
    )

    RecordingStudioUser.complete_email_proof!(
      user: result.user,
      challenge_id: issued.challenge_id,
      session: session
    )

    assert_empty @events
    assert_equal [{ user_id: user.id, challenge_id: issued.challenge_id }], @proofs
    assert user.reload.confirmed?
  end

  test "a rolled back transaction does not emit registration completed" do
    session = {}
    remember_source!(session, { kind: "press_contact", recording_id: 4 })
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("rollback"))
    result = verify_registration!(user)

    ActiveRecord::Base.transaction do
      RecordingStudioUser.complete_email_proof!(
        user: result.user,
        challenge_id: result.challenge.id,
        session: session
      )
      raise ActiveRecord::Rollback
    end

    assert_empty @events
    refute user.reload.confirmed?
  end

  test "reusing the consumed challenge does not emit a second registration completed event" do
    user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("reuse"))
    result = verify_registration!(user)
    proof = { user: result.user, challenge_id: result.challenge.id }

    RecordingStudioUser.complete_email_proof!(**proof)
    RecordingStudioUser.complete_email_proof!(**proof)

    assert_equal [{ user_id: user.id, method: :otp }], @events
    assert_equal 2, @proofs.size
  end

  test "after_registration hooks run with and without a source keyword" do
    plain = []
    sourced = []
    RecordingStudioUser.config.after_registration ->(user:, method:) { plain << [user.id, method] }
    RecordingStudioUser.config.after_registration ->(user:, method:, source: nil) {
      sourced << [user.id, method, source]
    }
    session = {}
    remember_source!(session, { kind: "kit_download", recording_id: 9 })
    sourced_user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("hook-source"))
    sourced_result = verify_registration!(sourced_user)

    RecordingStudioUser.complete_email_proof!(
      user: sourced_result.user,
      challenge_id: sourced_result.challenge.id,
      session: session
    )

    assert_equal [[sourced_user.id, :otp]], plain
    assert_equal [[sourced_user.id, :otp, { kind: "kit_download", recording_id: 9 }]], sourced

    plain_user = RecordingStudioUser.create_unconfirmed_user!(email: unique_email("hook-plain"))
    plain_result = verify_registration!(plain_user)
    RecordingStudioUser.complete_email_proof!(
      user: plain_result.user,
      challenge_id: plain_result.challenge.id
    )

    assert_equal [[sourced_user.id, :otp], [plain_user.id, :otp]], plain
    assert_equal [
      [sourced_user.id, :otp, { kind: "kit_download", recording_id: 9 }],
      [plain_user.id, :otp, nil]
    ], sourced
  end

  private

  def unique_email(label)
    "#{label}-#{SecureRandom.hex(4)}@example.com"
  end

  def otp_code(challenge_id)
    RecordingStudioUser.otp_message(challenge_id).fetch(:body)[/\d{6}/]
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

  def remember_source!(session, source)
    RecordingStudioUser.remember_signup_source!(
      request: Struct.new(:session).new(session),
      source: source
    )
  end
end
