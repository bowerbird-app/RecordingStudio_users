# frozen_string_literal: true

require "test_helper"

class OmniauthCredentialsTest < ActiveSupport::TestCase
  test "dummy test credentials enable every supported provider" do
    assert_equal(
      %i[google_oauth2 microsoft_graph apple linkedin instagram],
      RecordingStudioUser.config.omniauth_provider_names
    )
  end

  test "development credentials keep commented examples for unused providers" do
    encrypted = Rails.application.encrypted(
      Rails.root.join("config/credentials/development.yml.enc"),
      key_path: Rails.root.join("config/credentials/development.key")
    )
    contents = encrypted.read

    assert_includes contents, "google_oauth2:"
    assert_includes contents, "# microsoft_graph:"
    assert_includes contents, "#   client_id: your-microsoft-client-id"
    assert_includes contents, "# apple:"
    assert_includes contents, "# linkedin:"
    assert_includes contents, "# instagram:"
    assert_includes contents, "#   client_secret: your-instagram-client-secret"

    parsed = YAML.safe_load(contents, permitted_classes: [Symbol])
    omniauth = parsed.fetch("omniauth")
    assert omniauth.key?("google_oauth2")
    refute omniauth.key?("microsoft_graph")
    refute omniauth.key?("apple")
    refute omniauth.key?("linkedin")
    refute omniauth.key?("instagram")
  end
end
