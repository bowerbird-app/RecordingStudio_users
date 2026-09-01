# frozen_string_literal: true

require "test_helper"

class OmniauthTest < Minitest::Test
  def test_normalized_email_strips_and_downcases_provider_email
    auth = auth_hash(email: "  Person@Example.COM ")

    assert_equal "person@example.com", RecordingStudioUser::Omniauth::IdentityFlow.normalized_email(auth)
  end

  def test_normalized_email_requires_an_email
    error = assert_raises(RecordingStudioUser::Omniauth::MissingEmailError) do
      RecordingStudioUser::Omniauth::IdentityFlow.normalized_email(auth_hash(email: nil))
    end

    assert_match(/Email is required/, error.message)
  end

  def test_normalized_email_rejects_explicitly_unverified_info_claim
    auth = auth_hash(email: "person@example.com", email_verified: false)

    assert_raises(RecordingStudioUser::Omniauth::UnverifiedEmailError) do
      RecordingStudioUser::Omniauth::IdentityFlow.normalized_email(auth)
    end
  end

  def test_normalized_email_rejects_explicitly_unverified_raw_claim
    auth = auth_hash(email: "person@example.com")
    auth[:extra] = { raw_info: { email_verified: "false" } }

    assert_raises(RecordingStudioUser::Omniauth::UnverifiedEmailError) do
      RecordingStudioUser::Omniauth::IdentityFlow.normalized_email(auth)
    end
  end

  def test_provider_labels_and_default_logos_exist_for_every_supported_provider
    RecordingStudioUser::Omniauth::PROVIDER_LABELS.each do |provider, label|
      assert_predicate label, :present?
      assert_match(/\A<svg/, RecordingStudioUser::Omniauth.default_logo(provider))
    end
  end

  def test_providers_from_credentials_skip_blank_and_commented_keys
    credentials = fake_credentials(
      omniauth: {
        google_oauth2: { client_id: "google-id", client_secret: "google-secret" },
        microsoft_graph: { client_id: "", client_secret: "secret" },
        apple: { client_id: nil, client_secret: nil },
        linkedin: { client_id: "li-id" },
        instagram: { client_id: "ig-id", client_secret: "ig-secret" }
      }
    )

    providers = RecordingStudioUser::Omniauth.providers_from_credentials(credentials)

    assert_equal %i[google_oauth2 instagram], providers.keys
    assert_equal "google-id", providers[:google_oauth2][:client_id]
    refute_includes providers, :microsoft_graph
    refute_includes providers, :apple
    refute_includes providers, :linkedin
  end

  def test_apple_is_ready_with_pem_when_client_secret_is_blank
    credentials = fake_credentials(
      omniauth: {
        apple: {
          client_id: "apple-id",
          client_secret: "",
          team_id: "team",
          key_id: "key",
          pem: "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"
        }
      }
    )

    providers = RecordingStudioUser::Omniauth.providers_from_credentials(credentials)

    assert_equal "apple-id", providers.dig(:apple, :client_id)
    assert_equal "", providers.dig(:apple, :client_secret)
  end

  def test_resolve_providers_prefers_an_assigned_hash
    assigned = { linkedin: { client_id: "explicit-id", client_secret: "explicit-secret" } }

    assert_equal assigned, RecordingStudioUser::Omniauth.resolve_providers(assigned)
  end

  def test_explicit_providers_win_over_credentials
    configuration = RecordingStudioUser::Configuration.new
    configuration.omniauth_providers = {
      linkedin: { client_id: "explicit-id", client_secret: "explicit-secret" }
    }

    assert_equal(
      { linkedin: { client_id: "explicit-id", client_secret: "explicit-secret" } },
      configuration.omniauth_providers
    )
    refute configuration.omniauth_provider_configured?(:google_oauth2)
  end

  private

  def fake_credentials(hash)
    Object.new.tap do |credentials|
      credentials.define_singleton_method(:dig) do |*keys|
        hash.dig(*keys)
      end
    end
  end


  def auth_hash(email:, email_verified: nil)
    info = { email: email }
    info[:email_verified] = email_verified unless email_verified.nil?
    OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "uid", info: info)
  end
end
