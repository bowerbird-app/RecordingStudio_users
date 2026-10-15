# frozen_string_literal: true

require "test_helper"

class ApiMetricsTest < Minitest::Test
  def test_register_is_a_noop_without_the_api_constant
    skip "RecordingStudioApi is already loaded" if Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudioUser::Api::Metrics.register!
  end

  def test_register_is_a_noop_without_actor_metrics
    with_api(actor_metrics: false) do |calls|
      RecordingStudioApi.register_recordable_type_api("Probe", api: :operations)

      assert_nil RecordingStudioUser::Api::Metrics.register!
      assert_equal [{ args: ["Probe"], kwargs: { api: :operations } }], calls[:recordable]
      assert_equal [], calls[:actor]
    end
  end

  def test_register_records_each_actor_metrics_call
    with_api(actor_metrics: true) do |calls|
      with_user_class do
        2.times { RecordingStudioUser::Api::Metrics.register! }
      end

      authorize = RecordingStudioUser::Api::Access.method(:authorize_view!)
      assert_equal [
        { type_name: "User", api: :operations, resource: :users, authorize: authorize },
        { type_name: "User", api: :operations, resource: :users, authorize: authorize }
      ], calls[:actor]
      assert_equal [], calls[:recordable]
    end
  end

  def test_register_body_does_not_call_recordable_type_api
    source = File.read(File.expand_path("../lib/recording_studio_user/api/metrics.rb", __dir__))
    body = source[/def register!\n(.*?)def actor_metrics_supported\?/m, 1].gsub(/#[^\n]*/, "")

    assert_includes body, "register_actor_metrics"
    refute_includes body, "register_recordable_type_api"
  end

  private

  def with_api(actor_metrics:, &)
    if Object.const_defined?(:RecordingStudioApi, false)
      with_loaded_api(actor_metrics: actor_metrics, &)
    else
      with_fake_api(actor_metrics: actor_metrics, &)
    end
  end

  def with_fake_api(actor_metrics:)
    calls = { actor: [], recordable: [] }
    api = Module.new
    install_api_methods(api.singleton_class, calls, actor_metrics: actor_metrics)
    Object.const_set(:RecordingStudioApi, api)
    yield calls
  ensure
    if defined?(api) && api && Object.const_defined?(:RecordingStudioApi, false) && RecordingStudioApi.equal?(api)
      Object.send(:remove_const, :RecordingStudioApi)
    end
  end

  def with_loaded_api(actor_metrics:)
    calls = { actor: [], recordable: [] }
    singleton = RecordingStudioApi.singleton_class
    replaced = install_api_methods(singleton, calls, actor_metrics: actor_metrics)
    yield calls
  ensure
    restore_singleton_methods(singleton, replaced) if defined?(replaced) && replaced
  end

  def install_api_methods(singleton, calls, actor_metrics:)
    replaced = {}
    define_singleton_method(singleton, replaced, :respond_to?) do |name, include_all = false|
      case name.to_sym
      when :register_actor_metrics
        actor_metrics
      when :register_endpoint, :register_recordable_type_api
        true
      else
        replaced.fetch(:respond_to?).bind_call(self, name, include_all)
      end
    end
    define_singleton_method(singleton, replaced, :register_endpoint) { |*| }
    define_singleton_method(singleton, replaced, :register_recordable_type_api) do |*args, **kwargs|
      calls[:recordable] << { args: args, kwargs: kwargs }
    end
    define_singleton_method(singleton, replaced, :register_actor_metrics) do |type_name, **options|
      calls[:actor] << {
        type_name: type_name,
        api: options.fetch(:api),
        resource: options.fetch(:resource),
        authorize: options.fetch(:authorize)
      }
    end
    replaced
  end

  def define_singleton_method(singleton, replaced, name, &implementation)
    verbose = $VERBOSE
    exists = singleton.method_defined?(name) || singleton.private_method_defined?(name)
    replaced[name] = exists ? singleton.instance_method(name) : nil
    $VERBOSE = nil
    singleton.define_method(name, implementation)
  ensure
    $VERBOSE = verbose
  end

  def restore_singleton_methods(singleton, replaced)
    verbose = $VERBOSE
    $VERBOSE = nil
    replaced.each do |name, original|
      if original
        singleton.define_method(name, original)
      elsif singleton.method_defined?(name) || singleton.private_method_defined?(name)
        singleton.send(:remove_method, name)
      end
    end
  ensure
    $VERBOSE = verbose
  end

  def with_user_class
    created = false
    unless Object.const_defined?(:User, false)
      Object.const_set(:User, Class.new)
      created = true
    end
    yield
  ensure
    Object.send(:remove_const, :User) if created
  end
end
