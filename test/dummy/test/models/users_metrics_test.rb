# frozen_string_literal: true

require "test_helper"

class UsersMetricsTest < ActiveSupport::TestCase
  include AccessGrantTestHelper

  setup do
    @actor = create_user("metrics-actor-#{SecureRandom.hex(4)}@example.com")
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    RecordingStudioUser::Metrics.register!
  end

  test "registers the users metrics on the operations API" do
    identifiers = RecordingStudioMetrics.for_resource(:users).map(&:identifier)

    assert_includes identifiers, "users.total"
    assert_includes identifiers, "users.signups"
    assert_includes identifiers, "users.total_over_time"
    assert_includes identifiers, "users.by_method"
    assert_includes identifiers, "users.confirmation"

    assert_equal "Total users", RecordingStudioMetrics.find("users.total").title
    assert_equal "Signups over time", RecordingStudioMetrics.find("users.signups").title
    assert_equal "Total users over time", RecordingStudioMetrics.find("users.total_over_time").title
    assert_equal "population_at_end_of_period", RecordingStudioMetrics.find("users.total_over_time").semantics
    assert_equal "Signups by method", RecordingStudioMetrics.find("users.by_method").title
    assert_equal "Confirmed vs unconfirmed", RecordingStudioMetrics.find("users.confirmation").title

    RecordingStudioMetrics.for_resource(:users).each do |definition|
      assert_equal [:operations], definition.exposed_apis
      assert_equal :site, definition.blast_radius
    end
  end

  test "total users counts everyone across more than one page" do
    before = User.count
    51.times { |index| create_user("metrics-page-#{index}-#{SecureRandom.hex(4)}@example.com") }

    result = execute("users.total")

    assert_equal before + 51, result.value
    assert_equal User.count, result.value
    assert_operator result.value, :>, 50
  end

  test "signups over time count created_at in the window" do
    travel_to Time.utc(2026, 3, 10, 12) do
      create_user("signup-old-#{SecureRandom.hex(4)}@example.com")
    end
    travel_to Time.utc(2026, 4, 2, 12) do
      create_user("signup-new-#{SecureRandom.hex(4)}@example.com")
    end

    result = execute(
      "users.signups",
      interval: :month,
      start_at: Time.utc(2026, 3, 1),
      end_at: Time.utc(2026, 5, 1)
    )

    values = result.data.to_h { |row| [row[:date], row[:value]] }
    assert_equal 1, values["2026-03-01"]
    assert_equal 1, values["2026-04-01"]
    assert_equal "records_created_during_period", result.metadata[:semantics]
  end

  test "total users over time is population at end of period" do
    travel_to Time.utc(2026, 1, 15) do
      create_user("pop-jan-#{SecureRandom.hex(4)}@example.com")
    end
    travel_to Time.utc(2026, 2, 15) do
      create_user("pop-feb-#{SecureRandom.hex(4)}@example.com")
    end

    before_jan = User.where("created_at < ?", Time.utc(2026, 1, 1)).count

    result = execute(
      "users.total_over_time",
      interval: :month,
      start_at: Time.utc(2026, 1, 1),
      end_at: Time.utc(2026, 3, 1)
    )

    values = result.data.to_h { |row| [row[:date], row[:value]] }
    assert_equal before_jan + 1, values["2026-01-01"]
    assert_equal before_jan + 2, values["2026-02-01"]
    assert_equal "population_at_end_of_period", result.metadata[:semantics]
  end

  test "signups by method breakdown uses registered_with" do
    create_user("method-password-#{SecureRandom.hex(4)}@example.com", registered_with: "password")
    create_otp_user("method-otp-#{SecureRandom.hex(4)}@example.com")

    result = execute("users.by_method")
    counts = result.data.to_h { |row| [row[:key].to_s, row[:value]] }

    assert_equal User.where(registered_with: "password").count, counts["password"]
    assert_equal User.where(registered_with: "otp").count, counts["otp"]
  end

  test "confirmed vs unconfirmed splits on confirmed_at" do
    confirmed = create_user("confirmed-#{SecureRandom.hex(4)}@example.com")
    unconfirmed = create_unconfirmed_user("unconfirmed-#{SecureRandom.hex(4)}@example.com")

    result = execute("users.confirmation")
    counts = result.data.to_h { |row| [row[:key].to_s, row[:value]] }

    assert_operator counts["confirmed"], :>=, 1
    assert_operator counts["unconfirmed"], :>=, 1
    assert_equal User.where.not(confirmed_at: nil).count, counts["confirmed"]
    assert_equal User.where(confirmed_at: nil).count, counts["unconfirmed"]
    assert confirmed.confirmed_at.present?
    assert_nil unconfirmed.confirmed_at
  end

  test "skips confirmation when confirmed_at is missing" do
    user_class = User
    original = user_class.method(:column_names)
    user_class.define_singleton_method(:column_names) { original.call - ["confirmed_at"] }

    RecordingStudioMetrics.registry.reset!
    RecordingStudioUser::Metrics.register!

    identifiers = RecordingStudioMetrics.for_resource(:users).map(&:identifier)
    refute_includes identifiers, "users.confirmation"
    assert_includes identifiers, "users.total"
  ensure
    user_class.define_singleton_method(:column_names, original)
    RecordingStudioMetrics.registry.reset!
    RecordingStudioUser::Metrics.register!
  end

  test "execute handler returns the value when access allows" do
    bootstrap_owner_access!(@actor, @admin_recording)

    payload = RecordingStudioMetrics::Api::ExecuteHandler.call(build_api_context(@actor))

    assert_equal "users.total", payload[:metric]
    assert_equal User.count, payload[:value]
  end

  test "execute handler is 403 when access denies" do
    error = assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
      RecordingStudioMetrics::Api::ExecuteHandler.call(build_api_context(@actor))
    end

    assert_match(/not authorized/i, error.message)
  end

  test "discovery hides metrics from denied callers" do
    denied = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
    denied_ids = denied.fetch(:metrics).map { |row| row[:identifier] }
    refute_includes denied_ids, "users.total"

    bootstrap_owner_access!(@actor, @admin_recording)
    allowed = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
    allowed_ids = allowed.fetch(:metrics).map { |row| row[:identifier] }

    assert_includes allowed_ids, "users.total"
  end

  private

  def execute(identifier, **params)
    RecordingStudioMetrics.execute(
      identifier,
      context: site_context,
      **params
    )
  end

  def site_context
    RecordingStudioMetrics::Context.new(
      actor: @actor,
      scope: :site,
      site_authorized: true,
      timezone: "UTC"
    )
  end

  def build_api_context(actor)
    grant = Struct.new(:actor).new(actor)
    params = { resource: "users", name: "total", interval: nil, start: nil, start_at: nil, end: nil, end_at: nil, timezone: "UTC", filters: {} }
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }
    context.define_singleton_method(:api_client) { actor }
    context.define_singleton_method(:access_recording) { nil }
    context.define_singleton_method(:root_recording) { nil }
    context.define_singleton_method(:api_key) { :operations }
    context.define_singleton_method(:params) { params }
    context
  end

  def create_user(email, registered_with: "password")
    user = User.new(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!",
      registered_with: registered_with
    )
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    user.save!
    user
  end

  def create_otp_user(email)
    user = RecordingStudioUser.create_unconfirmed_user!(email: email)
    user.confirm if user.respond_to?(:confirm)
    user
  end

  def create_unconfirmed_user(email)
    RecordingStudioUser.create_unconfirmed_user!(email: email)
  end
end
