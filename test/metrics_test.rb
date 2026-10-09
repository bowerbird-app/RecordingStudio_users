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

  def test_access_can_view_is_false_without_actor_or_admin_root
    context = Object.new
    def context.access_grant
      nil
    end

    refute RecordingStudioUser::Api::Access.can_view?(context)
  end

  def test_site_admin_resolver_is_preferred_when_set
    site_recording = Object.new
    access_called = false

    with_admin_recording_resolvers(
      site: lambda do |context|
        assert_nil context.controller
        site_recording
      end,
      access: lambda do |_context|
        access_called = true
        Object.new
      end
    ) do
      assert_same site_recording, RecordingStudioUser::Api::Access.admin_root_recording
    end

    refute access_called
  end

  def test_access_resolver_is_used_when_site_resolver_is_unset
    access_recording = Object.new

    with_admin_recording_resolvers(
      site: nil,
      access: lambda do |context|
        assert_nil context.controller
        access_recording
      end
    ) do
      assert_same access_recording, RecordingStudioUser::Api::Access.admin_root_recording
    end
  end

  def test_can_view_is_false_when_admin_root_resolver_raises
    access_called = false

    with_admin_recording_resolvers(
      site: lambda do |_context|
        raise NoMethodError, "undefined method `current_user' for nil"
      end,
      access: lambda do |_context|
        access_called = true
        Object.new
      end
    ) do
      refute RecordingStudioUser::Api::Access.can_view?(metrics_view_context)
    end

    refute access_called
  end

  def test_can_view_is_false_when_admin_root_resolver_returns_nil
    access_called = false

    with_admin_recording_resolvers(
      site: ->(_context) {},
      access: lambda do |_context|
        access_called = true
        Object.new
      end
    ) do
      refute RecordingStudioUser::Api::Access.can_view?(metrics_view_context)
    end

    refute access_called
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

  def with_admin_recording_resolvers(site:, access:)
    config = RecordingStudioAdmin.configuration
    original_site = config.site_admin_recording_resolver
    original_access = config.access_recording_resolver
    config.site_admin_recording_resolver = site
    config.access_recording_resolver = access
    yield
  ensure
    config.site_admin_recording_resolver = original_site
    config.access_recording_resolver = original_access
  end
end
