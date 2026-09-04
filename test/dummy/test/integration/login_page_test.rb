# frozen_string_literal: true

require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  AUTH_SESSIONS_VIEW = RecordingStudioUser::Engine.root.join(
    "app/views/recording_studio_user/auth/sessions/new.html.erb"
  ).freeze
  AUTH_PASSWORD_VIEW = RecordingStudioUser::Engine.root.join(
    "app/views/recording_studio_user/auth/sessions/password.html.erb"
  ).freeze

  test "login paints Welcome back with email only, no Card or Remember me" do
    get new_user_session_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "h2", text: "Welcome back"
    assert_select "input[type='email'][name='user[email]'][placeholder='you@company.com']"
    assert_select "label", text: "Email", count: 0
    assert_select "input[type='password'][name='user[password]']", count: 0
    assert_select "input[name='user[remember_me]']", count: 0
    assert_select "button[type='submit']", text: "Continue with email"
    refute_includes response.body, "Remember me"
    refute_includes response.body, "Email OTP"
    refute_includes response.body, "Continue with password"
    refute_includes response.body, "/sign_in/otp"
    refute_includes response.body, "fixed inset-0"
    refute_includes response.body, "place-content-center"
    refute_includes response.body, "Default: admin@admin.com / Password"
    source = File.read(AUTH_SESSIONS_VIEW)
    shell = File.read(
      RecordingStudioUser::Engine.root.join("app/views/recording_studio_user/auth/_shell.html.erb")
    )
    refute_includes source, "FlatPack::Card::Component"
    refute_includes source, "otp_session_otp_path"
    assert_includes source, 'layout: "recording_studio_user/auth/shell"'
    refute_includes shell, "min-h-dvh"
    assert_includes shell, "max-w-sm"
    assert_includes shell, "text-left"
    assert_includes shell, "auth_site_logo"
    assert_equal 1, response.body.scan("min-h-dvh").length
    assert_includes response.body, "max-w-sm"
    assert_includes response.body, "Don't have an account?"
    assert_includes response.body, "text-center"
    assert_includes response.body, "text-left"
    assert_includes response.body, 'href="/users/sign_up"'
    refute_includes response.body, 'href="/recording_studio_users/auth/sign_up"'
    assert_match(/\bOr\b/, response.body)

    %w[Google Microsoft Apple LinkedIn Instagram].each do |label|
      assert_select "form[method='post'] button[type='submit']", text: "Continue with #{label}"
    end
  end

  test "login shows site square logo above the title when Site Settings has one" do
    skip "recording_studio_site_settings not loaded" unless defined?(RecordingStudioSiteSettings)

    admin_user = User.find_or_initialize_by(email: "admin@admin.com")
    if admin_user.new_record?
      admin_user.password = admin_user.password_confirmation = "Password"
      admin_user.save!
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    bootstrap_owner_access!(admin_user, admin_root_recording)

    square = Rails.root.join("db/seeds/square-logo.png")
    assert square.exist?, "dummy seed square logo missing"
    File.open(square, "rb") do |io|
      RecordingStudioSiteSettings.update!(
        admin_root_recording,
        name: "Studio",
        actor: admin_user,
        square_logo_io: io,
        square_logo_filename: "square-logo.png",
        square_logo_content_type: "image/png"
      )
    end

    get new_user_session_path

    assert_response :success
    assert_select "img[alt='Studio'][src*='active_storage']"
    assert_match %r{max-w-sm[\s\S]*active_storage[\s\S]*Welcome back}, response.body
  end

  test "continue with email primary opens password screen" do
    original = RecordingStudioUser.config.primary_login_type
    RecordingStudioUser.config.primary_login_type = :email

    post new_user_session_path, params: { user: { email: "member@admin.com" } }

    assert_redirected_to "#{new_user_session_path}/password"
    follow_redirect!

    assert_response :success
    assert_select "input[type='password'][name='user[password]']"
    assert_select "input[type='hidden'][name='user[email]'][value='member@admin.com']"
    assert_select "input[type='email']", count: 0
    assert_select "button[type='submit']", text: "Sign in"
    refute_includes response.body, "Don't have an account?"
    refute_includes response.body, "Continue with Google"
    password_source = File.read(AUTH_PASSWORD_VIEW)
    refute_includes password_source, "FlatPack::Card::Component"
    assert_includes password_source, 'layout: "recording_studio_user/auth/shell"'
  ensure
    RecordingStudioUser.config.primary_login_type = original
  end

  test "password sign in path without email sends you back to start" do
    get "#{new_user_session_path}/password"

    assert_redirected_to new_user_session_path
  end

  test "direct OTP sign in page renders email form without primary chooser" do
    get "#{new_user_session_path}/otp"

    assert_response :success
    assert_select "input[name='user[email]']"
    assert_select "button[type='submit']", text: "Send code"
    assert_equal 1, response.body.scan("min-h-dvh").length
    assert_includes response.body, "max-w-sm"
    refute_includes response.body, "Continue with password"
  end

  test "password login stays available when OTP is turned off" do
    original_otp = RecordingStudioUser.config.otp_enabled
    original_primary = RecordingStudioUser.config.primary_login_type
    RecordingStudioUser.config.primary_login_type = :email
    RecordingStudioUser.config.otp_enabled = false

    get new_user_session_path
    assert_response :success
    assert_select "h2", text: "Welcome back"
    assert_select "button[type='submit']", text: "Continue with email"

    post new_user_session_path, params: { user: { email: "member@admin.com" } }
    assert_redirected_to "#{new_user_session_path}/password"

    get "#{new_user_session_path}/otp"
    assert_response :not_found

    get new_user_registration_path
    assert_response :success
    assert_select "button[type='submit']", text: "Continue with email"

    get "#{new_user_registration_path}/otp"
    assert_response :not_found
  ensure
    RecordingStudioUser.config.otp_enabled = original_otp
    RecordingStudioUser.config.primary_login_type = original_primary
  end

  test "primary otp continue issues a code and opens verify" do
    original = RecordingStudioUser.config.primary_login_type
    RecordingStudioUser.config.primary_login_type = :otp

    post new_user_session_path, params: { user: { email: "otp@admin.com" } }

    assert_redirected_to verify_user_session_path
    assert_match(/eligible account/i, flash[:notice])
    follow_redirect!
    assert_response :success
    assert_select "input[name='code']"
    assert_includes response.body, "Enter your code"
  ensure
    RecordingStudioUser.config.primary_login_type = original
  end

  test "login title follows RecordingStudioUser.config.login_title" do
    original = RecordingStudioUser.config.login_title
    RecordingStudioUser.config.login_title = "Sign in to Acme"

    get new_user_session_path

    assert_response :success
    assert_select "h2", text: "Sign in to Acme"
  ensure
    RecordingStudioUser.config.login_title = original
  end

  test "dummy OmniAuth follows credentials and never enables OmniAuth test mode in the app" do
    source = File.read(Rails.root.join("config/initializers/recording_studio_user.rb"))
    initializer_paths = Dir[Rails.root.join("config/initializers/*.rb")]

    refute_includes source, "ENV["
    refute_includes source, "OMNIAUTH_TEST_MODE"
    refute_includes source, "OmniAuth.config.test_mode"
    initializer_paths.each do |path|
      contents = File.read(path)
      refute_includes contents, "OMNIAUTH_TEST_MODE"
      refute_includes contents, "OmniAuth.config.test_mode"
    end
    assert_includes source, "omniauth:"
  end
end
