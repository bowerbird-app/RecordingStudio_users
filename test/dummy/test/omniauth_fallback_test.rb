# frozen_string_literal: true

require "test_helper"

class OmniauthFallbackTest < ActiveSupport::TestCase
  test "dummy OmniAuth fallback uses placeholders instead of ENV secrets" do
    source = File.read(Rails.root.join("config/initializers/recording_studio_user.rb"))

    refute_includes source, "ENV["
    refute_includes source, "OMNIAUTH_TEST_MODE"
    assert_includes source, "providers_from_credentials"
    assert_includes source, "dev_placeholder"
    assert_includes source, "google_oauth2:"
    assert_includes source, "microsoft_graph:"
    assert_includes source, "apple:"
    assert_includes source, "linkedin:"
    assert_includes source, "instagram:"
    assert_includes source, "Rails.env.test?"
    assert_includes source, "Dummy::OmniauthFallbacks.providers"
  end

  test "test environment keeps every supported OmniAuth provider" do
    assert_equal(
      %i[google_oauth2 microsoft_graph apple linkedin instagram],
      RecordingStudioUser.config.omniauth_provider_names
    )
    assert_includes User.devise_modules, :omniauthable
  end
end
