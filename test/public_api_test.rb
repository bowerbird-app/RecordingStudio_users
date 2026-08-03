# frozen_string_literal: true

require "test_helper"

class PublicApiTest < Minitest::Test
  FakeUser = Struct.new(:id, :persisted?)

  def test_user_class_delegates_to_configuration
    RecordingStudioUsers.configuration.stub(:user_class, String) do
      assert_equal String, RecordingStudioUsers.user_class
    end
  end

  def test_provision_uses_resolved_provisioning_actor_when_actor_is_nil
    expected_user = FakeUser.new("user-1", true)
    expected_actor = FakeUser.new("actor-1", true)
    result = RecordingStudioUsers::Services::BaseService::Result.new(
      success: true,
      value: { user_root: :ok }
    )

    RecordingStudioUsers.configuration.stub(:provisioning_actor_for, expected_actor) do
      RecordingStudioUsers::Services::ProvisionUser.stub(
        :call,
        ->(user:, actor:) do
          assert_same expected_user, user
          assert_same expected_actor, actor
          result
        end
      ) do
        assert_equal({ user_root: :ok }, RecordingStudioUsers.provision(expected_user, actor: nil))
      end
    end
  end

  def test_validate_user_profile_requires_persisted_user
    user = FakeUser.new("user-1", false)

    error = assert_raises(ArgumentError) { RecordingStudioUsers.validate_user_profile!(user) }
    assert_equal "User must be persisted", error.message
  end
end
