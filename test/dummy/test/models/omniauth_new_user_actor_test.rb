# frozen_string_literal: true

require "test_helper"

class OmniauthNewUserActorTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
    @configuration = RecordingStudio.configuration
    @previous_require_actor = @configuration.require_actor
    Current.actor = nil
    # Production refuses a write with no actor. Dummy keeps allow_unauthorized_writes
    # so seeds can record, and that opt-out also skips the actor check unless
    # require_actor is on. Turn the check on and leave Current.actor empty.
    @configuration.require_actor = true
  end

  teardown do
    Current.actor = @previous_actor
    @configuration.require_actor = @previous_require_actor
  end

  test "find_or_create_user! records the profile as the new user with no ambient actor" do
    email = "oauth-actor-#{SecureRandom.hex(4)}@example.com"
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-actor-#{SecureRandom.hex(4)}",
      info: {
        email: email,
        first_name: "Gail",
        last_name: "OAuth",
        email_verified: true
      }
    )

    user = RecordingStudioUser::Omniauth::IdentityFlow.find_or_create_user!(auth)

    assert_equal email, user.email
    assert user.persisted?
    assert_nil Current.actor

    recording = RecordingStudioUser.profile_recording_for(user)
    assert recording
    created = recording.events.find_by!(action: "created")
    assert_equal user, created.actor
    assert_equal "User", created.actor_type
  end

  test "create_user! keeps an explicit actor when one is passed" do
    staff = User.create!(
      email: "staff-actor-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    staff.skip_confirmation! if staff.respond_to?(:skip_confirmation!)
    staff.save!

    user = RecordingStudioUser.create_user!(
      email: "created-by-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "New",
      last_name: "Member",
      time_zone: "UTC",
      actor: staff,
      confirm: true
    )

    created = RecordingStudioUser.profile_recording_for(user).events.find_by!(action: "created")
    assert_equal staff, created.actor
  end
end
