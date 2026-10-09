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
end
