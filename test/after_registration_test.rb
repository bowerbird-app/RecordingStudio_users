# frozen_string_literal: true

require "test_helper"
require "active_record"
require "active_support/notifications"
require "active_support/testing/assertions"
require "active_support/testing/error_reporter_assertions"
require "logger"
require "stringio"

class AfterRegistrationTest < Minitest::Test
  include ActiveSupport::Testing::Assertions
  include ActiveSupport::Testing::ErrorReporterAssertions

  class FakeUser
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  class RecordingHandler
    class << self
      attr_accessor :calls

      def call(**kwargs)
        self.calls ||= []
        calls << kwargs
        :ok
      end
    end
  end

  class BoomHandler
    def self.call(**)
      raise StandardError, "boom from class hook"
    end
  end

  def setup
    @original_config = RecordingStudioUser.instance_variable_get(:@config)
    @config = RecordingStudioUser::Configuration.new
    RecordingStudioUser.instance_variable_set(:@config, @config)

    @user = FakeUser.new("user-1")
    user = @user
    user_class = Class.new do
      define_singleton_method(:find_by) do |id:|
        user if user.id == id
      end
    end
    @config.define_singleton_method(:user_class) { user_class }

    RecordingHandler.calls = []
    @log_io = StringIO.new
    @original_logger = Rails.logger if defined?(Rails)
    Rails.logger = Logger.new(@log_io)
  end

  def teardown
    RecordingStudioUser.instance_variable_set(:@config, @original_config)
    Rails.logger = @original_logger if defined?(Rails)
  end

  def test_run_invokes_lambda_with_user_and_method
    seen = []
    @config.after_registration ->(user:, method:) { seen << [user.id, method] }

    RecordingStudioUser::AfterRegistration.run!(user_id: @user.id, method: :password)

    assert_equal [[@user.id, :password]], seen
  end

  def test_run_resolves_string_class_name
    @config.after_registration "AfterRegistrationTest::RecordingHandler"

    RecordingStudioUser::AfterRegistration.run!(user_id: @user.id, method: :oauth)

    assert_equal [{ user: @user, method: :oauth }], RecordingHandler.calls
  end

  def test_multiple_hooks_run_in_order
    order = []
    @config.after_registration ->(user:, method:) { order << [user.id, :first, method] }
    @config.after_registration ->(user:, method:) { order << [user.id, :second, method] }

    RecordingStudioUser::AfterRegistration.run!(user_id: @user.id, method: :otp)

    assert_equal [[@user.id, :first, :otp], [@user.id, :second, :otp]], order
  end

  def test_hook_error_is_logged_and_reported_without_stopping_others
    order = []
    @config.after_registration(lambda { |user:, method:|
      raise StandardError, "first failed for #{user.id} via #{method}"
    })
    @config.after_registration ->(user:, method:) { order << [user.id, method] }

    report = assert_error_reported(StandardError) do
      RecordingStudioUser::AfterRegistration.run!(user_id: @user.id, method: :password)
    end

    assert_equal "first failed for #{@user.id} via password", report.error.message
    assert_predicate report, :handled?
    assert_equal [[@user.id, :password]], order
    assert_match(/after_registration hook failed/, @log_io.string)
    assert_match(/first failed/, @log_io.string)
  end

  def test_string_class_hook_error_is_isolated
    order = []
    @config.after_registration "AfterRegistrationTest::BoomHandler"
    @config.after_registration ->(user:, method:) { order << [user.id, method] }

    assert_error_reported(StandardError) do
      RecordingStudioUser::AfterRegistration.run!(user_id: @user.id, method: :oauth)
    end

    assert_equal [[@user.id, :oauth]], order
    assert_match(/boom from class hook/, @log_io.string)
  end

  def test_missing_user_skips_hooks
    called = []
    @config.after_registration ->(user:, method:) { called << [user.id, method] }

    assert_no_error_reported do
      RecordingStudioUser::AfterRegistration.run!(user_id: "missing", method: :password)
    end

    assert_empty called
  end

  def test_emit_runs_hooks_after_event_without_changing_payload
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(
      RecordingStudioUser::RegistrationCompleted::EVENT
    ) do |_name, _start, _finish, _id, payload|
      events << payload
    end

    seen = []
    @config.after_registration ->(user:, method:) { seen << [user.id, method] }

    RecordingStudioUser::RegistrationCompleted.emit!(user_id: @user.id, method: :password)

    assert_equal [{ user_id: @user.id, method: :password }], events
    assert_equal [[@user.id, :password]], seen
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
