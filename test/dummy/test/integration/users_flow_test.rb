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

    assert_redirected_to "/people/onboarding"
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Set up your workspace"
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

  test "admin invitation creates pending invitation and queues absolute email" do
    owner = create_user("owner@example.com")
    root = create_owned_root(owner)
    sign_in_as(owner)

    assert_enqueued_emails 1 do
      assert_difference("RecordingStudioUsers::Invitation.count", 1) do
        post "/people/invitations", params: {
          root_recording_id: root.id,
          invitation: { email: "new-person@example.com", role: "edit" }
        }
      end
    end

    invitation = RecordingStudioUsers::Invitation.order(:created_at).last
    assert_equal "pending", invitation.status
    assert_equal "edit", invitation.role
    assert_redirected_to "/people/invitations?root_recording_id=#{root.id}"
  end

  test "write with an inaccessible root id does not fall back to another workspace" do
    owner = create_user("owner@example.com")
    create_owned_root(owner)
    sign_in_as(owner)

    assert_no_difference("RecordingStudioUsers::Invitation.count") do
      post "/people/invitations", params: {
        root_recording_id: SecureRandom.uuid,
        invitation: { email: "blocked@example.com", role: "view" }
      }
    end

    assert_response :not_found
  end

  test "wrong email and expired invitations do not grant access" do
    owner = create_user("owner@example.com")
    invitee = create_user("invitee@example.com")
    wrong_user = create_user("wrong@example.com")
    root = create_owned_root(owner)
    _invitation, token = RecordingStudioUsers::Invitation.issue!(
      email: invitee.email,
      root_recording: root,
      role: :view,
      inviter: owner
    )

    result = RecordingStudioUsers::Services::AcceptInvitation.call(token: token, actor: wrong_user)
    assert result.failure?
    assert_nil RecordingStudioAccessible.role_for(actor: wrong_user, recording: root)

    _expired, expired_token = RecordingStudioUsers::Invitation.issue!(
      email: invitee.email,
      root_recording: root,
      role: :view,
      inviter: owner,
      expires_at: 1.minute.ago
    )
    result = RecordingStudioUsers::Services::AcceptInvitation.call(token: expired_token, actor: invitee)
    assert result.failure?
    assert_nil RecordingStudioAccessible.role_for(actor: invitee, recording: root)
  end

  test "signed-out recipient returns to the invitation after login" do
    owner = create_user("owner@example.com")
    invitee = create_user("invitee@example.com")
    root = create_owned_root(owner)
    _invitation, token = RecordingStudioUsers::Invitation.issue!(
      email: invitee.email,
      root_recording: root,
      role: :view,
      inviter: owner
    )

    get "/people/invitations/accept/#{token}"
    assert_redirected_to "/users/sign_in"

    post "/users/sign_in", params: { user: { email: invitee.email, password: @password } }
    assert_redirected_to "/people/invitations/accept/#{token}"
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Join the workspace"
  end

  test "invitation fails closed when inviter is no longer an admin" do
    owner = create_user("owner@example.com")
    replacement_admin = create_user("replacement@example.com")
    invitee = create_user("invitee@example.com")
    root = create_owned_root(owner)
    replacement_grant = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: replacement_admin,
      role: :admin,
      manager_actor: owner
    )
    invitation, token = RecordingStudioUsers::Invitation.issue!(
      email: invitee.email,
      root_recording: root,
      role: :view,
      inviter: owner
    )
    owner_access = RecordingStudioAccessible.access_recordings_for_actor(recording: root, actor: owner).first
    revoke = RecordingStudioAccessible::Services::RevokeRecordingAccess.call(
      recording: root,
      access_recording: owner_access,
      manager_actor: replacement_admin
    )
    assert replacement_grant.success?
    assert revoke.success?

    result = RecordingStudioUsers::Services::AcceptInvitation.call(token: token, actor: invitee)

    assert result.failure?
    assert_equal "pending", invitation.reload.status
    assert_nil RecordingStudioAccessible.role_for(actor: invitee, recording: root)
  end

  test "admin changes and revokes membership through Accessible" do
    owner = create_user("owner@example.com")
    member = create_user("member@example.com")
    root = create_owned_root(owner)
    grant = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: member,
      role: :edit,
      manager_actor: owner
    )
    assert grant.success?, grant.error
    sign_in_as(owner)

    patch "/people/memberships/#{grant.value.id}", params: {
      root_recording_id: root.id,
      membership: { role: "view" }
    }
    assert_equal :view, RecordingStudioAccessible.role_for(actor: member, recording: root)

    delete "/people/memberships/#{grant.value.id}", params: { root_recording_id: root.id }
    assert_nil RecordingStudioAccessible.role_for(actor: member, recording: root)
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

  test "admin can render the Flatpack people screen" do
    owner = create_user("owner@example.com")
    root = create_owned_root(owner)
    sign_in_as(owner)

    get "/people/invitations", params: { root_recording_id: root.id }

    assert_response :success
    assert_includes response.body, "Invite someone"
    assert_includes response.body, "Working role"
  end

  test "accept screen posts from a form the browser can submit" do
    owner = create_user("owner@example.com")
    invitee = create_user("invitee@example.com")
    root = create_owned_root(owner)
    _invitation, token = RecordingStudioUsers::Invitation.issue!(
      email: invitee.email,
      root_recording: root,
      role: :view,
      inviter: owner
    )
    sign_in_as(invitee)

    get "/people/invitations/accept/#{token}"

    assert_response :success
    assert_select "form[action=?][method=?]", "/people/invitations/accept/#{token}", "post" do
      assert_select "button[type=submit]", count: 1
    end
    assert_select "button button", false, "a button nested in a button cannot be clicked"
  end

  test "people screen membership controls are submittable" do
    owner = create_user("owner@example.com")
    member = create_user("member@example.com")
    root = create_owned_root(owner)
    grant = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: member,
      role: :edit,
      manager_actor: owner
    )
    assert grant.success?, grant.error
    sign_in_as(owner)

    get "/people/invitations", params: { root_recording_id: root.id }

    assert_response :success
    membership_action = "/people/memberships/#{grant.value.id}?root_recording_id=#{root.id}"
    assert_select "form[action=?]", membership_action, count: 2
    assert_select "form[action=?] button[type=submit]", membership_action, count: 2
    assert_select "button button", false, "a button nested in a button cannot be clicked"
  end

  test "invitation mail contains an absolute mounted URL" do
    owner = create_user("owner@example.com")
    root = create_owned_root(owner)
    invitation, token = RecordingStudioUsers::Invitation.issue!(
      email: "mail@example.com",
      root_recording: root,
      role: :view,
      inviter: owner
    )

    mail = RecordingStudioUsers::InvitationMailer.with(invitation: invitation, token: token).invite

    assert_includes mail.body.encoded, "http://example.com/people/invitations/accept/#{token}"
    assert_equal ["users@example.com"], mail.from
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
