# frozen_string_literal: true

require "test_helper"

class CreateFirstRootTest < Minitest::Test
  Actor = Struct.new(:id) do
    def persisted?
      true
    end

    def with_lock
      yield
    rescue ActiveRecord::Rollback
      nil
    end
  end

  def setup
    RecordingStudioUsers.reset_configuration!
    RecordingStudioUsers.configuration.root_creator = ->(**) { :shared_recordable }
  end

  def teardown
    RecordingStudioUsers.reset_configuration!
  end

  def test_rejects_shared_root_without_bootstrapping_owner
    actor = Actor.new("actor-1")
    recording = Struct.new(:id).new("root-1")
    bootstrap = lambda do |**|
      flunk "Shared roots must never receive bootstrap owner access"
    end

    RecordingStudioAccessible.stub(:root_recordings_for, []) do
      RecordingStudioAccessible.stub(:bootstrap_owner_access!, bootstrap) do
        RecordingStudio.stub(:root_recording_for, recording) do
          RecordingStudio.stub(:root_recording?, true) do
            RecordingStudio.stub(:shared_root?, true) do
              result = RecordingStudioUsers::Services::CreateFirstRoot.call(
                name: "Shared",
                actor: actor
              )

              assert result.failure?
              assert_equal "That root cannot be bootstrapped", result.error
            end
          end
        end
      end
    end
  end

  def test_rejects_blank_name
    result = RecordingStudioUsers::Services::CreateFirstRoot.call(name: " ", actor: Actor.new("actor-1"))

    assert result.failure?
    assert_equal "Give your workspace a name", result.error
  end
end
