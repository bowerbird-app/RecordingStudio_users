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

  private

  def auth_hash(email:, email_verified: nil)
    info = { email: email }
    info[:email_verified] = email_verified unless email_verified.nil?
    OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "uid", info: info)
  end
end
