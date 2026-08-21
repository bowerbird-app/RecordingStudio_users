# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  Recording = Data.define(:id)

  def setup
    @recording = Recording.new(id: "root-1")
    @actor = Object.new
    @session = {}
  end

  def test_operating_role_defaults_to_accessible_ceiling
    with_ceiling(:admin) do
      assert_equal :admin, RecordingStudioUsers.current_operating_role(
        actor: @actor,
        recording: @recording,
        session: @session
      )
    end
  end

  def test_operating_role_can_demote_without_changing_ceiling
    with_ceiling(:admin) do
      role = RecordingStudioUsers.set_operating_role!(
        actor: @actor,
        recording: @recording,
        role: :view,
        session: @session
      )

      assert_equal :view, role
      assert_equal :admin, RecordingStudioAccessible.role_for(actor: @actor, recording: @recording)
      refute RecordingStudioUsers.authorized_operating?(
        actor: @actor,
        recording: @recording,
        role: :admin,
        session: @session
      )
    end
  end

  def test_viewer_cannot_promote_operating_role
    with_ceiling(:view) do
      assert_raises(RecordingStudioUsers::Authorization::NotAuthorized) do
        RecordingStudioUsers.set_operating_role!(
          actor: @actor,
          recording: @recording,
          role: :admin,
          session: @session
        )
      end
    end
  end

  def test_both_mode_blocks_demoted_admin
    with_ceiling(:admin) do
      RecordingStudioUsers.set_operating_role!(
        actor: @actor,
        recording: @recording,
        role: :view,
        session: @session
      )

      assert_raises(RecordingStudioUsers::Authorization::NotAuthorized) do
        RecordingStudioUsers.authorize!(
          actor: @actor,
          recording: @recording,
          role: :admin,
          mode: :both,
          session: @session
        )
      end
      assert RecordingStudioUsers.authorize!(
        actor: @actor,
        recording: @recording,
        role: :admin,
        mode: :ceiling,
        session: @session
      )
    end
  end

  private

  def with_ceiling(role)
    role_for = ->(**) { role }
    authorized = lambda do |role: nil, **|
      RecordingStudio::AccessRoles.satisfies?(role: role_for.call, minimum_role: role)
    end

    RecordingStudioAccessible.stub(:role_for, role_for) do
      RecordingStudioAccessible.stub(:authorized?, authorized) { yield }
    end
  end
end
