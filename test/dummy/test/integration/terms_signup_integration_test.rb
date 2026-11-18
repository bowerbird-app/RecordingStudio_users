# frozen_string_literal: true

require "test_helper"

class TermsSignupIntegrationTest < ActionDispatch::IntegrationTest
  PASSWORD = "Password123!"

  setup do
    @workspace = Workspace.find_or_create_by!(name: Dummy::SignupTerms::WORKSPACE_NAME)
    @root = RecordingStudio.create_root_recording!(@workspace)
    ensure_live_terms!
  end

  test "create-password shows the signup notice and no checkbox" do
    email = "signup-notice-#{SecureRandom.hex(4)}@example.com"

    post new_user_registration_path, params: { user: { email: email } }
    assert_redirected_to "#{new_user_registration_path}/password"
    follow_redirect!

    assert_response :success
    assert_select "input#user_password[type=password]"
    assert_select "button[type=submit]", text: "Sign up"
    assert_select "input[type=checkbox]", count: 0
    assert_select "input[name=accept_terms]", count: 0
    assert_includes response.body, "By continuing you agree to the Terms"
    refute File.exist?(Rails.root.join("app/views/recording_studio_user/auth/registrations/_extra_fields.html.erb"))
  end

  test "finishing password signup records acceptance" do
    email = "signup-accept-#{SecureRandom.hex(4)}@example.com"
    post user_registration_path, params: { user: { email: email, password: PASSWORD } }
    assert_redirected_to verify_user_registration_path

    user = User.find_by!(email: email)
    refute RecordingStudioTermsAndConditions.accepted?(user)

    assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, +1 do
      post verify_user_registration_path, params: { code: signup_code }
    end

    assert RecordingStudioTermsAndConditions.accepted?(user)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal "signup", receipt.provenance["source"]
    assert_equal "password", receipt.provenance["method"]
    assert_equal user.id, receipt.actor_id
    assert_equal "User", receipt.actor_type
  end

  test "create-password still shows the notice when the current workspace has no terms" do
    Workspace.create!(name: "No terms #{SecureRandom.hex(4)}")
    email = "signup-library-#{SecureRandom.hex(4)}@example.com"

    post new_user_registration_path, params: { user: { email: email } }
    follow_redirect!

    assert_response :success
    assert_select "input#user_password[type=password]"
    assert_select "input[type=checkbox]", count: 0
    assert_includes response.body, "By continuing you agree to the Terms"
  end

  test "signup records nothing when no live terms are pending" do
    empty_pending_published_list do
      email = "signup-empty-#{SecureRandom.hex(4)}@example.com"
      post user_registration_path, params: { user: { email: email, password: PASSWORD } }
      follow_redirect!
      assert_includes response.body, "By continuing you agree to the Terms"
      assert_select "input[type=checkbox]", count: 0

      assert_no_difference -> { RecordingStudioTermsAndConditions::Acceptance.count } do
        post verify_user_registration_path, params: { code: signup_code }
      end

      user = User.find_by!(email: email)
      refute RecordingStudioTermsAndConditions.accepted?(user)
    end
  end

  private

  def signup_code
    RecordingStudioUser.otp_message(session[:otp_challenge_id]).fetch(:body)[/\d{6}/]
  end

  def ensure_live_terms!
    return if RecordingStudioTermsAndConditions.current_published_for

    library = terms_library_root
    recording = record_terms(library, title: "Signup Terms", body: "Be kind on the way in.")
    publish_terms!(recording, slug: "signup-terms-#{SecureRandom.hex(4)}")
  end

  def empty_pending_published_list
    mod = RecordingStudioTermsAndConditions.singleton_class
    mod.class_eval do
      alias_method :pending_published_list_without_signup, :pending_published_list
      define_method(:pending_published_list) { |*_args, **_kwargs| [] }
    end
    yield
  ensure
    mod.class_eval do
      alias_method :pending_published_list, :pending_published_list_without_signup
      remove_method :pending_published_list_without_signup
    end
  end
end
