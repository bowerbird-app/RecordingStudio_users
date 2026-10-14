# frozen_string_literal: true

require "test_helper"

class OtpChallengesMetricsTest < ActiveSupport::TestCase
  include AccessGrantTestHelper

  WINDOW = { interval: :month, start_at: Time.utc(2026, 3, 1), end_at: Time.utc(2026, 5, 1) }.freeze

  setup do
    @actor = create_user("otp-metrics-actor-#{SecureRandom.hex(4)}@example.com")
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    RecordingStudioMetrics.registry.reset!
    RecordingStudioUser::Metrics.register!
  end

  test "registers failed_over_time with unit and catalog fields on the operations API" do
    definition = RecordingStudioMetrics.find("otp_challenges.failed_over_time")

    assert_equal :timeseries, definition.result_type
    assert_equal "count", definition.unit
    assert_equal :revoked_at, definition.field
    assert_equal [:purpose], definition.group_by
    assert_equal :site, definition.blast_radius
    assert definition.exposed_to_api?(:operations)
    assert_equal "Failed OTP challenges over time", definition.title
    assert_predicate definition.description, :present?

    catalog = definition.catalog_metadata
    assert_equal 5, catalog[:min_group_size]
    assert catalog.dig(:date_range, :supported)
  end

  test "users.confirmation has a count unit" do
    assert_equal "count", RecordingStudioMetrics.find("users.confirmation").unit
  end

  test "counts challenges locked by VerifyOtp after max wrong codes" do
    travel_to(Time.utc(2026, 3, 10)) { lock_out!(issue("login")) }
    travel_to(Time.utc(2026, 4, 10)) { lock_out!(issue("registration")) }

    values = series(execute("otp_challenges.failed_over_time", **WINDOW))

    assert_equal 1, values["2026-03-01"]
    assert_equal 1, values["2026-04-01"]
  end

  test "does not count verified, superseded, expired, or below-limit challenges" do
    travel_to(Time.utc(2026, 3, 10)) do
      verified = issue("login", code: "123456")
      verify(verified, "123456")

      wrong_once = issue("login")
      verify(wrong_once, "000000")

      superseded = issue("login")
      verify(superseded, "000000")
      RecordingStudioUser::Services::IssueOtp.call(user: superseded.user, purpose: "login")
      assert superseded.reload.revoked?

      issue("registration")
    end

    values = travel_to(Time.utc(2026, 4, 20)) { series(execute("otp_challenges.failed_over_time", **WINDOW)) }

    assert_equal 0, values["2026-03-01"]
    assert_equal 0, values["2026-04-01"]
  end

  test "group_by purpose folds groups under five into other" do
    travel_to(Time.utc(2026, 3, 10)) do
      5.times { lock_out!(issue("login")) }
      2.times { lock_out!(issue("registration")) }
    end

    result = execute("otp_challenges.failed_over_time", group_by: "purpose", **WINDOW)

    assert_equal 7, series(result)["2026-03-01"]
    assert_equal :purpose, result.group_by
    assert_equal ["login"], result.groups.map { |group| group[:key] }
    assert_equal 5, series_data(result.groups.first[:data])["2026-03-01"]
    assert_equal 1, result.other[:groups]
    assert_equal 2, series_data(result.other[:data])["2026-03-01"]
  end

  test "rejects group_by on private fields" do
    %w[user_id code_digest].each do |field|
      assert_raises(RecordingStudioMetrics::Errors::InvalidGroupBy) do
        execute("otp_challenges.failed_over_time", group_by: field, **WINDOW)
      end
    end
  end

  test "discovery hides the metric from denied callers and shows it to AdminRoot viewers" do
    denied = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
    refute_includes denied.fetch(:metrics).map { |row| row[:identifier] }, "otp_challenges.failed_over_time"

    bootstrap_owner_access!(@actor, @admin_recording)
    allowed = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
    row = allowed.fetch(:metrics).find { |metric| metric[:identifier] == "otp_challenges.failed_over_time" }

    assert row
    assert_equal "count", row[:unit]
    assert_equal [:purpose], row[:group_by]
  end

  private

  def issue(purpose, code: RecordingStudioUser::OtpChallenge.generate_code)
    user = create_user("otp-metrics-#{SecureRandom.hex(4)}@example.com")
    RecordingStudioUser::OtpChallenge.issue_for!(user: user, purpose: purpose, code: code)
  end

  def verify(challenge, code)
    RecordingStudioUser::Services::VerifyOtp.call(
      challenge_id: challenge.id,
      code: code,
      purpose: challenge.purpose,
      session: { otp_challenge_id: challenge.id, otp_purpose: challenge.purpose }
    )
  end

  def lock_out!(challenge)
    RecordingStudioUser.config.otp_max_attempts.times do
      code = challenge.verify_code!("000000") ? "999999" : "000000"
      verify(challenge, code)
    end
    assert challenge.reload.revoked?
  end

  def execute(identifier, **params)
    RecordingStudioMetrics.execute(identifier, context: site_context, **params)
  end

  def series(result)
    series_data(result.data)
  end

  def series_data(data)
    data.to_h { |row| [row[:date], row[:value]] }
  end

  def site_context
    RecordingStudioMetrics::Context.new(actor: @actor, scope: :site, site_authorized: true, timezone: "UTC")
  end

  def build_api_context(actor)
    grant = Struct.new(:actor).new(actor)
    params = { resource: nil, name: nil, interval: nil, start: nil, start_at: nil, end: nil, end_at: nil,
               timezone: "UTC", filters: {} }
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }
    context.define_singleton_method(:api_client) { actor }
    context.define_singleton_method(:access_recording) { nil }
    context.define_singleton_method(:root_recording) { nil }
    context.define_singleton_method(:api_key) { :operations }
    context.define_singleton_method(:params) { params }
    context
  end

  def create_user(email)
    user = User.new(email: email, password: "Password123!", password_confirmation: "Password123!",
                    registered_with: "password")
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    user.save!
    user
  end
end
