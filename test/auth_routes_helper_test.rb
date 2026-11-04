# frozen_string_literal: true

require "test_helper"

class AuthRoutesHelperTest < Minitest::Test
  def test_routes_module_defines_recording_studio_user_auth_for
    source = File.read(
      File.expand_path("../lib/recording_studio_user/rails/routes.rb", __dir__)
    )

    assert_includes source, "def recording_studio_user_auth_for"
    assert_includes source, 'module: "recording_studio_user/auth"'
    assert_includes source, "sessions#new"
    assert_includes source, "sessions#continue"
    assert_includes source, "registrations#new"
    assert_includes source, "registrations#continue"
    assert_includes source, "sessions#otp"
    assert_includes source, "registrations#otp"
    assert_includes source, "recording_studio_user_otp_registration_routes?"
    assert_includes source, "recording_studio_user_otp_login_routes?"
    assert_includes source, "otp_enabled?"
    assert_includes source, "otp_registration_enabled?"
    assert_includes source, "otp_login_enabled?"
    assert_includes source, "devise/sessions#destroy"
    assert_includes source, "recording_studio_user/auth/passwords"
    assert_includes source, '"edit_#{singular}_password"'
    assert_includes source, "\#{passwords}#update"
  end

  def test_engine_routes_gate_otp_on_config
    source = File.read(File.expand_path("../lib/recording_studio_user/engine_routes.rb", __dir__))

    assert_includes source, "otp_enabled?"
    assert_includes source, "otp_registration_enabled?"
    assert_includes source, "otp_login_enabled?"
    assert_includes source, "resources :otp_codes, only: :show"
  end

  def test_auth_route_helpers_prefer_host_paths
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_user/auth_routes_helper.rb", __dir__)
    )

    assert_includes helper, "def password_session_path"
    assert_includes helper, "def password_registration_path"
    assert_includes helper, "def auth_sign_up_path"
    assert_includes helper, "def auth_sign_in_path"
    assert_includes helper, "def auth_new_password_path"
    assert_includes helper, "def auth_password_path"
    assert_includes helper, "def auth_edit_password_path"
    assert_includes helper, "def continue_session_path"
    assert_includes helper, "def continue_registration_path"
    assert_includes helper, "def host_or_engine"
    assert_includes helper, "main_app.public_send"
  end

  def test_engine_requires_auth_routes_mapper
    lib = File.read(File.expand_path("../lib/recording_studio_user.rb", __dir__))

    assert_includes lib, 'require "recording_studio_user/rails/routes"'
  end

  def test_password_auth_is_not_gated_by_otp_enabled
    base = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/base_controller.rb", __dir__)
    )
    sessions = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/sessions_controller.rb", __dir__)
    )
    registrations = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/registrations_controller.rb", __dir__)
    )

    refute_includes base, "before_action :require_otp_enabled!"
    assert_includes sessions, "before_action :require_otp_login_enabled!"
    assert_includes registrations, "before_action :require_otp_registration_enabled!"
    assert_includes base, "RecordingStudioUser.config.otp_enabled?"
  end

  def test_auth_views_share_default_layout_chrome
    chrome = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/_chrome.html.erb", __dir__)
    )
    %w[
      sessions/new
      sessions/password
      sessions/otp
      sessions/verify
      registrations/new
      registrations/password
      registrations/otp
      registrations/verify
      passwords/new
      passwords/edit
      confirmations/new
    ].each do |view|
      source = File.read(
        File.expand_path("../app/views/recording_studio_user/auth/#{view}.html.erb", __dir__)
      )
      assert_includes source, 'render "recording_studio_user/auth/chrome"'
      refute_includes source, "FlatPack::PageTitle::Component"
      refute_includes source, "recording_studio_user/auth/shell"
    end

    assert_includes chrome, "content_for :title"
    assert_includes chrome, "flat_pack_page_nav"
    assert_includes chrome, "auth_site_logo"
    refute_includes chrome, "min-h-dvh"
    refute_includes chrome, "max-w-sm"
    refute_includes chrome, "FlatPack::PageTitle::Component"
    refute File.exist?(
      File.expand_path("../app/views/layouts/recording_studio_user/auth.html.erb", __dir__)
    )
    refute File.exist?(
      File.expand_path("../app/views/recording_studio_user/auth/_shell.html.erb", __dir__)
    )
  end

  def test_auth_controllers_use_recording_studio_layout
    base = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/base_controller.rb", __dir__)
    )
    application = File.read(
      File.expand_path("../app/controllers/recording_studio_user/application_controller.rb", __dir__)
    )
    confirmations = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/confirmations_controller.rb", __dir__)
    )
    passwords = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/passwords_controller.rb", __dir__)
    )

    assert_includes application, "recording_studio_layout { RecordingStudioUser.configuration.layout }"
    refute_includes base, "layout "
    refute_includes confirmations, 'layout "recording_studio_user/auth"'
    refute_includes passwords, 'layout "recording_studio_user/auth"'
    assert_includes confirmations, "include RecordingStudio::ControllerLayout"
    assert_includes passwords, "include RecordingStudio::ControllerLayout"
    assert_includes confirmations, "recording_studio_layout { RecordingStudioUser.configuration.layout }"
    assert_includes passwords, "recording_studio_layout { RecordingStudioUser.configuration.layout }"
  end
end
