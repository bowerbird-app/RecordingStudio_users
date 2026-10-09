# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  def test_engine_registers_metrics_without_calling_metrics_api_register
    engine = File.read(File.expand_path("../lib/recording_studio_user/engine.rb", __dir__))
    metrics = File.read(File.expand_path("../lib/recording_studio_user/metrics.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_user.metrics"'
    assert_includes engine, "RecordingStudioUser::Metrics.register!"
    refute_includes engine, "RecordingStudioMetrics::Api.register!"
    refute_includes metrics, "RecordingStudioMetrics::Api.register!"
    assert_includes metrics, "blast_radius: :site"
    assert_includes metrics, "RecordingStudioUser::Api::Access.can_view?"
    assert_includes metrics, "expose: { api: [API] }"
    assert_includes metrics, 'title: "Total users"'
    assert_includes metrics, 'title: "Signups over time"'
    assert_includes metrics, 'title: "Total users over time"'
    assert_includes metrics, 'semantics: "population_at_end_of_period"'
    assert_includes metrics, 'title: "Signups by method"'
    assert_includes metrics, "field: :registered_with"
    assert_includes metrics, 'title: "Confirmed vs unconfirmed"'
  end

  def test_gemspec_depends_on_metrics
    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_metrics", "~> 0.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics"'
    assert_includes gemfile, 'tag: "v0.2.0"'
    assert_includes dummy, 'github: "bowerbird-app/RecordingStudio_metrics"'
    assert_includes dummy, 'tag: "v0.2.0"'

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.2.0"
      assert_includes lock, "recording_studio_metrics (0.2.0)"
      assert_includes lock, "6e02b6b75a8a9dad2bd80c6ba2d30f7444e67b9e"
    end
  end

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

  def test_access_can_view_is_false_without_actor_or_admin_root
    context = Object.new
    def context.access_grant
      nil
    end

    refute RecordingStudioUser::Api::Access.can_view?(context)
  end
end
