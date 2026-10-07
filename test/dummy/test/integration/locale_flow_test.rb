# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class LocaleFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = RecordingStudioUser.create_user!(
      email: "locale-flow-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      first_name: "Locale",
      last_name: "Flow",
      time_zone: "UTC"
    )
  end

  test "sign in and profile render in French from the query string" do
    get new_user_session_path, params: { locale: "fr" }

    assert_response :success
    assert_select "h2", text: "Heureux de vous revoir"
    assert_select "button[type='submit']", text: "Continuer avec l'e-mail"
    assert_includes response.body, "Pas encore de compte ?"

    sign_in @user
    get recording_studio_users.profile_path, params: { locale: "fr" }

    assert_response :success
    assert_includes response.body, "Mon profil"
    assert_select "a, button", text: "Modifier"

    get recording_studio_users.edit_profile_path, params: { locale: "fr" }

    assert_response :success
    assert_includes response.body, "Modifier le profil"
    assert_includes response.body, "Langue"
    assert_includes response.body, "Utiliser la langue du site"
    assert_select "button[type='submit']", text: "Enregistrer le profil"
  end

  test "signed-in profile locale switches dummy screens without a query string" do
    RecordingStudioUser.record_profile!(
      @user,
      actor: @user,
      first_name: "Locale",
      last_name: "Flow",
      time_zone: "UTC",
      additional_profile_attributes: { "locale" => "fr" }
    )
    sign_in @user

    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_includes response.body, "Langue"
    assert_includes response.body, "Utiliser la langue du site"
    refute_includes response.body, "Use the site default"
  end

  test "a French query cookie keeps the verify screen after OTP post" do
    get "#{new_user_session_path}/otp", params: { locale: "fr" }

    assert_response :success
    assert_includes response.body, "Envoyer le code"

    post "#{new_user_session_path}/otp", params: { user: { email: "otp@admin.com" } }

    assert_redirected_to verify_user_session_path
    follow_redirect!
    assert_includes response.body, "Entrez votre code"
    assert_includes response.body, "Si un compte admissible existe"
  end

  test "profile updated flash renders in French" do
    sign_in @user
    patch "#{recording_studio_users.profile_path}?locale=fr", params: {
      user: { first_name: "Locale", last_name: "Flow", time_zone: "UTC" }
    }

    assert_redirected_to recording_studio_users.profile_path
    follow_redirect!
    assert_includes response.body, "Profil enregistré."
  end
end
