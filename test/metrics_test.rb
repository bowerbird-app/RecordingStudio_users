# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  def test_confirmable_column_is_false_when_missing
    user_class = Class.new do
      def self.column_names
        %w[id email created_at registered_with]
      end

      def self.table_exists?
        true
      end
    end

    refute RecordingStudioUser::Metrics.confirmable_column?(user_class)
  end

  def test_confirmable_column_is_false_when_table_is_missing
    user_class = Class.new do
      def self.table_exists?
        false
      end

      def self.column_names
        raise "do not read columns"
      end
    end

    refute RecordingStudioUser::Metrics.confirmable_column?(user_class)
  end

  def test_confirmable_column_is_true_when_present
    user_class = Class.new do
      def self.column_names
        %w[id confirmed_at]
      end

      def self.table_exists?
        true
      end
    end

    assert RecordingStudioUser::Metrics.confirmable_column?(user_class)
  end

  def test_define_confirmation_skips_without_confirmed_at
    user_class = Class.new do
      def self.column_names
        %w[id email]
      end

      def self.table_exists?
        true
      end
    end
    called = false
    dsl = Object.new
    dsl.define_singleton_method(:custom) { |*| called = true }

    RecordingStudioUser::Metrics.define_confirmation(dsl, user_class)

    refute called

    totals = []
    core = Object.new
    core.define_singleton_method(:count) { |id, **| totals << id }
    core.define_singleton_method(:timeseries) { |*| }
    core.define_singleton_method(:breakdown) { |*| }
    RecordingStudioUser::Metrics.define_core(core)

    assert_includes totals, :total
  end

  def test_metric_descriptions_omit_admin_area_access
    descriptions = [
      RecordingStudioUser::Metrics::TOTAL,
      RecordingStudioUser::Metrics::SIGNUPS,
      RecordingStudioUser::Metrics::TOTAL_OVER_TIME,
      RecordingStudioUser::Metrics::BY_METHOD,
      RecordingStudioUser::Metrics::CONFIRMATION,
      RecordingStudioUser::Metrics::OTP_FAILED
    ]

    descriptions.each do |description|
      refute_empty description
      refute_includes description, "view access to the admin area"
      refute_includes description, "edit access to the admin area"
    end
    refute defined?(RecordingStudioUser::Metrics::VIEW)
  end

  def test_access_can_view_is_false_without_actor_or_admin_root
    context = Object.new
    def context.access_grant
      nil
    end

    refute RecordingStudioUser::Api::Access.can_view?(context)
  end

  def test_can_view_is_false_when_admin_root_resolver_raises
    with_admin_root_resolver(lambda { |context: nil|
      raise NoMethodError, "undefined method `current_user' for nil: #{context.inspect}"
    }) do
      assert_nil RecordingStudioUser::Api::Access.admin_root_recording
      refute RecordingStudioUser::Api::Access.can_view?(metrics_view_context)
    end
  end

  def test_can_view_is_false_when_admin_root_resolver_returns_nil
    with_admin_root_resolver(->(**) {}) do
      assert_nil RecordingStudioUser::Api::Access.admin_root_recording
      refute RecordingStudioUser::Api::Access.can_view?(metrics_view_context)
    end
  end

  def test_can_view_is_false_when_admin_root_is_not_a_recording
    with_admin_root_resolver(->(**) { Object.new }) do
      assert_nil RecordingStudioUser::Api::Access.admin_root_recording
      refute RecordingStudioUser::Api::Access.can_view?(metrics_view_context)
    end
  end

  private

  def metrics_view_context
    context = Object.new
    def context.access_grant
      grant = Object.new
      def grant.actor
        "metrics-actor"
      end
      grant
    end
    context
  end

  def with_admin_root_resolver(resolver)
    config = RecordingStudioAccessible.configuration
    original = config.admin_root_resolver
    config.admin_root_resolver = resolver
    yield
  ensure
    config.admin_root_resolver = original
  end
end
