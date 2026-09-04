# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioUser::Configuration.new
  end

  def test_defaults_match_the_public_mount_contract
    assert_equal "User", @configuration.user_class_name
    assert_equal "/recording_studio_users", @configuration.mount_path
    assert_equal "profile", @configuration.profile_route_path
    assert_equal "admin", @configuration.admin_route_path
    assert_equal "application", @configuration.layout
    assert_empty @configuration.additional_profile_attributes
    refute @configuration.require_password_confirmation
    refute_predicate @configuration, :require_password_confirmation?
    assert_equal "Welcome back", @configuration.login_title
    assert_equal :email, @configuration.primary_login_type
    assert_predicate @configuration, :primary_login_type_email?
    refute_predicate @configuration, :primary_login_type_otp?
    assert_empty @configuration.omniauth_providers
    assert_predicate @configuration, :omniauth_create_account?
    refute_predicate @configuration, :omniauth_configured?
  end

  def test_require_password_confirmation_casts_like_other_flags
    @configuration.require_password_confirmation = true
    assert_predicate @configuration, :require_password_confirmation?

    @configuration.require_password_confirmation = "false"
    refute_predicate @configuration, :require_password_confirmation?
  end

  def test_login_title_defaults_and_rejects_blank
    @configuration.login_title = "Sign in to Acme"
    assert_equal "Sign in to Acme", @configuration.login_title

    @configuration.login_title = "  "
    assert_equal "Welcome back", @configuration.login_title
  end

  def test_omniauth_flags_and_providers
    @configuration.omniauth_create_account = false
    refute_predicate @configuration, :omniauth_create_account?

    @configuration.omniauth_create_account = "true"
    assert_predicate @configuration, :omniauth_create_account?

    @configuration.omniauth_providers = {
      "google_oauth2" => { "client_id" => "id", "client_secret" => "secret" },
      "microsoft_graph" => { "client_id" => "", "client_secret" => "secret" }
    }

    assert_equal(
      { google_oauth2: { client_id: "id", client_secret: "secret" } },
      @configuration.omniauth_providers
    )
    assert_predicate @configuration, :omniauth_configured?
    assert @configuration.omniauth_provider_configured?(:google_oauth2)
    refute @configuration.omniauth_provider_configured?(:microsoft_graph)
    refute @configuration.omniauth_provider_configured?(:apple)
  end

  def test_normalizes_configured_paths
    @configuration.mount_path = "account/"
    @configuration.profile_route_path = "/me/"
    @configuration.admin_route_path = "/user-reporting/"

    assert_equal "/account", @configuration.mount_path
    assert_equal "me", @configuration.profile_route_path
    assert_equal "user-reporting", @configuration.admin_route_path
  end

  def test_rejects_invalid_paths_and_protected_attributes
    assert_raises(ArgumentError) { @configuration.mount_path = "" }
    assert_raises(ArgumentError) { @configuration.profile_route_path = "../profile" }
    assert_raises(ArgumentError) { @configuration.admin_route_path = "admin//users" }
    assert_raises(ArgumentError) { @configuration.additional_profile_attributes = [:email] }
  end

  def test_allows_safe_additional_attributes
    @configuration.additional_profile_attributes = ["locale", :locale, "preferred_name"]

    assert_equal %i[locale preferred_name], @configuration.additional_profile_attributes
  end

  def test_otp_defaults_and_validation
    assert_equal false, @configuration.otp_enabled
    assert @configuration.otp_login_enabled?
    assert @configuration.otp_registration_enabled?
    assert_equal %i[password otp], @configuration.registration_authentication_methods
    assert_equal 10.minutes, @configuration.otp_expires_in
    assert_equal 5, @configuration.otp_max_attempts
    assert_equal 60.seconds, @configuration.otp_resend_cooldown
    assert_equal %i[email], @configuration.otp_registration_channels
    assert_equal %i[email push], @configuration.otp_login_channels
    assert_equal 7.days, @configuration.unconfirmed_user_retention
  end

  def test_primary_login_type_email_and_otp
    @configuration.primary_login_type = :email
    assert_predicate @configuration, :primary_login_type_email?

    assert_raises(ArgumentError) { @configuration.primary_login_type = :otp }

    @configuration.otp_enabled = true
    @configuration.primary_login_type = :otp
    assert_predicate @configuration, :primary_login_type_otp?

    assert_raises(ArgumentError) { @configuration.primary_login_type = :sms }
    assert_raises(ArgumentError) { @configuration.otp_enabled = false }
  end

  def test_primary_login_type_otp_requires_login_and_registration_flags
    @configuration.otp_enabled = true
    @configuration.otp_registration_enabled = false
    assert_raises(ArgumentError) { @configuration.primary_login_type = :otp }

    @configuration.otp_registration_enabled = true
    @configuration.registration_authentication_methods = %i[password]
    @configuration.otp_login_enabled = false
    assert_raises(ArgumentError) { @configuration.primary_login_type = :otp }

    @configuration.otp_login_enabled = true
    assert_raises(ArgumentError) { @configuration.primary_login_type = :otp }

    @configuration.registration_authentication_methods = %i[password otp]
    @configuration.primary_login_type = :otp
    assert_predicate @configuration, :primary_login_type_otp?
  end

  def test_otp_login_disabled_with_otp_registration_raises
    assert_raises(ArgumentError) { @configuration.otp_login_enabled = false }

    fresh = RecordingStudioUser::Configuration.new
    fresh.registration_authentication_methods = %i[password]
    fresh.otp_login_enabled = false
    assert_raises(ArgumentError) { fresh.registration_authentication_methods = %i[otp] }
  end

  def test_invalid_registration_authentication_methods_raise
    assert_raises(ArgumentError) { @configuration.registration_authentication_methods = %i[sms] }
  end

  def test_non_positive_otp_settings_raise
    assert_raises(ArgumentError) { @configuration.otp_expires_in = 0 }
    assert_raises(ArgumentError) { @configuration.otp_max_attempts = 0 }
    assert_raises(ArgumentError) { @configuration.otp_resend_cooldown = 0 }
    assert_raises(ArgumentError) { @configuration.unconfirmed_user_retention = 0 }
  end

  def test_mounted_admin_path_uses_configured_paths
    original_config = RecordingStudioUser.config
    RecordingStudioUser.instance_variable_set(:@config, @configuration)
    @configuration.mount_path = "/account"
    @configuration.admin_route_path = "user-reporting"

    assert_equal "/account/user-reporting", RecordingStudioUser.mounted_admin_path
  ensure
    RecordingStudioUser.instance_variable_set(:@config, original_config)
  end
end
