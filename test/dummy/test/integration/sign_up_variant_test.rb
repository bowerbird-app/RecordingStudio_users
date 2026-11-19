# frozen_string_literal: true

require "test_helper"

class SignUpVariantTest < ActionDispatch::IntegrationTest
  include RecordingStudioUser::AuthRoutesHelper

  test "a registered variant shows its title and subtitle" do
    get new_user_registration_path, params: { variant: "trial", title: "Pay the prince" }

    assert_response :success
    assert_select "h2", text: "Start your trial"
    assert_includes response.body, "Fourteen days, on us."
    assert_select "form[action*='variant=trial']"
    refute_includes response.body, "Pay the prince"
    refute_includes response.body, "dummy.signup.trial"
  end

  test "french uses the host strings for the same variant" do
    get new_user_registration_path, params: { variant: "trial", locale: "fr" }

    assert_response :success
    assert_select "h2", text: "Commencez votre essai"
    assert_includes response.body, "Quatorze jours, offerts."
  end

  test "an unknown variant keeps the default title" do
    get new_user_registration_path, params: { variant: "nope" }

    assert_response :success
    assert_select "h2", text: "Sign up"
    assert_select "p", text: "Fourteen days, on us.", count: 0
    assert_select "form[action*='variant=']", count: 0
  end

  test "a missing translation falls back and does not show the key" do
    original = RecordingStudioUser.config.sign_up_variants
    RecordingStudioUser.config.sign_up_variants = original.merge(
      missing: { title: "dummy.signup.missing.title", subtitle: "dummy.signup.missing.subtitle" }
    )

    get new_user_registration_path, params: { variant: "missing" }

    assert_response :success
    assert_select "h2", text: "Sign up"
    refute_includes response.body, "dummy.signup.missing"
    refute_includes response.body, "translation missing"
  ensure
    RecordingStudioUser.config.sign_up_variants = original
  end

  test "text in the query is ignored" do
    get new_user_registration_path, params: {
      variant: "Pay the prince",
      title: "Pay the prince",
      subtitle: "Send the coins today"
    }

    assert_response :success
    assert_select "h2", text: "Sign up"
    refute_includes response.body, "Pay the prince"
    refute_includes response.body, "Send the coins today"
  end

  test "a failed submit keeps the variant title" do
    post "#{new_user_registration_path}?variant=trial", params: { user: { email: "" } }

    assert_response :unprocessable_entity
    assert_select "h2", text: "Start your trial"
    assert_includes response.body, "Fourteen days, on us."
    assert_select "form[action*='variant=trial']"
  end

  test "the sign in link does not carry the variant" do
    get new_user_registration_path, params: { variant: "trial", return_to: "/after-helper" }

    assert_select "h2", text: "Start your trial"
    link = css_select("a").map { |anchor| anchor["href"] }.find { |href| href.include?("/users/sign_in") }
    query = Rack::Utils.parse_query(URI.parse(link).query)

    assert_equal "/after-helper", query["return_to"]
    assert_nil query["variant"]
  end

  test "helpers build a sign up link with the variant and return path" do
    link = recording_studio_user_sign_up_path(variant: :trial, return_to: "/after-helper", popup: true)
    query = Rack::Utils.parse_query(URI.parse(link).query)

    assert_includes link, new_user_registration_path
    assert_equal "trial", query["variant"]
    assert_equal "/after-helper", query["return_to"]
    assert_equal "1", query["popup"]

    built = RecordingStudioUser.auth_url_for(:sign_up, variant: :trial, return_to: "/after-helper")
    built_query = Rack::Utils.parse_query(URI.parse(built).query)

    assert_equal "trial", built_query["variant"]
    assert_equal "/after-helper", built_query["return_to"]

    unknown = recording_studio_user_sign_up_path(variant: :nope, return_to: "/after-helper")
    unknown_query = Rack::Utils.parse_query(URI.parse(unknown).query)

    assert_nil unknown_query["variant"]
    assert_equal "/after-helper", unknown_query["return_to"]

    sign_in = RecordingStudioUser.auth_url_for(:sign_in, variant: :trial, return_to: "/after-helper")
    refute_includes sign_in, "variant="
  end
end
