# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class OmniauthFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    OmniAuth.config.test_mode = true
    clear_omniauth_mocks!
    @original_create_account = RecordingStudioUser.config.omniauth_create_account
    RecordingStudioUser.config.omniauth_create_account = true
  end

  teardown do
    clear_omniauth_mocks!
    RecordingStudioUser.config.omniauth_create_account = @original_create_account
  end

  test "login and sign up show Continue with each configured provider" do
    get new_user_session_path

    assert_response :success
    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "a, button", text: /Continue with #{Regexp.escape(label)}/
    end
    assert_select "input[type='password']"

    get new_user_registration_path

    assert_response :success
    assert_select "a, button", text: /Continue with Google/
    assert_select "a, button", text: /Continue with Microsoft/
  end

  test "new Google account creates User Profile and Identity then signs in" do
    mock_provider_auth!(
      :google_oauth2,
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

  test "Microsoft find-or-create links known email and creates unknown email" do
    existing = RecordingStudioUser.create_user!(
      email: "ms-linked-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Existing",
      last_name: "User",
      time_zone: "UTC"
    )
    mock_provider_auth!(
      :microsoft_graph,
      uid: "ms-link-#{SecureRandom.hex(4)}",
      email: existing.email,
      first_name: "Ignored",
      last_name: "Name"
    )

    assert_no_difference -> { User.count } do
      assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
        get user_microsoft_graph_omniauth_callback_path
      end
    end

    existing.reload
    assert existing.identities.exists?(provider: "microsoft_graph")

    delete destroy_user_session_path if respond_to?(:destroy_user_session_path)
    reset!

    mock_provider_auth!(
      :microsoft_graph,
      uid: "ms-new-#{SecureRandom.hex(4)}",
      email: "ms-new-#{SecureRandom.hex(4)}@example.com",
      first_name: "New",
      last_name: "Microsoft"
    )

    assert_difference -> { User.count }, +1 do
      get user_microsoft_graph_omniauth_callback_path
    end
  end

  test "Instagram without email fails closed on first login but connects while signed in" do
    mock_provider_auth!(
      :instagram,
      uid: "ig-no-email-#{SecureRandom.hex(4)}",
      email: nil,
      first_name: "Ig",
      last_name: "User"
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudioUser::Identity.count } do
        get user_instagram_omniauth_callback_path
      end
    end

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match(/did not return an email/i, flash[:alert].to_s + response.body)

    user = RecordingStudioUser.create_user!(
      email: "ig-connect-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Ig",
      last_name: "Connect",
      time_zone: "UTC"
    )
    sign_in user
    mock_provider_auth!(
      :instagram,
      uid: "ig-connect-#{SecureRandom.hex(4)}",
      email: nil,
      first_name: "Ig",
      last_name: "Connect"
    )

    assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
      get user_instagram_omniauth_callback_path
    end

    identity = user.identities.find_by!(provider: "instagram")
    assert_nil identity.email
    assert_redirected_to recording_studio_users.sign_in_methods_profile_path
  end

  test "signed-in Connect and Disconnect work across providers" do
    user = RecordingStudioUser.create_user!(
      email: "connect-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Connect",
      last_name: "Me",
      time_zone: "UTC"
    )
    sign_in user
    mock_provider_auth!(
      :linkedin,
      uid: "li-connect-#{SecureRandom.hex(4)}",
      email: "li-#{SecureRandom.hex(4)}@example.com",
      first_name: "Li",
      last_name: "User"
    )

    assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
      get user_linkedin_omniauth_callback_path
    end
    assert_redirected_to recording_studio_users.sign_in_methods_profile_path

    delete recording_studio_users.profile_identity_path("linkedin")
    assert_redirected_to recording_studio_users.sign_in_methods_profile_path
    refute user.identities.exists?(provider: "linkedin")
  end

  test "disconnect refuses last method when user has no password" do
    mock_provider_auth!(
      :apple,
      uid: "apple-only-#{SecureRandom.hex(4)}",
      email: "apple-only-#{SecureRandom.hex(4)}@example.com",
      first_name: "Apple",
      last_name: "Only"
    )
    get user_apple_omniauth_callback_path
    user = User.order(:created_at).last
    sign_in user

    assert_no_difference -> { RecordingStudioUser::Identity.count } do
      delete recording_studio_users.profile_identity_path("apple")
    end
    assert_redirected_to recording_studio_users.sign_in_methods_profile_path
    assert_match(/password|sign-in method/i, flash[:alert].to_s)
  end

  test "omniauth_create_account false refuses unknown emails" do
    RecordingStudioUser.config.omniauth_create_account = false
    mock_provider_auth!(
      :google_oauth2,
      uid: "disabled-#{SecureRandom.hex(4)}",
      email: "disabled-#{SecureRandom.hex(4)}@example.com"
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudioUser::Identity.count } do
        get user_google_oauth2_omniauth_callback_path
      end
    end
    assert_redirected_to new_user_session_path
  end

  test "uid collision rejects Connect to another User" do
    owner = RecordingStudioUser.create_user!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Owner",
      last_name: "User",
      time_zone: "UTC"
    )
    owner.identities.create!(provider: "google_oauth2", uid: "shared-uid", email: owner.email)

    other = RecordingStudioUser.create_user!(
      email: "other-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Other",
      last_name: "User",
      time_zone: "UTC"
    )
    sign_in other
    mock_provider_auth!(:google_oauth2, uid: "shared-uid", email: "ignored@example.com")

    assert_no_difference -> { RecordingStudioUser::Identity.count } do
      get user_google_oauth2_omniauth_callback_path
    end
    assert_redirected_to recording_studio_users.sign_in_methods_profile_path
    assert_match(/already linked/i, flash[:alert].to_s + response.body)
  end

  test "edit profile has no Connect or Sign-in methods link" do
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
    refute_includes response.body, "Connect Google"
    refute_includes response.body, "Disconnect"
    refute_includes response.body, recording_studio_users.sign_in_methods_profile_path

    get recording_studio_users.profile_path

    assert_response :success
    assert_includes response.body, "Sign-in methods"
    assert_includes response.body, recording_studio_users.sign_in_methods_profile_path
  end

  test "sign-in methods lists Connect for every unlinked configured provider" do
    user = RecordingStudioUser.create_user!(
      email: "methods-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Methods",
      last_name: "User",
      time_zone: "UTC"
    )
    sign_in user

    get recording_studio_users.sign_in_methods_profile_path

    assert_response :success
    assert_includes response.body, 'role="list"'
    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_includes response.body, label
    end
    assert_select "a, button", text: /\AConnect\z/, count: 5
  end

  test "sign-in methods shows Disconnect for linked Google and Connect for others" do
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

    get recording_studio_users.sign_in_methods_profile_path

    assert_response :success
    assert_includes response.body, "Disconnect"
    assert_includes response.body, user.email
    assert_select "a, button", text: /\AConnect\z/, count: 4
    assert_select "a, button", text: /\ADisconnect\z/, count: 1
  end

  private

  def clear_omniauth_mocks!
    %i[google_oauth2 microsoft_graph apple linkedin instagram].each do |provider|
      OmniAuth.config.mock_auth[provider] = nil
    end
  end

  def mock_provider_auth!(provider, uid:, email:, first_name: "OAuth", last_name: "User")
    info = {
      name: "#{first_name} #{last_name}",
      first_name: first_name,
      last_name: last_name
    }
    info[:email] = email if email.present?

    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
      provider: provider.to_s,
      uid: uid,
      info: info
    )
  end
end
