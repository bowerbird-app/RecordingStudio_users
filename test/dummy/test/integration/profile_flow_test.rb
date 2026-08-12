# frozen_string_literal: true

require "test_helper"

class ProfileFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name: "Taylor",
      last_name: "Member",
      email: "taylor@example.com",
      time_zone: "UTC",
      password: "Password123!"
    )
    @other_user = User.create!(
      first_name: "Other",
      last_name: "Person",
      email: "other@example.com",
      time_zone: "UTC",
      password: "Password123!"
    )
  end

  test "unauthenticated visitors are redirected to sign in" do
    get profile_path

    assert_redirected_to new_user_session_path
  end

  test "signed in users see only their own global profile" do
    sign_in @user

    assert_no_difference -> { RecordingStudio::Recording.count } do
      get profile_path
    end

    assert_response :success
    assert_includes response.body, @user.email
    refute_includes response.body, @other_user.email
    assert_select "a[href=?][aria-current='page']", profile_path, minimum: 1
    assert_includes response.body, "My profile"
  end

  test "updates only permitted fields on current user" do
    sign_in @user
    original_email = @user.email
    original_password = @user.encrypted_password

    patch profile_path, params: {
      user: {
        id: @other_user.id,
        first_name: "Updated",
        last_name: "Name",
        time_zone: "Pacific Time (US & Canada)",
        email: "hijacked@example.com",
        encrypted_password: "not-a-password"
      }
    }

    assert_redirected_to profile_path
    assert_equal "Your profile was updated.", flash[:notice]
    @user.reload
    @other_user.reload
    assert_equal "Updated Name", @user.full_name
    assert_equal "Pacific Time (US & Canada)", @user.time_zone
    assert_equal original_email, @user.email
    assert_equal original_password, @user.encrypted_password
    assert_equal "Other Person", @other_user.full_name
  end

  test "route never accepts a user identifier" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/profiles/#{@other_user.id}", method: :get)
    end
  end
end
