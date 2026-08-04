# frozen_string_literal: true

require "test_helper"

class ResultTest < Minitest::Test
  def test_success_contract
    result = RecordingStudioUsers::Result.success(:profile)

    assert result.success?
    refute result.failure?
    assert_equal :profile, result.value
    assert_nil result.error
    assert_empty result.errors
  end

  def test_failure_contract
    result = RecordingStudioUsers::Result.failure("denied", errors: ["not editable"])

    refute result.success?
    assert result.failure?
    assert_nil result.value
    assert_equal "denied", result.error
    assert_equal ["not editable"], result.errors
  end
end
