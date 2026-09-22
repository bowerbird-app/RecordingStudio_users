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

  test "first-time Agree has no Terms updated alert and uses tight checkbox spacing" do
    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert_includes response.body, "Studio Terms"
    assert_includes response.body, "I agree to these terms"
    assert_select "button[type=submit]", text: "Agree"
    refute_includes response.body, "Terms updated"
    refute_includes CGI.unescapeHTML(response.body), "These terms changed. Agree again to stay in."
    assert_select "div.space-y-4"
    assert_select "div.pt-2"
    assert_select "div.py-5", count: 0
  end

  test "re-accept Agree drops Terms updated and keeps Agree again" do
    RecordingStudioTermsAndConditions.accept!(@user, @recording, { "source" => "clickwrap" })
    revised = @root.revise(@recording) do |terms|
      terms.body = "Be kinder than last time."
    end
    publish_terms!(revised, slug: "studio-terms-#{SecureRandom.hex(4)}")

    get recording_studio_terms_and_conditions.acceptance_path

    assert_response :success
    assert RecordingStudioTermsAndConditions.reaccepting?(@user, @workspace)
    refute_includes response.body, "Terms updated"
    refute_includes CGI.unescapeHTML(response.body), "These terms changed. Agree again to stay in."
    assert_select "button[type=submit]", text: "Agree again"
    assert_select "div.pt-2"
    assert_select "div.py-5", count: 0
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
