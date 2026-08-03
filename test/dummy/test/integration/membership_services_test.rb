# frozen_string_literal: true

require "test_helper"

class MembershipServicesTest < ActiveSupport::TestCase
  setup do
    @original_authorizer = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    @manager = create_user("manager")
    @member = create_user("member")
    @recording = RecordingStudio.root_recording_for(
      Workspace.create!(name: "Membership Workspace #{SecureRandom.hex(4)}")
    )
    @manager_access = grant(@manager, :admin)
  end

  teardown do
    RecordingStudioAccessible.configuration.access_management_authorizer = @original_authorizer
  end

  test "grant delegates membership persistence to Recording Studio Accessible" do
    result = RecordingStudioUsers::Services::GrantMembership.call(
      recording: @recording,
      user: @member,
      role: :edit,
      manager_actor: @manager
    )

    assert_predicate result, :success?
    assert_equal "edit", direct_access_for(@member).recordable.role
  end

  test "final admin cannot be demoted" do
    result = RecordingStudioUsers::Services::ChangeMembershipRole.call(
      recording: @recording,
      access_recording: @manager_access,
      role: :view,
      manager_actor: @manager
    )

    assert_predicate result, :failure?
    assert_equal RecordingStudioUsers::Services::MembershipGuard::FINAL_ADMIN_ERROR, result.error
    assert_equal "admin", direct_access_for(@manager).recordable.role
  end

  test "final admin cannot be revoked" do
    result = RecordingStudioUsers::Services::RevokeMembership.call(
      recording: @recording,
      access_recording: @manager_access,
      manager_actor: @manager
    )

    assert_predicate result, :failure?
    assert direct_access_for(@manager)
  end

  test "an admin can be demoted when another admin remains" do
    grant(@member, :admin)

    result = RecordingStudioUsers::Services::ChangeMembershipRole.call(
      recording: @recording,
      access_recording: @manager_access,
      role: :edit,
      manager_actor: @manager
    )

    assert_predicate result, :success?
    assert_equal "edit", direct_access_for(@manager).recordable.role
  end

  private

  def create_user(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!"
    )
  end

  def grant(user, role)
    RecordingStudioAccessible.grant_access(
      recording: @recording,
      actor: user,
      role: role,
      manager_actor: @manager
    ).value!
  end

  def direct_access_for(user)
    RecordingStudioAccessible::DirectAccessQuery
      .access_recordings_for_actor(recording: @recording, actor: user)
      .includes(:recordable)
      .first
  end
end
