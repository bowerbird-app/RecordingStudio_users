# frozen_string_literal: true

require "test_helper"

class TermsAgreePageTest < ActionDispatch::IntegrationTest
  setup do
    ensure_live_terms!
  end

  test "otp verify shows the signup notice and no checkbox" do
    email = "agree-notice-#{SecureRandom.hex(4)}@example.com"

    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    assert_redirected_to verify_user_registration_path
    follow_redirect!

    assert_response :success
    assert_includes response.body, "By continuing you agree to the Terms"
    assert_select "input[type=checkbox]", count: 0
    assert_select "input[name=accept_terms]", count: 0
    assert_select "button[type=submit]", text: "Verify and continue"
  end

  test "otp signup records acceptance without a checkbox" do
    email = "agree-otp-#{SecureRandom.hex(4)}@example.com"
    post "#{new_user_registration_path}/otp", params: { user: { email: email } }
    user = User.find_by!(email: email)
    challenge = RecordingStudioUser::OtpChallenge.find_by!(user_id: user.id, purpose: "registration")
    code = challenge.decrypt_delivery_code!
    refute RecordingStudioTermsAndConditions.accepted?(user)

    assert_difference -> { RecordingStudioTermsAndConditions::Acceptance.count }, +1 do
      post verify_user_registration_path, params: { code: code }
    end

    assert user.reload.confirmed?
    assert RecordingStudioTermsAndConditions.accepted?(user)
    receipt = RecordingStudioTermsAndConditions::Acceptance.order(:created_at).last
    assert_equal "signup", receipt.provenance["source"]
    assert_equal "otp", receipt.provenance["method"]
    assert_equal user.id, receipt.actor_id
    assert_equal "User", receipt.actor_type
  end

  private

  def ensure_live_terms!
    return if RecordingStudioTermsAndConditions.current_published_for

    library = terms_library_root
    recording = record_terms(library, title: "Signup Terms", body: "Be kind on the way in.")
    publish_terms!(recording, slug: "agree-terms-#{SecureRandom.hex(4)}")
  end
end
