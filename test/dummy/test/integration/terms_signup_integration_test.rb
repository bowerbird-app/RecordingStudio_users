# frozen_string_literal: true

require "cgi"
require "test_helper"

class TermsSignupIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = Workspace.find_or_create_by!(name: Dummy::SignupTerms::WORKSPACE_NAME)
    @root = RecordingStudio.root_recording_for(@workspace)
    ensure_live_terms!
  end

  test "create-password shows the released continue notice and modal document" do
    email = "signup-notice-#{SecureRandom.hex(4)}@example.com"

    post new_user_registration_path, params: { user: { email: email } }
    assert_redirected_to "#{new_user_registration_path}/password"
    follow_redirect!

    assert_response :success
    assert_select "input#user_password[type=password]"
    assert_select "button[type=submit]", text: "Sign up"
    assert_select "input[type=checkbox][name=agreed]", count: 0
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_includes CGI.unescapeHTML(response.body), "Studio's"
    assert_includes response.body, "Terms &amp; Conditions"
    assert_includes response.body, '<p class="text-xs text-[var(--surface-muted-content-color)]">'
    assert_select "a.flat-pack-link[data-modal-id]", text: "Terms & Conditions"
    assert_includes response.body, "text-[var(--color-primary)]"
    assert_includes response.body, "underline"
    assert_select "[data-controller='flat-pack--modal']", minimum: 1
    assert_includes response.body, "page-title"
    assert_includes response.body, "fp-content"
    live = RecordingStudioTermsAndConditions.current_published_for(@workspace)
    assert_includes response.body, live.title
    assert_includes CGI.unescapeHTML(response.body), live.body.to_s

    users_extra_fields = File.read(
      RecordingStudioUser::Engine.root.join(
        "app/views/recording_studio_user/auth/registrations/_extra_fields.html.erb"
      )
    )
    assert_includes users_extra_fields, "recording_studio_user_signup_terms_notice"
    refute File.exist?(Rails.root.join("app/views/recording_studio_user/auth/registrations/_extra_fields.html.erb"))
  end

  test "create_password writes a continue_notice Acceptance receipt" do
    email = "signup-accept-#{SecureRandom.hex(4)}@example.com"
    post new_user_registration_path, params: { user: { email: email } }
    follow_redirect!

    assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, +1 do
      post user_registration_path, params: {
        user: { email: email, password: "Password123!" }
      }
    end

    user = User.find_by!(email: email)
    assert RecordingStudioTermsAndConditions.accepted?(user, @workspace)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal({ "source" => "continue_notice" }, receipt.provenance)
    assert_equal user.id, receipt.actor_id
    assert_equal "User", receipt.actor_type
  end

  test "create-password still shows the notice when the current workspace has no live Terms" do
    empty = Workspace.create!(name: "No terms #{SecureRandom.hex(4)}")
    email = "signup-fallback-#{SecureRandom.hex(4)}@example.com"

    with_current_root(empty) do
      post new_user_registration_path, params: { user: { email: email } }
      follow_redirect!

      assert_response :success
      assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
      assert_select "button[type=submit]", text: "Sign up"
    end
  end

  test "create-password stays blank when no live Terms are pending" do
    empty_pending_published_list do
      email = "signup-empty-#{SecureRandom.hex(4)}@example.com"
      post new_user_registration_path, params: { user: { email: email } }
      follow_redirect!

      assert_response :success
      assert_select "input#user_password[type=password]"
      assert_select "input[type=checkbox][name=agreed]", count: 0
      refute_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    end
  end

  private

  def ensure_live_terms!
    return if RecordingStudioTermsAndConditions.current_published_for(@workspace)

    recording = record_terms(@root, title: "Signup Terms", body: "Be kind on the way in.")
    publish_terms!(recording, slug: "signup-terms-#{SecureRandom.hex(4)}")
  end

  def with_current_root(root)
    gate = RecordingStudioTermsAndConditions::Gate
    singleton = gate.singleton_class
    singleton.class_eval do
      alias_method :root_for_without_empty, :root_for
      define_method(:root_for) { |*_args, **_kwargs| root }
    end
    yield
  ensure
    singleton.class_eval do
      alias_method :root_for, :root_for_without_empty
      remove_method :root_for_without_empty
    end
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
