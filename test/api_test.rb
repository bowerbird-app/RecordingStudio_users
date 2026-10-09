# frozen_string_literal: true

require "test_helper"

class ApiTest < Minitest::Test
  module ApiAccessOverride
    def authorized_on_admin_root?(context, role)
      result = authorization_result
      return super if result.nil?

      result.call(context, role)
    end

    attr_accessor :authorization_result
  end

  class CountedUsers
    class << self
      attr_accessor :total

      def count
        total
      end
    end
  end

  class FakeGrant
    def initialize(actor)
      @actor = actor
    end

    attr_reader :actor
  end

  class FakeContext
    def initialize(actor:, params: {})
      @access_grant = FakeGrant.new(actor)
      @params = params
    end

    attr_reader :access_grant, :params
  end

  def setup
    CountedUsers.total = 0
    @authorize_admin_root = true
    access = RecordingStudioUser::Api::Access
    unless access.singleton_class.ancestors.include?(ApiAccessOverride)
      access.singleton_class.prepend(ApiAccessOverride)
    end
    access.authorization_result = ->(_context, _role) { @authorize_admin_root }
  end

  def teardown
    RecordingStudioUser::Api::Access.authorization_result = nil
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
    assert_includes registration, "handler: Index"
    assert_includes registration, "handler: Create"
    assert_includes registration, "handler: Show"
    assert_includes registration, "handler: Update"
    assert_includes registration, "api: USER_COUNT_API"
    refute_includes registration, "OPERATIONS_API"
    refute_includes registration, "api: :public"
    refute_includes registration, "http_verb: :delete"
  end

  def test_user_count_endpoint_is_registered_on_operations_when_api_present
    api = install_test_recording_studio_api!

    assert RecordingStudioUser::Api.register!

    registration = user_count_registration(api)
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

    names = api.registrations.map { |entry| entry.fetch(:name) }
    assert_equal 1, names.count(:user_count)
    assert_equal %i[user_count users users_create users_show users_update], names
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

      assert_equal({ count: 6 }, user_count_registration(api).fetch(:handler).call(nil))
    end
  end

  def test_users_endpoints_register_on_operations_not_public
    api = install_test_recording_studio_api!

    RecordingStudioUser::Api.register!

    names = api.registrations.map { |entry| entry.fetch(:name) }
    assert_equal %i[user_count users users_create users_show users_update], names
    assert(api.registrations.all? { |entry| entry.fetch(:api) == :operations })
    refute(api.registrations.any? { |entry| entry.fetch(:http_verb) == :delete })

    index = registration_named(api, :users)
    assert_equal :get, index.fetch(:http_verb)
    assert_equal "users", index.fetch(:path)

    create = registration_named(api, :users_create)
    assert_equal :post, create.fetch(:http_verb)
    assert_equal "users", create.fetch(:path)

    show = registration_named(api, :users_show)
    assert_equal :get, show.fetch(:http_verb)
    assert_equal "users/:id", show.fetch(:path)

    update = registration_named(api, :users_update)
    assert_equal :patch, update.fetch(:http_verb)
    assert_equal "users/:id", update.fetch(:path)
  end

  def test_serialize_omits_secrets_and_lists_identity_providers
    identity = Struct.new(:provider).new("google_oauth2")
    user = Struct.new(
      :id, :email, :confirmed_at, :created_at, :updated_at, :registered_with, :identities, :encrypted_password
    ).new(
      "user-1",
      "ada@example.com",
      Time.utc(2026, 1, 2, 3, 4, 5),
      Time.utc(2026, 1, 1, 0, 0, 0),
      Time.utc(2026, 1, 3, 0, 0, 0),
      "otp",
      [identity],
      "DIGEST"
    )
    payload = without_profile_lookup { RecordingStudioUser::Api::Serialize.user(user) }

    assert_equal "user-1", payload.fetch(:id)
    assert_equal "ada@example.com", payload.fetch(:email)
    assert_equal "otp", payload.fetch(:registered_with)
    assert_equal ["google_oauth2"], payload.fetch(:identity_providers)
    assert_equal({}, payload.fetch(:additional_profile_attributes))
    refute payload.key?(:encrypted_password)
    refute payload.key?(:password)
    refute payload.key?(:reset_password_token)
    refute payload.key?(:confirmation_token)
    refute payload.key?(:otp_secret)
  end

  def test_access_uses_admin_root_view_and_edit_roles
    access = File.read(File.expand_path("../lib/recording_studio_user/api/access.rb", __dir__))

    assert_includes access, "authorized_on_admin_root?(context, :edit)"
    assert_includes access, "authorized_on_admin_root?(context, :view)"
    assert_includes access, "RecordingStudioAccessible.authorized?"
    refute_includes access, "class_eval"
    refute_includes access, ".prepend"
  end

  def test_params_slice_writable_fields_and_top_level_extras
    context = FakeContext.new(
      actor: :staff,
      params: {
        email: "ada@example.com",
        password: "secret",
        first_name: "Ada",
        locale: "fr",
        admin: true,
        encrypted_password: "nope"
      }
    )
    attributes = RecordingStudioUser::Api::Params.create_attributes(context)

    assert_equal "ada@example.com", attributes[:email]
    assert_equal "secret", attributes[:password]
    assert_equal "Ada", attributes[:first_name]
    assert_equal({ locale: "fr" }, attributes[:additional_profile_attributes])
    refute attributes.key?(:admin)
    refute attributes.key?(:encrypted_password)
  end

  def test_update_attributes_reject_email
    context = FakeContext.new(
      actor: :staff,
      params: { id: "user-1", email: "new@example.com", first_name: "Ada" }
    )
    error = with_api_errors do
      assert_raises(RecordingStudioApi::InvalidActionInputError) do
        RecordingStudioUser::Api::Params.update_attributes(context)
      end
    end
    assert_match(/email cannot be changed/, error.message)
  end

  def test_update_attributes_allow_profile_fields_without_email
    context = FakeContext.new(actor: :staff, params: { id: "user-1", first_name: "Ada", locale: "fr" })
    attributes = RecordingStudioUser::Api::Params.update_attributes(context)

    assert_equal "Ada", attributes[:first_name]
    assert_equal({ locale: "fr" }, attributes[:additional_profile_attributes])
    refute attributes.key?(:email)
    refute attributes.key?(:password)
  end

  def test_query_normalizes_page_and_per_page
    assert_equal 1, RecordingStudioUser::Api::Query.normalize_page(nil)
    assert_equal 1, RecordingStudioUser::Api::Query.normalize_page(0)
    assert_equal 3, RecordingStudioUser::Api::Query.normalize_page(3)
    assert_equal 50, RecordingStudioUser::Api::Query.normalize_per_page(nil)
    assert_equal 50, RecordingStudioUser::Api::Query.normalize_per_page(0)
    assert_equal 10, RecordingStudioUser::Api::Query.normalize_per_page(10)
    assert_equal 100, RecordingStudioUser::Api::Query.normalize_per_page(500)
  end

  def test_operations_list_orders_like_the_admin_screen
    admin = File.read(File.expand_path("../lib/recording_studio_user/admin.rb", __dir__))
    index = File.read(File.expand_path("../lib/recording_studio_user/api/index.rb", __dir__))

    assert_includes admin, "config.user_class.order(created_at: :desc)"
    assert_includes index, "config.user_class.order(created_at: :desc)"
    refute_includes index, "ordered_users"
    refute_includes index, "search_term"
    refute_includes admin, "paginate per_page"
    refute_includes File.read(File.expand_path("../lib/recording_studio_user/api/query.rb", __dir__)),
                    "pagination_token"
  end

  def test_create_requires_email_after_edit_authorization
    error = with_api_errors do
      assert_raises(RecordingStudioApi::InvalidActionInputError) do
        RecordingStudioUser::Api::Create.call(FakeContext.new(actor: :staff, params: { first_name: "Nico" }))
      end
    end
    assert_match(/email is required/, error.message)
  end

  def test_index_show_create_update_require_admin_root_roles
    @authorize_admin_root = false
    RecordingStudioUser::Api::Access.authorization_result = ->(_context, _role) { false }
    context = FakeContext.new(actor: :stranger, params: { id: "missing" })

    with_api_errors do
      assert_raises(RecordingStudioApi::AuthorizationError) do
        RecordingStudioUser::Api::Index.call(context)
      end
      assert_raises(RecordingStudioApi::AuthorizationError) do
        RecordingStudioUser::Api::Show.call(context)
      end
      assert_raises(RecordingStudioApi::AuthorizationError) do
        RecordingStudioUser::Api::Create.call(context)
      end
      assert_raises(RecordingStudioApi::AuthorizationError) do
        RecordingStudioUser::Api::Update.call(context)
      end
    end
  end

  def test_create_with_password_calls_create_user!
    created = fake_created_user(registered_with: "password")
    calls = []
    with_api_errors do
      with_singleton_method(RecordingStudioUser.singleton_class, :create_user!, proc { |**kwargs|
        calls << kwargs
        created
      }) do
        with_singleton_method(RecordingStudioUser.singleton_class, :create_unconfirmed_user!, proc { |**|
          flunk "create_unconfirmed_user! must not run when a password is present"
        }) do
          events = registration_events do
            payload = without_profile_lookup do
              context = FakeContext.new(
                actor: :staff,
                params: { email: "ada@example.com", password: "secret", first_name: "Ada" }
              )
              RecordingStudioUser::Api::Create.call(context)
            end
            assert_equal "ada@example.com", payload.fetch(:email)
            assert_equal "password", payload.fetch(:registered_with)
          end
          assert_empty events
        end
      end
    end
    assert_equal "ada@example.com", calls.first[:email]
    assert_equal "secret", calls.first[:password]
    assert_nil calls.first[:password_confirmation]
    assert_equal :staff, calls.first[:actor]
    assert_equal "Ada", calls.first[:first_name]
  end

  def test_create_without_password_calls_create_unconfirmed_user_when_otp_is_on
    created = fake_created_user(registered_with: "otp")
    calls = []
    with_api_errors do
      with_otp_enabled(true) do
        with_singleton_method(RecordingStudioUser.singleton_class, :create_unconfirmed_user!, proc { |email:|
          calls << email
          created
        }) do
          with_singleton_method(RecordingStudioUser.singleton_class, :create_user!, proc { |**|
            flunk "create_user! must not run without a password"
          }) do
            events = registration_events do
              payload = without_profile_lookup do
                RecordingStudioUser::Api::Create.call(
                  FakeContext.new(actor: :staff, params: { email: "ada@example.com", first_name: "Ada" })
                )
              end
              assert_equal "otp", payload.fetch(:registered_with)
            end
            assert_empty events
          end
        end
      end
    end
    assert_equal ["ada@example.com"], calls
  end

  def test_create_without_password_requires_a_password_when_otp_is_off
    with_api_errors do
      with_otp_enabled(false) do
        with_singleton_method(RecordingStudioUser.singleton_class, :create_unconfirmed_user!, proc { |**|
          flunk "create_unconfirmed_user! must not run when one-time codes are off"
        }) do
          with_singleton_method(RecordingStudioUser.singleton_class, :create_user!, proc { |**|
            flunk "create_user! must not run without a password"
          }) do
            error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
              RecordingStudioUser::Api::Create.call(
                FakeContext.new(actor: :staff, params: { email: "ada@example.com" })
              )
            end
            assert_equal "password is required", error.message
          end
        end
      end
    end
  end

  def test_create_handler_calls_existing_user_methods_only
    directory = File.read(File.expand_path("../lib/recording_studio_user/directory.rb", __dir__))
    create = File.read(File.expand_path("../lib/recording_studio_user/api/create.rb", __dir__))

    assert_includes directory, "def create_user!(email:, password:, password_confirmation: nil"
    refute_includes directory, "def create_user!(email:, password: nil"
    assert_includes create, "RecordingStudioUser.create_user!"
    assert_includes create, "RecordingStudioUser.create_unconfirmed_user!"
    assert_includes create, "otp_enabled?"
    refute_includes create, "create_passwordless_user!"
    refute_includes create, "RegistrationCompleted"
    refute_includes create, "skip_confirmation!"
    refute File.exist?(File.expand_path("../lib/recording_studio_user/directory/passwordless.rb", __dir__))
  end

  private

  def without_profile_lookup
    singleton = RecordingStudioUser::Directory.singleton_class
    original = singleton.instance_method(:profile_for)
    verbose = $VERBOSE
    $VERBOSE = nil
    singleton.define_method(:profile_for) { |_record| nil }
    yield
  ensure
    $VERBOSE = nil
    singleton.define_method(:profile_for, original) if defined?(singleton) && defined?(original)
    $VERBOSE = verbose
  end

  def fake_created_user(registered_with:)
    Struct.new(:id, :email, :confirmed_at, :created_at, :updated_at, :registered_with, keyword_init: true).new(
      id: "user-1",
      email: "ada@example.com",
      confirmed_at: nil,
      created_at: Time.utc(2026, 1, 1),
      updated_at: Time.utc(2026, 1, 1),
      registered_with: registered_with
    )
  end

  def registration_events
    events = []
    event = RecordingStudioUser::RegistrationCompleted::EVENT
    subscriber = ActiveSupport::Notifications.subscribe(event) do |_name, _start, _finish, _id, payload|
      events << payload
    end
    yield
    events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def with_otp_enabled(enabled)
    config = RecordingStudioUser.config
    singleton = config.singleton_class
    original = singleton.instance_method(:otp_enabled?)
    verbose = $VERBOSE
    $VERBOSE = nil
    singleton.define_method(:otp_enabled?) { enabled }
    $VERBOSE = verbose
    yield
  ensure
    $VERBOSE = nil
    singleton.define_method(:otp_enabled?, original) if defined?(singleton) && defined?(original) && original
    $VERBOSE = verbose
  end

  def with_singleton_method(singleton, name, implementation)
    original = singleton.instance_method(name)
    verbose = $VERBOSE
    $VERBOSE = nil
    singleton.define_method(name, implementation)
    $VERBOSE = verbose
    yield
  ensure
    $VERBOSE = nil
    singleton.define_method(name, original) if defined?(singleton) && defined?(original) && original
    $VERBOSE = verbose
  end

  def with_api_errors
    return yield if defined?(RecordingStudioApi::InvalidActionInputError)

    api = Module.new
    api.const_set(:AuthorizationError, Class.new(StandardError))
    invalid = Class.new(StandardError) do
      attr_reader :details

      def initialize(message = "Action input is invalid", details: [])
        super(message)
        @details = Array(details)
      end
    end
    api.const_set(:InvalidActionInputError, invalid)
    api.const_set(:NotFoundError, Class.new(StandardError))
    Object.const_set(:RecordingStudioApi, api)
    yield
  ensure
    if defined?(api) && api && Object.const_defined?(:RecordingStudioApi, false) && RecordingStudioApi.equal?(api)
      Object.send(:remove_const, :RecordingStudioApi)
    end
  end

  def user_count_registration(api)
    registration_named(api, :user_count)
  end

  def registration_named(api, name)
    found = api.registrations.find { |entry| entry[:name] == name }
    refute_nil found, "missing #{name}"
    found
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
