# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def test_engine_is_isolated
    assert RecordingStudioUsers::Engine.isolated?
  end

  def test_supported_dependency_floor
    specification = Gem::Specification.load(File.expand_path("../recording_studio_users.gemspec", __dir__))
    dependencies = specification.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement.to_s] }

    assert_equal ">= 4.1.0, < 5", dependencies.fetch("recording_studio")
    assert_equal ">= 0.6.1, < 1", dependencies.fetch("recording_studio_accessible")
    assert_equal ">= 0.5.0, < 1", dependencies.fetch("recording_studio_root_switchable")
    refute dependencies.key?("recording_studio_admin")
  end
end
