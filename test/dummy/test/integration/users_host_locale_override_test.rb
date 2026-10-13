# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class UsersHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_NOT_CONNECTED = "HOST That sign-in method is not connected."
  HOST_MY_PROFILE = "HOST My Profile"
  OVERRIDE_KEY = "recording_studio_user.omniauth.not_connected"
  PROFILE_KEY = "recording_studio_user.profile.my_profile"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_user_host.en.yml")
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/users_host_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @backend_before = I18n.backend
    @user = RecordingStudioUser.create_user!(
      email: "users-host-override-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Host",
      last_name: "Override",
      time_zone: "UTC"
    )
    accept_pending_live_terms!(@user)
  end

  teardown do
    I18n.backend = @backend_before if @backend_before
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation. Render assertion uses the not-connected flash.
  test "host locale override for recording_studio_user wins on boot order" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_NOT_CONNECTED
    assert_equal HOST_NOT_CONNECTED, I18n.t(OVERRIDE_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user

    delete recording_studio_users.profile_identity_path("google_oauth2")
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, HOST_NOT_CONNECTED
  end

  # Test-only fixture applied via backend.load_translations(file) on top of the
  # already-initialized backend — never mutates I18n.load_path (Marshal).
  test "fresh-backend last-file-wins host fixture overrides gem english on profile page" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_MY_PROFILE

    sign_in @user

    snapshot = i18n_backend_translations_snapshot
    I18n.t(PROFILE_KEY)
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_MY_PROFILE, I18n.t(PROFILE_KEY)
    assert_equal HOST_NOT_CONNECTED, I18n.t(OVERRIDE_KEY)

    get recording_studio_users.profile_path
    assert_response :success
    assert_includes response.body, HOST_MY_PROFILE
  ensure
    restore_i18n_backend_translations(snapshot) if snapshot
  end

  private

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, nested), copy| copy[key] = deep_plain_copy(nested) }
    when Array
      value.map { |nested| deep_plain_copy(nested) }
    else
      value
    end
  end
end
