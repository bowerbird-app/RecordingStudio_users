# frozen_string_literal: true

require "test_helper"

class ApiTest < Minitest::Test
  class CountedUsers
    class << self
      attr_accessor :total

      def count
        total
      end
    end
  end

  def setup
    CountedUsers.total = 0
  end

  def teardown
    restore_user_class_name
    remove_test_recording_studio_api!
  end

  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)
    assert_nil RecordingStudioUser::Api.register!
  end

  def test_gemspec_omits_recording_studio_api_dependency
    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))

    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
  end

  def test_engine_registers_api_when_present
    engine = File.read(File.expand_path("../lib/recording_studio_user/engine.rb", __dir__))
    registration = File.read(File.expand_path("../lib/recording_studio_user/api/registration.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_user.api"'
    assert_includes engine, "RecordingStudioUser::Api.register!"
    assert_includes registration, "RecordingStudioApi.register_endpoint"
    assert_includes registration, "api: USER_COUNT_API"
    assert_includes registration, "path: USER_COUNT_PATH"
    assert_includes registration, "handler: UserCount"
    assert_includes registration, "return unless RecordingStudioApi.respond_to?(:register_endpoint)"
  end

  def test_user_count_endpoint_is_registered_on_operations_when_api_present
    api = install_test_recording_studio_api!

    assert RecordingStudioUser::Api.register!

    registration = only_registration(api)
    assert_equal :user_count, registration.fetch(:name)
    assert_equal :operations, registration.fetch(:api)
    assert_equal :get, registration.fetch(:http_verb)
    assert_equal "users/count", registration.fetch(:path)
    assert_equal RecordingStudioUser::Api::UserCount, registration.fetch(:handler)
    assert_equal :user_count, RecordingStudioUser::Api::USER_COUNT_ENDPOINT
    assert_equal "users/count", RecordingStudioUser::Api::USER_COUNT_PATH
    assert_equal :operations, RecordingStudioUser::Api::USER_COUNT_API
  end

  def test_user_count_registration_is_idempotent
    api = install_test_recording_studio_api!

    2.times { RecordingStudioUser::Api.register! }

    assert_equal 1, api.registrations.size
  end

  def test_user_count_returns_the_configured_user_class_count
    CountedUsers.total = 4
    with_user_class_name("ApiTest::CountedUsers") do
      assert_equal({ count: 4 }, RecordingStudioUser::Api::UserCount.call(nil))

      CountedUsers.total = 9
      assert_equal({ count: 9 }, RecordingStudioUser::Api::UserCount.call(nil))
    end
  end

  def test_registered_handler_uses_the_configured_user_class
    api = install_test_recording_studio_api!
    CountedUsers.total = 6
    with_user_class_name("ApiTest::CountedUsers") do
      RecordingStudioUser::Api.register!

      assert_equal({ count: 6 }, only_registration(api).fetch(:handler).call(nil))
    end
  end

  private

  def only_registration(api)
    assert_equal 1, Array(api.registrations).size
    api.registrations.first
  end

  def with_user_class_name(name)
    config = RecordingStudioUser.config
    @previous_user_class_name = config.user_class_name
    config.user_class_name = name
    yield
  ensure
    restore_user_class_name
  end

  def restore_user_class_name
    return unless defined?(@previous_user_class_name) && @previous_user_class_name

    RecordingStudioUser.config.user_class_name = @previous_user_class_name
    @previous_user_class_name = nil
  end

  def install_test_recording_studio_api!
    remove_test_recording_studio_api!
    refute Object.const_defined?(:RecordingStudioApi, false)

    api = Module.new do
      class << self
        attr_accessor :registrations

        def register_endpoint(name, **options)
          self.registrations ||= []
          registrations << { name: name, **options }
        end

        def registered_endpoint(name, api: :public)
          Array(registrations).find { |entry| entry[:name] == name && entry.fetch(:api, :public) == api }
        end
      end
    end
    Object.const_set(:RecordingStudioApi, api)
    @test_recording_studio_api = api
  end

  def remove_test_recording_studio_api!
    return unless defined?(@test_recording_studio_api) && @test_recording_studio_api
    return unless Object.const_defined?(:RecordingStudioApi, false)
    return unless RecordingStudioApi.equal?(@test_recording_studio_api)

    Object.send(:remove_const, :RecordingStudioApi)
    @test_recording_studio_api = nil
  end
end
