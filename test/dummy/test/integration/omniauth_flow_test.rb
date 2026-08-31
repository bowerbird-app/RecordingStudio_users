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

  test "Devise callback route is wired to the Users callback controller" do
    route = Rails.application.routes.recognize_path(
      "/users/auth/google_oauth2/callback",
      method: :get
    )

    assert_equal "recording_studio_user/omniauth_callbacks", route[:controller]
    assert_equal "google_oauth2", route[:action]
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

  test "returning provider uid signs into its existing User without using a changed email" do
    user = RecordingStudioUser.create_user!(
      email: "returning-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Returning",
      last_name: "User",
      time_zone: "UTC"
    )
    uid = "returning-#{SecureRandom.hex(4)}"
    user.identities.create!(provider: "google_oauth2", uid: uid, email: user.email)
    mock_provider_auth!(
      :google_oauth2,
      uid: uid,
      email: "changed-#{SecureRandom.hex(4)}@example.com"
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudioUser::Identity.count } do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    assert_redirected_to root_path
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
      email: existing.email.upcase,
      first_name: "Ignored",
      last_name: "Name"
    )

    assert_no_difference -> { User.count } do
      assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
        get user_microsoft_graph_omniauth_callback_path
      end
    end

    existing.reload
    identity = existing.identities.find_by!(provider: "microsoft_graph")
    assert_equal existing.email, identity.email

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

  test "omniauth_create_account false still links a matching existing email" do
    RecordingStudioUser.config.omniauth_create_account = false
    existing = RecordingStudioUser.create_user!(
      email: "known-disabled-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Known",
      last_name: "User",
      time_zone: "UTC"
    )
    mock_provider_auth!(
      :google_oauth2,
      uid: "known-disabled-#{SecureRandom.hex(4)}",
      email: existing.email.upcase
    )

    assert_no_difference -> { User.count } do
      assert_difference -> { RecordingStudioUser::Identity.count }, +1 do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    assert existing.identities.exists?(provider: "google_oauth2")
  end

  test "explicitly unverified provider email never links an existing User" do
    existing = RecordingStudioUser.create_user!(
      email: "unverified-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Existing",
      last_name: "User",
      time_zone: "UTC"
    )
    mock_provider_auth!(
      :google_oauth2,
      uid: "unverified-#{SecureRandom.hex(4)}",
      email: existing.email,
      email_verified: false
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudioUser::Identity.count } do
        get user_google_oauth2_omniauth_callback_path
      end
    end

    assert_redirected_to new_user_session_path
    assert_match(/did not verify/i, flash[:alert].to_s)
  end

  test "unconfirmed existing email is not automatically linked when the User supports confirmation" do
    existing = RecordingStudioUser.create_user!(
      email: "unconfirmed-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Unconfirmed",
      last_name: "User",
      time_zone: "UTC"
    )
    original_confirmed = User.instance_method(:confirmed?) if User.method_defined?(:confirmed?)
    User.define_method(:confirmed?) { false }
    mock_provider_auth!(
      :google_oauth2,
      uid: "unconfirmed-#{SecureRandom.hex(4)}",
      email: existing.email
    )

    assert_no_difference -> { RecordingStudioUser::Identity.count } do
      get user_google_oauth2_omniauth_callback_path
    end

    assert_redirected_to new_user_session_path
    assert_match(/Confirm your email/i, flash[:alert].to_s)
  ensure
    if original_confirmed
      User.define_method(:confirmed?, original_confirmed)
    else
      User.send(:remove_method, :confirmed?) if User.method_defined?(:confirmed?)
    end
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

  test "a User cannot connect a second identity for the same provider" do
    user = RecordingStudioUser.create_user!(
      email: "one-provider-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "One",
      last_name: "Provider",
      time_zone: "UTC"
    )
    user.identities.create!(
      provider: "google_oauth2",
      uid: "first-#{SecureRandom.hex(4)}",
      email: user.email
    )
    sign_in user
    mock_provider_auth!(
      :google_oauth2,
      uid: "second-#{SecureRandom.hex(4)}",
      email: user.email
    )

    assert_no_difference -> { RecordingStudioUser::Identity.count } do
      get user_google_oauth2_omniauth_callback_path
    end
    assert_redirected_to recording_studio_users.sign_in_methods_profile_path
    assert_match(/already linked/i, flash[:alert].to_s)
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

  test "Sign-in methods and identity removal require Accessible edit access" do
    locked_out = User.create!(
      email: "oauth-locked-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    RecordingStudioUser.people_root.record(RecordingStudioUser::Profile) do |profile|
      profile.user_id = locked_out.id
      profile.first_name = "OAuth"
      profile.last_name = "Locked"
      profile.time_zone = "UTC"
    end
    identity = locked_out.identities.create!(
      provider: "google_oauth2",
      uid: "locked-#{SecureRandom.hex(4)}",
      email: locked_out.email
    )
    sign_in locked_out

    get recording_studio_users.sign_in_methods_profile_path
    assert_response :forbidden

    assert_no_difference -> { RecordingStudioUser::Identity.count } do
      delete recording_studio_users.profile_identity_path("google_oauth2")
    end
    assert_response :forbidden
    assert_predicate identity.reload, :persisted?
  end

  test "Continue Connect and Disconnect forms include CSRF tokens" do
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get new_user_session_path
    RecordingStudioUser.config.omniauth_provider_names.each do |provider|
      path = Rails.application.routes.url_helpers.public_send("user_#{provider}_omniauth_authorize_path")
      assert_select "form[action='#{path}'][method='post'] input[name='authenticity_token']", count: 1
    end

    user = RecordingStudioUser.create_user!(
      email: "csrf-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Csrf",
      last_name: "User",
      time_zone: "UTC"
    )
    user.identities.create!(
      provider: "google_oauth2",
      uid: "csrf-#{SecureRandom.hex(4)}",
      email: user.email
    )
    sign_in user
    get recording_studio_users.sign_in_methods_profile_path

    disconnect_path = recording_studio_users.profile_identity_path("google_oauth2")
    assert_select "form[action='#{disconnect_path}'][method='post'] input[name='authenticity_token']", count: 1
    assert_select "form[action='#{disconnect_path}'] input[name='_method'][value='delete']", count: 1
    %i[microsoft_graph apple linkedin instagram].each do |provider|
      path = Rails.application.routes.url_helpers.public_send("user_#{provider}_omniauth_authorize_path")
      assert_select "form[action='#{path}'][method='post'] input[name='authenticity_token']", count: 1
    end
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
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

  def mock_provider_auth!(
    provider,
    uid:,
    email:,
    first_name: "OAuth",
    last_name: "User",
    email_verified: nil
  )
    info = {
      name: "#{first_name} #{last_name}",
      first_name: first_name,
      last_name: last_name
    }
    info[:email] = email if email.present?
    info[:email_verified] = email_verified unless email_verified.nil?

    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
      provider: provider.to_s,
      uid: uid,
      info: info
    )
  end
end
