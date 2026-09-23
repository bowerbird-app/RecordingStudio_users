# frozen_string_literal: true

require "cgi"
require "test_helper"
require "devise/test/integration_helpers"

class TermsAgreePageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "agree-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    @workspace = Workspace.create!(name: "Agree #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    bootstrap_owner_access!(@user, @root)
    @recording = record_terms(@root, title: "Studio Terms", body: "Be kind. Don't be a jerk.")
    publish_terms!(@recording, slug: "studio-terms-#{SecureRandom.hex(4)}")
    sign_in @user
    switch_to(@workspace)
  end

  test "Accept screen shows continue notice and Continue without Terms updated" do
    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_includes response.body, "Studio Terms"
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_select "button[type=submit]", text: "Continue"
    assert_select 'button[type=submit][data-fp-style="primary"]', text: "Continue"
    assert_select "input[type=checkbox][name=agreed]", count: 0
    refute_includes response.body, "Terms updated"
    refute_includes response.body, "Agree again"
    refute_includes CGI.unescapeHTML(response.body), "These terms changed. Agree again to stay in."
    assert_match %r{flat_pack/application}, response.body
  end

  test "re-gate Accept keeps continue notice and Continue without Terms updated" do
    RecordingStudioTermsAndConditions.accept!(@user, @recording, { "source" => "continue_notice" })
    revised = @root.revise(@recording) do |terms|
      terms.body = "Be kinder than last time."
    end
    publish_terms!(revised, slug: "studio-terms-#{SecureRandom.hex(4)}")

    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert RecordingStudioTermsAndConditions.reaccepting?(@user, @workspace)
    refute_includes response.body, "Terms updated"
    refute_includes response.body, "Agree again"
    assert_includes CGI.unescapeHTML(response.body), "We have updated our terms and conditions."
    assert_select "button[type=submit]", text: "Continue"
    assert_select 'button[type=submit][data-fp-style="primary"]', text: "Continue"
    assert_includes CGI.unescapeHTML(response.body), "By continuing, you agree"
    assert_select "input[type=checkbox][name=agreed]", count: 0
    assert_match %r{flat_pack/application}, response.body
  end

  private

  def switch_to(workspace)
    recording = RecordingStudio.root_recording_for(workspace)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "roots",
      root_switch: {
        root_recording_id: recording.id,
        return_to: "/"
      }
    }
  end
end
