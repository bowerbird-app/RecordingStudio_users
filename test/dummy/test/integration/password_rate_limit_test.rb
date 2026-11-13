# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PasswordRateLimitTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActionMailer::Base.deliveries.clear
    @config = RecordingStudioUser.config
    @original_limits = {
      password_sign_in_email_limit: @config.password_sign_in_email_limit,
      password_sign_in_ip_limit: @config.password_sign_in_ip_limit,
      password_reset_email_limit: @config.password_reset_email_limit,
      password_reset_ip_limit: @config.password_reset_ip_limit
    }
    @original_paranoid = Devise.paranoid
  end

  teardown do
    Rails.cache = @previous_cache
    @original_limits.each { |setting, value| @config.public_send("#{setting}=", value) }
    Devise.paranoid = @original_paranoid
  end

  test "sign-in throttles per email and answers with the mismatch notice" do
    email = "rate-sign-in-#{SecureRandom.hex(4)}@example.com"
    create_password_user!(email)
    mismatch = I18n.t("recording_studio_user.auth.email_or_password_mismatch")

    5.times do
      post_sign_in(email: email, password: "not-the-password", ip: "203.0.113.30")
      assert_password_mismatch(mismatch)
    end

    post_sign_in(email: email, password: "Password123!", ip: "203.0.113.30")
    assert_password_mismatch(mismatch)

    other = "other-rate-#{SecureRandom.hex(4)}@example.com"
    create_password_user!(other)
    post_sign_in(email: other, password: "Password123!", ip: "203.0.113.30")
    assert_redirected_to root_path
  end

  test "sign-in throttles per IP and a block does not spend the email key" do
    @config.password_sign_in_ip_limit = 1
    @config.password_sign_in_email_limit = 1
    first = "rate-ip-#{SecureRandom.hex(4)}@example.com"
    second = "rate-ip-next-#{SecureRandom.hex(4)}@example.com"
    create_password_user!(first)
    create_password_user!(second)
    mismatch = I18n.t("recording_studio_user.auth.email_or_password_mismatch")

    post_sign_in(email: first, password: "not-the-password", ip: "203.0.113.31")
    assert_password_mismatch(mismatch)

    post_sign_in(email: second, password: "Password123!", ip: "203.0.113.31")
    assert_password_mismatch(mismatch)

    post_sign_in(email: second, password: "Password123!", ip: "203.0.113.32")
    assert_redirected_to root_path
  end

  test "reset throttles per email and keeps the neutral notice" do
    email = "rate-reset-#{SecureRandom.hex(4)}@example.com"
    create_password_user!(email)
    notice = I18n.t("devise.passwords.send_instructions")

    3.times do
      ActionMailer::Base.deliveries.clear
      post_reset(email: email, ip: "203.0.113.40")
      assert_neutral_reset(notice)
      assert_equal 1, ActionMailer::Base.deliveries.size
    end

    @config.password_reset_ip_limit = 1
    ActionMailer::Base.deliveries.clear
    post_reset(email: email, ip: "203.0.113.41")
    assert_neutral_reset(notice)
    assert_empty ActionMailer::Base.deliveries

    other = "other-reset-#{SecureRandom.hex(4)}@example.com"
    create_password_user!(other)
    ActionMailer::Base.deliveries.clear
    post_reset(email: other, ip: "203.0.113.41")
    assert_neutral_reset(notice)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "known and unknown emails match with and without a throttle" do
    [false, true].each do |paranoid|
      Devise.paranoid = paranoid
      Rails.cache.clear
      known = "rate-known-#{paranoid}-#{SecureRandom.hex(3)}@example.com"
      unknown = "rate-unknown-#{paranoid}-#{SecureRandom.hex(3)}@example.com"
      create_password_user!(known)
      mismatch = I18n.t("recording_studio_user.auth.email_or_password_mismatch")
      notice = I18n.t("devise.passwords.send_instructions")
      ip = paranoid ? "203.0.113.50" : "203.0.113.51"

      post_sign_in(email: known, password: "not-the-password", ip: ip)
      known_sign_in = response.status
      known_alert = flash[:alert]
      post_sign_in(email: unknown, password: "not-the-password", ip: ip)
      assert_equal known_sign_in, response.status
      assert_equal known_alert, flash[:alert]
      assert_equal mismatch, flash[:alert]

      ActionMailer::Base.deliveries.clear
      post_reset(email: known, ip: ip)
      assert_equal 1, ActionMailer::Base.deliveries.size
      known_reset = flash[:notice]
      post_reset(email: unknown, ip: ip)
      assert_equal known_reset, flash[:notice]
      assert_equal notice, flash[:notice]
      refute_match(/not found/i, flash[:notice].to_s)

      @config.password_sign_in_email_limit = 1
      @config.password_reset_email_limit = 1
      Rails.cache.clear

      post_sign_in(email: known, password: "Password123!", ip: ip)
      post_sign_in(email: known, password: "Password123!", ip: "203.0.113.60")
      throttled_known_sign_in = [response.status, flash[:alert]]
      post_sign_in(email: unknown, password: "Password123!", ip: "203.0.113.61")
      post_sign_in(email: unknown, password: "Password123!", ip: "203.0.113.62")
      assert_equal throttled_known_sign_in, [response.status, flash[:alert]]
      assert_equal mismatch, flash[:alert]

      sign_out :user
      ActionMailer::Base.deliveries.clear
      post_reset(email: known, ip: "203.0.113.70")
      assert_equal 1, ActionMailer::Base.deliveries.size
      ActionMailer::Base.deliveries.clear
      post_reset(email: known, ip: "203.0.113.71")
      assert_empty ActionMailer::Base.deliveries
      throttled_known_reset = flash[:notice]
      post_reset(email: unknown, ip: "203.0.113.72")
      post_reset(email: unknown, ip: "203.0.113.73")
      assert_equal throttled_known_reset, flash[:notice]
      assert_equal notice, flash[:notice]
      assert_empty ActionMailer::Base.deliveries
      refute_match(/not found/i, flash[:notice].to_s)

      @config.password_sign_in_email_limit = @original_limits[:password_sign_in_email_limit]
      @config.password_reset_email_limit = @original_limits[:password_reset_email_limit]
    end
  end

  private

  def create_password_user!(email)
    user = RecordingStudioUser.create_user!(
      email: email,
      password: "Password123!",
      first_name: "Rate",
      last_name: "Limit",
      time_zone: "UTC"
    )
    accept_pending_live_terms!(user)
    sign_out :user
    user
  end

  def post_sign_in(email:, password:, ip:)
    post "/users/sign_in/password",
         params: { user: { email: email, password: password } },
         env: { "REMOTE_ADDR" => ip }
  end

  def post_reset(email:, ip:)
    post user_password_path,
         params: { user: { email: email } },
         env: { "REMOTE_ADDR" => ip }
  end

  def assert_password_mismatch(message)
    assert_response :unprocessable_entity
    assert_equal message, flash[:alert]
    assert_includes response.body, message
    refute_match(/too many|try again later|locked/i, response.body)
  end

  def assert_neutral_reset(notice)
    assert_redirected_to new_user_session_path
    assert_equal notice, flash[:notice]
    refute_match(/not found/i, flash[:notice].to_s)
  end
end
