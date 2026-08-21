# frozen_string_literal: true

require "test_helper"

class UsersFlowTest < ActionDispatch::IntegrationTest
  def setup
    @password = "Password1!"
  end

  test "zero-root user is sent to onboarding" do
    user = create_user("new@example.com")
    sign_in_as(user)

    get "/"

    assert_redirected_to "/people"
  end

  test "creating the first workspace bootstraps admin access and selects it" do
    user = create_user("owner@example.com")
    sign_in_as(user)

    assert_difference("Workspace.count", 1) do
      post "/people/onboarding", params: { workspace: { name: "Fresh Studio" } }
    end

    workspace = Workspace.find_by!(name: "Fresh Studio")
    root = RecordingStudio.root_recording_for(workspace)
    assert_equal :admin, RecordingStudioAccessible.role_for(actor: user, recording: root)
    assert_redirected_to "/people/invitations?root_recording_id=#{root.id}"
    assert_equal root.id, RecordingStudio::RootSwitchable::Selection.order(:created_at).last.root_recording_id
  end

  test "invitation acceptance grants access and selects the workspace" do
    owner = create_user("owner@example.com")
    invitee = create_user("invitee@example.com")
    root = create_owned_root(owner)
    invitation, token = RecordingStudioUsers::Invitation.issue!(
      email: invitee.email,
      root_recording: root,
      role: :edit,
      inviter: owner
    )
    sign_in_as(invitee)

    post "/people/invitations/accept/#{token}"

    assert_equal "accepted", invitation.reload.status
    assert_equal :edit, RecordingStudioAccessible.role_for(actor: invitee, recording: root)
    assert_equal root.id, RecordingStudio::RootSwitchable::Selection.order(:created_at).last.root_recording_id
  end

  test "demoted admin cannot invite while accessible ceiling remains admin" do
    owner = create_user("owner@example.com")
    root = create_owned_root(owner)
    sign_in_as(owner)

    patch "/people/operating_role", params: { root_recording_id: root.id, role: "view" }
    assert_no_difference("RecordingStudioUsers::Invitation.count") do
      post "/people/invitations", params: {
        root_recording_id: root.id,
        invitation: { email: "blocked@example.com", role: "view" }
      }
    end

    assert_equal :admin, RecordingStudioAccessible.role_for(actor: owner, recording: root)
  end

  private

  def create_user(email)
    User.create!(email: email, password: @password, password_confirmation: @password)
  end

  def create_owned_root(owner)
    workspace = Workspace.create!(name: "Workspace #{SecureRandom.hex(3)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: owner)
    assert result.success?, result.error
    root
  end

  def sign_in_as(user)
    post "/users/sign_in", params: { user: { email: user.email, password: @password } }
    assert_response :redirect
  end
end
