# frozen_string_literal: true

require "test_helper"

class RecordingStudioUsersProfileTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signed-out user is redirected to sign in" do
    get recording_studio_users.profile_path

    assert_redirected_to new_user_session_path
  end

  test "signed-out JSON request is unauthorized" do
    get recording_studio_users.profile_path(format: :json)

    assert_response :unauthorized
  end

  test "signed-in user can open the profile" do
    user = User.find_by!(email: "admin@admin.com")

    sign_in user
    get recording_studio_users.profile_path

    assert_response :success
    assert_select "html.h-full.overflow-hidden"
    assert_select "div.mx-auto.w-full.max-w-4xl"
    assert_select "nav[aria-label='Page navigation'][data-controller='flat-pack--page-nav']" do
      assert_select "button[aria-label='Back to previous page'][data-action='click->flat-pack--page-nav#back']"
      assert_select "a[href='/'][aria-label='Home'] svg[data-flat-pack--icon-name-value='home']"
      assert_select "div.ml-auto.flex.items-center.gap-2 [data-controller='flat-pack--tooltip']" do
        assert_select "a[href='#{recording_studio_users.edit_profile_path}'][aria-label='Edit profile'] " \
                      "svg[data-flat-pack--icon-name-value='pencil']"
        assert_select "[role='tooltip']", text: "Edit profile"
      end
    end
    assert_select "a[href='#{recording_studio_users.edit_profile_path}']", count: 1
    navigation = css_select("nav[aria-label='Page navigation']").first
    back_button = navigation.css("button[aria-label='Back to previous page']").first
    home_link = navigation.css("a[aria-label='Home']").first
    edit_link = navigation.css("a[aria-label='Edit profile']").first
    assert_equal back_button["class"], edit_link["class"]
    assert_equal home_link["class"], edit_link["class"]
    assert_select "h2", text: "Your profile"
    assert_select "p", text: "Manage the identity information shared by supported Recording Studio features."
    assert_select "h3", text: "Profile information", count: 0
    assert_operator response.body.index('aria-label="Page navigation"'), :<,
                    response.body.index("Your profile")
    assert_select "h3#avatar-heading", count: 0
    assert_select "form[action='#{recording_studio_users.avatar_profile_path}']", count: 0
    refute_includes response.body, "bg-[var(--card-background-color)]"
  end

  test "signed-in user manages the avatar above profile fields on edit" do
    user = User.find_by!(email: "admin@admin.com")

    sign_in user
    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_select "html.h-full.overflow-hidden"
    assert_select "div.mx-auto.w-full.max-w-3xl"
    assert_select "section[aria-labelledby='avatar-heading']" do
      assert_select "h3#avatar-heading", text: "Avatar"
      assert_select "form[action='#{recording_studio_users.avatar_profile_path}']", count: 1
      assert_select "input[name='signed_blob_id']"
    end
    assert_select "section[aria-labelledby='profile-fields-heading']" do
      assert_select "form[action='#{recording_studio_users.profile_path}']", count: 1
      assert_select "input[name='profile[display_name]']"
    end
    assert_operator response.body.index('id="avatar-heading"'), :<,
                    response.body.index('id="profile-fields-heading"')
    refute_includes response.body, "bg-[var(--card-background-color)]"
  end
end