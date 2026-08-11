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

  test "signed-in user edits pre-filled profile fields below avatar controls" do
    user = User.find_by!(email: "admin@admin.com")
    profile_attributes = {
      display_name: "Studio Administrator",
      biography: "Keeps the recording workflow moving.",
      locale: "en-AU",
      time_zone: "Australia/Melbourne"
    }
    result = RecordingStudioUsers.revise_profile(
      user:,
      actor: user,
      attributes: profile_attributes
    )

    assert_predicate result, :success?

    sign_in user
    get recording_studio_users.edit_profile_path

    assert_response :success
    assert_select "html.h-full.overflow-hidden"
    assert_select "div.mx-auto.w-full.max-w-4xl"
    assert_select "nav[aria-label='Page navigation'][data-controller='flat-pack--page-nav']" do
      assert_select "button[aria-label='Back to previous page'][data-action='click->flat-pack--page-nav#back']"
      assert_select "a[href='/'][aria-label='Home'] svg[data-flat-pack--icon-name-value='home']"
    end
    assert_select "h2", text: "Edit profile"
    assert_operator response.body.index('aria-label="Page navigation"'), :<,
                    response.body.index("Edit profile")
    assert_select "section[aria-labelledby='avatar-heading']" do
      assert_select "h3#avatar-heading", text: "Avatar"
      assert_select "form[action='#{recording_studio_users.avatar_profile_path}']" \
                    "[data-controller='recording-studio-attachable--attachment-revision-upload']" \
                    "[data-recording-studio-attachable--attachment-revision-upload-direct-upload-url-value=" \
              "'#{Rails.application.routes.url_helpers.rails_direct_uploads_path}']", count: 1 do |forms|
        assert_includes forms.first["data-action"],
                "change->recording-studio-attachable--attachment-revision-upload#fileSelected"
        assert_includes forms.first["data-action"],
                "submit->recording-studio-attachable--attachment-revision-upload#handleSubmit"
        assert_select "input[type='file'][name='avatar_file']" \
                "[data-recording-studio-attachable--attachment-revision-upload-target='fileInput']" do |inputs|
          assert_includes inputs.first["data-action"], "change->flat-pack--file-input#handleFiles"
        end
        assert_select "input[type='hidden'][name='signed_blob_id']" \
                      "[data-recording-studio-attachable--attachment-revision-upload-target='signedBlobInput']"
        assert_select "[data-recording-studio-attachable--attachment-revision-upload-target='status']"
        assert_select "button[data-recording-studio-attachable--attachment-revision-upload-target='submitButton']"
      end
    end
    assert_select "section[aria-labelledby='profile-fields-heading']" do
      assert_select "form[action='#{recording_studio_users.profile_path}']" \
                    "[data-controller='recording-studio-users--profile-preferences']", count: 1
      assert_select "input[name='profile[display_name]'][value='#{profile_attributes[:display_name]}']"
      assert_select "textarea[name='profile[biography]']", text: profile_attributes[:biography]
      assert_select "select[name='profile[locale]']" \
                    "[data-recording-studio-users--profile-preferences-target='locale']" do
        assert_select "option[value='']", text: "Select a locale"
        assert_select "option[value='en-US']", text: "English (United States)"
        assert_select "option[value='en-GB']", text: "English (United Kingdom)"
        assert_select "option[value='es-ES']", text: "Español (España)"
        assert_select "option[value='#{profile_attributes[:locale]}'][selected]", text: "en-AU (saved value)"
      end
      assert_select "[data-recording-studio-users--profile-preferences-target='timeZone']" do
        assert_select "[data-controller='flat-pack--select']" \
                      "[data-flat-pack--select-searchable-value='true']" \
                      "[data-flat-pack--select-search-mode-value='local']" do
          assert_select "input[type='hidden'][name='profile[time_zone]']" \
                        "[value='#{profile_attributes[:time_zone]}']"
          assert_select "input[type='text'][data-action='input->flat-pack--select#search']"
          assert_select "[role='option'][data-value='America/New_York']", text: /America\/New York/
          assert_select "[role='option'][data-value='#{profile_attributes[:time_zone]}']" \
                        "[aria-selected='true']", text: /Australia\/Melbourne/
        end
      end
    end
    assert_operator response.body.index('id="avatar-heading"'), :<,
                    response.body.index('id="profile-fields-heading"')
    refute_includes response.body, "bg-[var(--card-background-color)]"
  end

  test "signed-in user uploads an avatar from an Active Storage signed blob" do
    user = User.find_by!(email: "admin@admin.com")
    if RecordingStudioUsers.avatar_recording_for(user)
      removal = RecordingStudioUsers.remove_avatar(user:, actor: user)
      assert_predicate removal, :success?
    end
    blob = File.open(Rails.root.join("public/icon.png"), "rb") do |image|
      ActiveStorage::Blob.create_and_upload!(
        io: image,
        filename: "avatar.png",
        content_type: "image/png"
      )
    end

    sign_in user
    post recording_studio_users.avatar_profile_path, params: {signed_blob_id: blob.signed_id}

    assert_redirected_to recording_studio_users.profile_path
    assert_equal "Avatar uploaded.", flash[:notice]
    avatar_recording = RecordingStudioUsers.avatar_recording_for(user)
    assert_equal "RecordingStudioAttachable::Attachment", avatar_recording.recordable_type
    assert_equal blob.id, avatar_recording.recordable.file.blob_id

    follow_redirect!

    assert_response :success
    preview_path = "/recording_studio_attachable/attachments/#{avatar_recording.id}/preview/square_small"
    assert_includes response.body, preview_path

    get preview_path

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_operator response.body.bytesize, :>, 0
  end
end