# frozen_string_literal: true

require "test_helper"

class UsersOperationsApiTest < ActionDispatch::IntegrationTest
  PUBLIC_ROOT = "/recording_studio_api/api/v1"
  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"

  setup do
    @staff = RecordingStudioUser.create_user!(
      email: "api-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Api",
      last_name: "Staff",
      time_zone: "UTC"
    )
    Current.actor = @staff
    @workspace = Workspace.find_or_create_by!(name: "My workspace")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_root = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    grant!(@admin_root, @staff, :admin)
    bootstrap_owner_access!(@staff, @root) unless RecordingStudioAccessible.authorized?(
      actor: @staff, recording: @root, role: :view
    )

    Dummy::SignupTerms.ensure_live!(actor: @staff)

    @editor_token = provision_token(
      access_point: @admin_root,
      actor: @staff,
      role: :edit,
      name: "Users operations editor #{SecureRandom.hex(4)}",
      api: :operations,
      admin_root_recording: @admin_root,
      admin_root_role: :edit
    )
    @viewer_token = provision_token(
      access_point: @admin_root,
      actor: @staff,
      role: :view,
      name: "Users operations viewer #{SecureRandom.hex(4)}",
      api: :operations,
      admin_root_recording: @admin_root,
      admin_root_role: :view
    )
    @workspace_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :view,
      name: "Workspace #{SecureRandom.hex(4)}"
    )
  end

  teardown do
    Current.actor = nil
  end

  test "missing token is unauthorized on operations users" do
    get "#{OPERATIONS_ROOT}/users", as: :json
    assert_response :unauthorized

    get "#{OPERATIONS_ROOT}/users/count", as: :json
    assert_response :unauthorized
  end

  test "public API has no users routes" do
    get "#{PUBLIC_ROOT}/users", headers: auth(@workspace_token), as: :json
    assert_includes [404, 422], response.status, response.body

    get "#{PUBLIC_ROOT}/users/count", headers: auth(@workspace_token), as: :json
    assert_includes [404, 422], response.status, response.body

    post "#{PUBLIC_ROOT}/users",
         headers: auth(@workspace_token),
         params: { email: "nope@example.com" },
         as: :json
    assert_includes [404, 422], response.status, response.body
  end

  test "public token is rejected on operations users" do
    get "#{OPERATIONS_ROOT}/users", headers: auth(@workspace_token), as: :json
    assert_includes [401, 403], response.status, response.body
  end

  test "workspace client without admin root cannot read users" do
    get "#{OPERATIONS_ROOT}/users/count", headers: auth(@workspace_token), as: :json
    assert_includes [401, 403], response.status, response.body
  end

  test "operations viewer can count list and show but cannot write" do
    listed = RecordingStudioUser.create_user!(
      email: "listed-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Listed",
      last_name: "Person",
      time_zone: "UTC"
    )

    get "#{OPERATIONS_ROOT}/users/count", headers: auth(@viewer_token), as: :json
    assert_response :success
    assert_equal User.count, response.parsed_body.fetch("count")

    get "#{OPERATIONS_ROOT}/users",
        headers: auth(@viewer_token),
        params: { page: 1, per_page: 50 },
        as: :json
    assert_response :success
    emails = response.parsed_body.fetch("records").map { |row| row.fetch("email") }
    assert_includes emails, listed.email
    meta = response.parsed_body.fetch("meta")
    assert_equal 1, meta.fetch("page")
    assert_equal 50, meta.fetch("per_page")
    assert_equal User.count, meta.fetch("total_count")
    refute_secret_fields response.parsed_body.fetch("records").first

    get "#{OPERATIONS_ROOT}/users/#{listed.id}", headers: auth(@viewer_token), as: :json
    assert_response :success
    assert_equal listed.email, response.parsed_body.fetch("email")
    assert_equal "Listed", response.parsed_body.fetch("first_name")
    assert_equal "password", response.parsed_body.fetch("registered_with")
    refute_secret_fields response.parsed_body

    assert_raises(RecordingStudioApi::AuthorizationError) do
      invoke_users_handler(
        RecordingStudioUser::Api::Create,
        @viewer_token,
        { email: "viewer-cannot-#{SecureRandom.hex(4)}@example.com" }
      )
    end

    assert_raises(RecordingStudioApi::AuthorizationError) do
      invoke_users_handler(
        RecordingStudioUser::Api::Update,
        @viewer_token,
        { id: listed.id, first_name: "Hijack" }
      )
    end
  end

  test "operations editor creates without password and does not accept terms" do
    email = "passwordless-#{SecureRandom.hex(4)}@example.com"

    payload = nil
    events = registration_completed_events do
      payload = invoke_users_handler(
        RecordingStudioUser::Api::Create,
        @editor_token,
        { email: email, first_name: "Nico", last_name: "New", locale: "en" }
      )
    end
    payload = payload.deep_stringify_keys
    assert_equal email, payload.fetch("email")
    assert_equal "Nico", payload.fetch("first_name")
    assert_equal "otp", payload.fetch("registered_with")
    assert payload.fetch("confirmed_at").present?
    refute_secret_fields payload

    user = User.find(payload.fetch("id"))
    assert user.registered_with_otp?
    assert_not user.password_set?
    assert RecordingStudioUser.profile_for(user).present?
    assert_empty RecordingStudioTermsAndConditions::Acceptance.where(
      actor_type: user.class.name,
      actor_id: user.id
    )
    pending = RecordingStudioTermsAndConditions.pending_published_list(user, Dummy::SignupTerms.workspace)
    assert pending.any?, "passwordless create must leave Terms for the Accept page"
    assert_equal [{ user_id: user.id, method: :otp }], events
  end

  test "operations editor patches profile fields but rejects email changes" do
    email = "password-#{SecureRandom.hex(4)}@example.com"

    created = nil
    events = registration_completed_events do
      created = invoke_users_handler(
        RecordingStudioUser::Api::Create,
        @editor_token,
        {
          email: email,
          password: "Password123!",
          first_name: "Pat",
          last_name: "Chable",
          time_zone: "UTC"
        }
      )
    end
    user_id = created.fetch(:id)
    user = User.find(user_id)
    assert_equal "password", user.registered_with
    assert user.password_set?
    assert_equal [{ user_id: user.id, method: :password }], events

    updated = invoke_users_handler(
      RecordingStudioUser::Api::Update,
      @editor_token,
      { id: user_id, first_name: "Patricia", time_zone: "Eastern Time (US & Canada)" }
    )
    assert_equal email, updated.fetch(:email)
    assert_equal "Patricia", updated.fetch(:first_name)
    assert_equal "Eastern Time (US & Canada)", updated.fetch(:time_zone)

    user.reload
    assert_equal email, user.email
    assert_nil user.unconfirmed_email
    assert_equal "Patricia", RecordingStudioUser.profile_for(user).first_name

    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      invoke_users_handler(
        RecordingStudioUser::Api::Update,
        @editor_token,
        { id: user_id, email: "reconfirm-#{SecureRandom.hex(4)}@example.com" }
      )
    end
    assert_match(/email cannot be changed/, error.message)
  end

  test "operations list uses offset paging on ordered_users" do
    stamp = Time.utc(2026, 10, 8, 15, 0, 0)
    3.times do |index|
      RecordingStudioUser.create_user!(
        email: "page-#{index}-#{SecureRandom.hex(4)}@example.com",
        password: "Password123!",
        first_name: "Page#{index}",
        last_name: "User",
        time_zone: "UTC"
      ).update_columns(created_at: stamp + index.seconds, updated_at: stamp + index.seconds)
    end
    total = User.count

    get "#{OPERATIONS_ROOT}/users",
        headers: auth(@viewer_token),
        params: { page: 1, per_page: 2 },
        as: :json
    assert_response :success
    first = response.parsed_body
    assert_equal 2, first.fetch("records").length
    assert_equal(
      { "page" => 1, "per_page" => 2, "total_count" => total, "total_pages" => (total.to_f / 2).ceil },
      first.fetch("meta")
    )
    refute first.fetch("meta").key?("q")
    refute first.fetch("meta").key?("pagination_token")
    refute first.fetch("meta").key?("next_pagination_token")

    get "#{OPERATIONS_ROOT}/users",
        headers: auth(@viewer_token),
        params: { page: 2, per_page: 2 },
        as: :json
    assert_response :success
    second_ids = response.parsed_body.fetch("records").map { |row| row.fetch("id") }
    first_ids = first.fetch("records").map { |row| row.fetch("id") }
    assert_empty first_ids & second_ids
  end

  test "operations registry matches POST and PATCH users by verb" do
    registry = RecordingStudioApi.api(:operations).registered_endpoint_registry

    post_match = registry.match(path: "users", http_verb: :post)
    patch_match = registry.match(path: "users/example-id", http_verb: :patch)
    get_match = registry.match(path: "users", http_verb: :get)
    path_only = registry.match_path("users")

    assert_equal RecordingStudioUser::Api::Create, post_match.endpoint.handler
    assert_equal RecordingStudioUser::Api::Update, patch_match.endpoint.handler
    assert_equal RecordingStudioUser::Api::Index, get_match.endpoint.handler
    assert_equal :get, path_only.endpoint.http_verb
  end

  test "delete is not registered on operations users" do
    user = RecordingStudioUser.create_user!(
      email: "keep-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Keep",
      last_name: "Me",
      time_zone: "UTC"
    )

    delete "#{OPERATIONS_ROOT}/users/#{user.id}", headers: auth(@editor_token), as: :json
    assert_includes [404, 422], response.status, response.body
    assert User.exists?(user.id)
  end

  private

  def refute_secret_fields(payload)
    %w[
      encrypted_password password password_confirmation reset_password_token
      confirmation_token unlock_token otp_secret encrypted_otp_secret
    ].each do |key|
      refute payload.key?(key), "payload leaked #{key}"
    end
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def registration_completed_events
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(
      RecordingStudioUser::RegistrationCompleted::EVENT
    ) do |_name, _start, _finish, _id, payload|
      events << payload
    end
    yield
    events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def invoke_users_handler(handler, token, params)
    result = RecordingStudioApi.access_grant_from_authorization_header(
      authorization_header: "Bearer #{token}",
      api: :operations
    )
    raise result.error unless result.success?

    grant = result.value
    context = RecordingStudioApi::RegisteredEndpointContext.new(
      api_client: grant.api_client,
      credential: grant.credential,
      access_recording: grant.access_recording,
      access_grant: grant,
      root_recording: grant.root_recording,
      params: params
    )
    handler.call(context)
  end

  def provision_token(access_point:, actor:, role:, name:, api: :public, admin_root_recording: nil, admin_root_role: :edit)
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: actor,
      role: role,
      name: name,
      api: api
    )
    raise result.error unless result.success?

    payload = result.value
    grant!(admin_root_recording, payload.fetch(:api_client), admin_root_role) if admin_root_recording

    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.fetch(:credential).oauth_client_id,
      client_secret: payload.fetch(:token),
      api: api
    )
    raise token_result.error unless token_result.success?

    token_result.value.fetch(:access_token)
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end

  def grant!(recording, actor, role)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)

    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
