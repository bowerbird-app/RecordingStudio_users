# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class GoogleOauthFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    @original_create_account = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.omniauth_create_account = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    RecordingStudioUser.config.omniauth_create_account = @original_create_account
  end

  test "login and sign up show Continue with Google when configured" do
    get new_user_session_path

    assert_response :success
    assert_select "a, button", text: /Continue with Google/
    assert_select "input[type='password']"

    get new_user_registration_path

    assert_response :success
    assert_select "a, button", text: /Continue with Google/
  end

  test "new Google account creates User Profile and Identity then signs in" do
    mock_google_auth!(
      uid: "google-new-#{SecureRandom.hex(4)}",
      email: "oauth-new-#{SecureRandom.hex(4)}@example.com",
      first_name: "Gail",
      last_name: "OAuth"
    )

    assert_difference -> { User.count }, +1 do
      assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    user = User.find_by!(email: OmniAuth.config.mock_auth[:google_oauth2].info.email)
    assert user.encrypted_password.blank?
    assert user.identities.exists?(provider: "google_oauth2")
    assert_equal "Gail OAuth", RecordingStudioUser.display_name_for(user)
    assert RecordingStudioUser.profile_recording_for(user).present?
    follow_redirect! if response.redirect?
    assert_response :success
  end

  test "known Google email links Identity to the existing User" do
    existing = RecordingStudioUser.create_user!(
      email: "linked-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Existing",
      last_name: "User",
      time_zone: "UTC"
    )
    mock_google_auth!(
      uid: "google-link-#{SecureRandom.hex(4)}",
      email: existing.email,
      first_name: "Ignored",
      last_name: "Name"
    )

    assert_no_difference -> { User.count } do
      assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    existing.reload
    assert existing.encrypted_password.present?
    assert_equal 1, existing.identities.where(provider: "google_oauth2").count
    assert_equal "Existing User", RecordingStudioUser.display_name_for(existing)
  end

  test "signed-in Connect attaches Google to the current User" do
    user = RecordingStudioUser.create_user!(
      email: "connect-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Connect",
      last_name: "Me",
      time_zone: "UTC"
    )
    sign_in user
    mock_google_auth!(
      uid: "google-connect-#{SecureRandom.hex(4)}",
      email: "other-google-#{SecureRandom.hex(4)}@example.com",
      first_name: "Other",
      last_name: "Google"
    )

    assert_no_difference -> { User.count } do
      assert_difference -> { user.identities.count }, +1 do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    assert_redirected_to recording_studio_users.edit_profile_path
    assert user.reload.identity_for(:google_oauth2).present?
    assert user.encrypted_password.present?
  end

  test "disconnect removes Identity when another sign-in method remains" do
    user = RecordingStudioUser.create_user!(
      email: "disconnect-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Has",
      last_name: "Password",
      time_zone: "UTC"
    )
    user.identities.create!(provider: "google_oauth2", uid: "uid-#{SecureRandom.hex(4)}", email: user.email)
    sign_in user

    assert_difference -> { user.identities.count }, -1 do
      delete recording_studio_users.profile_identity_path("google_oauth2")
    end

    assert_redirected_to recording_studio_users.edit_profile_path
    refute user.reload.identity_for(:google_oauth2).present?
  end

  test "cannot disconnect the last sign-in method without a password" do
    mock_google_auth!(
      uid: "google-only-#{SecureRandom.hex(4)}",
      email: "google-only-#{SecureRandom.hex(4)}@example.com",
      first_name: "Only",
      last_name: "Google"
    )
    get user_google_oauth2_omniauth_callback_path
    user = User.find_by!(email: OmniAuth.config.mock_auth[:google_oauth2].info.email)
    assert user.encrypted_password.blank?

    assert_no_difference -> { user.identities.count } do
      delete recording_studio_users.profile_identity_path("google_oauth2")
    end

    assert_redirected_to recording_studio_users.edit_profile_path
    follow_redirect!
    assert_match(/password|sign-in method/i, flash[:alert].to_s + response.body)
  end

  test "omniauth_create_account false rejects unknown emails" do
    RecordingStudioUser.config.omniauth_create_account = false
    mock_google_auth!(
      uid: "google-disabled-#{SecureRandom.hex(4)}",
      email: "unknown-#{SecureRandom.hex(4)}@example.com",
      first_name: "No",
      last_name: "Create"
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudioUser::Identity.count } do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    assert_redirected_to new_user_session_path
  end

  test "connect rejects a Google uid already linked to another User" do
    owner = RecordingStudioUser.create_user!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Owner",
      last_name: "User",
      time_zone: "UTC"
    )
    uid = "shared-uid-#{SecureRandom.hex(4)}"
    owner.identities.create!(provider: "google_oauth2", uid: uid, email: owner.email)

    other = RecordingStudioUser.create_user!(
      email: "other-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Other",
      last_name: "User",
      time_zone: "UTC"
    )
    sign_in other
    mock_google_auth!(uid: uid, email: "collision-#{SecureRandom.hex(4)}@example.com")

    assert_no_difference -> { other.identities.count } do
      get user_google_oauth2_omniauth_callback_path
    end

    assert_redirected_to recording_studio_users.edit_profile_path
    follow_redirect!
    assert_match(/already linked/i, flash[:alert].to_s + response.body)
  end

  test "edit profile shows Connect Google and show stays read-only" do
    user = RecordingStudioUser.create_user!(
      email: "ui-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Ui",
      last_name: "User",
      time_zone: "UTC"
    )
    sign_in user

    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_includes response.body, "Sign-in methods"
    assert_includes response.body, "Connect Google"
    assert_includes response.body, "Ui User"
    refute_includes response.body, "large_subtitle"

    get recording_studio_users.profile_path

    assert_response :success
    refute_includes response.body, "Connect Google"
    refute_includes response.body, "Disconnect"
    refute_includes response.body, "Sign-in methods"
  end

  test "edit profile shows Disconnect when Google is connected" do
    user = RecordingStudioUser.create_user!(
      email: "connected-ui-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Connected",
      last_name: "User",
      time_zone: "UTC"
    )
    user.identities.create!(
      provider: "google_oauth2",
      uid: "ui-uid-#{SecureRandom.hex(4)}",
      email: user.email
    )
    sign_in user

    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_includes response.body, "Disconnect"
    assert_select "a, button", text: /\AConnect Google\z/, count: 0
  end

  private

  def mock_google_auth!(uid:, email:, first_name: "Google", last_name: "User")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: {
        email: email,
        name: "#{first_name} #{last_name}",
        first_name: first_name,
        last_name: last_name
      }
    )
  end
end
