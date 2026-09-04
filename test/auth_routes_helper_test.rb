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
    assert_includes source, "registrations#new"
    assert_includes source, "sessions#otp"
    assert_includes source, "registrations#otp"
    assert_includes source, "devise/sessions#destroy"
    assert_includes source, "recording_studio_user/auth/passwords"
  end

  def test_auth_route_helpers_prefer_host_paths
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_user/auth_routes_helper.rb", __dir__)
    )

    assert_includes helper, "def password_session_path"
    assert_includes helper, "def password_registration_path"
    assert_includes helper, "def auth_sign_up_path"
    assert_includes helper, "def auth_sign_in_path"
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

  def test_auth_views_share_the_shell_partial
    shell = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/_shell.html.erb", __dir__)
    )
    %w[
      sessions/new
      sessions/otp
      sessions/verify
      registrations/new
      registrations/otp
      registrations/verify
    ].each do |view|
      source = File.read(
        File.expand_path("../app/views/recording_studio_user/auth/#{view}.html.erb", __dir__)
      )
      assert_includes source, 'layout: "recording_studio_user/auth/shell"'
    end

    refute_includes shell, "min-h-dvh"
    assert_includes shell, "w-full"
    assert_includes shell, "max-w-sm"
    assert_includes shell, "FlatPack::PageTitle::Component"
  end

  def test_auth_layout_owns_viewport_centering
    layout = File.read(
      File.expand_path("../app/views/layouts/recording_studio_user/auth.html.erb", __dir__)
    )
    base = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/base_controller.rb", __dir__)
    )

    assert_includes base, 'layout "recording_studio_user/auth"'
    refute_includes base, 'layout "application"'
    assert_includes layout, "min-h-dvh"
    assert_includes layout, "items-center"
    assert_equal 1, layout.scan("min-h-dvh").length
  end
end
