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
    assert_includes registration, "api: OPERATIONS_API"
    refute_includes registration, "api: :public"
    refute_includes registration, "http_verb: :delete"
    assert_includes registration, "handler: UserCount"
    assert_includes registration, "handler: Index"
    assert_includes registration, "handler: Create"
    assert_includes registration, "handler: Show"
    assert_includes registration, "handler: Update"
  end

  def test_users_endpoints_register_on_operations_not_public
    api = install_test_recording_studio_api!

    assert RecordingStudioUser::Api.register!

    names = api.registrations.map { |entry| entry.fetch(:name) }
    assert_equal %i[user_count users users_create users_show users_update], names
    assert(api.registrations.all? { |entry| entry.fetch(:api) == :operations })
    refute(api.registrations.any? { |entry| entry.fetch(:http_verb) == :delete })

    count = registration_named(api, :user_count)
    assert_equal :get, count.fetch(:http_verb)
    assert_equal "users/count", count.fetch(:path)
    assert_equal RecordingStudioUser::Api::UserCount, count.fetch(:handler)

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

  def test_user_count_registration_is_idempotent
    api = install_test_recording_studio_api!

    2.times { RecordingStudioUser::Api.register! }

    assert_equal 5, api.registrations.size
  end

  def test_user_count_authorizes_view_then_counts
    CountedUsers.total = 4
    with_user_class_name("ApiTest::CountedUsers") do
      assert_equal({ count: 4 }, RecordingStudioUser::Api::UserCount.call(FakeContext.new(actor: :staff)))
    end
  end

  def test_user_count_rejects_unauthorized_actors
    @authorize_admin_root = false
    RecordingStudioUser::Api::Access.authorization_result = ->(_context, _role) { false }

    error = assert_raises(RecordingStudioUser::Api::AuthorizationDenied) do
      RecordingStudioUser::Api::UserCount.call(FakeContext.new(actor: :stranger))
    end
    assert_match(/not authorized/, error.message)
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
    payload = RecordingStudioUser::Api::Serialize.user(user)

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
    error = assert_raises(ArgumentError) do
      RecordingStudioUser::Api::Params.update_attributes(context)
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

  def test_query_normalizes_limit
    assert_equal 50, RecordingStudioUser::Api::Query.normalize_limit(nil)
    assert_equal 50, RecordingStudioUser::Api::Query.normalize_limit(0)
    assert_equal 10, RecordingStudioUser::Api::Query.normalize_limit(10)
    assert_equal 100, RecordingStudioUser::Api::Query.normalize_limit(500)
  end

  def test_create_requires_email_after_edit_authorization
    error = assert_raises(ArgumentError) do
      RecordingStudioUser::Api::Create.call(FakeContext.new(actor: :staff, params: { first_name: "Nico" }))
    end
    assert_match(/email is required/, error.message)
  end

  def test_index_show_create_update_require_admin_root_roles
    @authorize_admin_root = false
    RecordingStudioUser::Api::Access.authorization_result = ->(_context, _role) { false }
    context = FakeContext.new(actor: :stranger, params: { id: "missing" })

    assert_raises(RecordingStudioUser::Api::AuthorizationDenied) do
      RecordingStudioUser::Api::Index.call(context)
    end
    assert_raises(RecordingStudioUser::Api::AuthorizationDenied) do
      RecordingStudioUser::Api::Show.call(context)
    end
    assert_raises(RecordingStudioUser::Api::AuthorizationDenied) do
      RecordingStudioUser::Api::Create.call(context)
    end
    assert_raises(RecordingStudioUser::Api::AuthorizationDenied) do
      RecordingStudioUser::Api::Update.call(context)
    end
  end

  def test_directory_create_user_accepts_a_blank_password
    directory = File.read(File.expand_path("../lib/recording_studio_user/directory.rb", __dir__))
    accounts = File.read(File.expand_path("../lib/recording_studio_user/directory/accounts.rb", __dir__))

    assert_includes directory, "def create_user!(email:, password: nil"
    assert_includes directory, "Accounts.create_passwordless_user!"
    assert_includes accounts, 'attrs = attrs.merge(registered_with: "otp")'
    refute_includes directory, "accept!"
    refute_includes accounts, "accept!"
  end

  private

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
