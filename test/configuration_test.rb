# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioUsers::Configuration.new
  end

  def test_defaults_fail_closed
    user = Object.new

    refute RecordingStudioUsers.call_configured(@configuration.search_authorizer, actor: user)
    assert_equal %i[display_name biography locale time_zone], @configuration.profile_fields
    assert_equal({ small: :square_small, medium: :square_med, large: :square_large },
                 @configuration.avatar_variant_mapping)
  end

  def test_to_h_redacts_callables_and_actor_records
    actor = Object.new
    @configuration.provisioning_actor = ->(**) { actor }
    @configuration.external_avatar_resolver = ->(**) { "https://example.test/avatar" }

    result = @configuration.to_h

    assert_equal :configured, result[:provisioning_actor]
    assert_equal :configured, result[:external_avatar_resolver]
    refute_includes result.values, actor
    refute result.key?(:tokens)
  end

  def test_validate_rejects_unknown_profile_fields
    @configuration.profile_fields = %i[display_name encrypted_password]

    error = assert_raises(RecordingStudioUsers::ConfigurationError) { @configuration.validate! }

    assert_includes error.message, "encrypted_password"
  end

  def test_validate_rejects_unknown_avatar_size
    @configuration.avatar_variant_mapping = { tiny: :square_small }

    assert_raises(RecordingStudioUsers::ConfigurationError) { @configuration.validate! }
  end

  def test_validate_rejects_non_image_avatar_types
    @configuration.avatar_content_types = ["image/png", "application/pdf"]

    assert_raises(RecordingStudioUsers::ConfigurationError) { @configuration.validate! }
  end

  def test_validate_rejects_untrusted_variants
    @configuration.avatar_variant_mapping[:medium] = :request_controlled

    assert_raises(RecordingStudioUsers::ConfigurationError) { @configuration.validate! }
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!("picker_limit" => 12, "unknown" => true)

    assert_equal 12, @configuration.picker_limit
    refute_respond_to @configuration, :unknown
  end
end
