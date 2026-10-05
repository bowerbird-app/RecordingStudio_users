# frozen_string_literal: true

require "test_helper"

class CredentialsTest < ActiveSupport::TestCase
  test "dummy credentials expose shared keys when the master key is available" do
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    credentials = Rails.application.credentials
    assert credentials.secret_key_base.present?
    assert_equal "dev_placeholder", credentials.dig(:gem_template, :api_key)
    assert_equal "dev_placeholder", credentials.dig(:smtp, :user_name)
    assert_equal "dev_placeholder", credentials.dig(:smtp, :password)
    assert_equal "dev_placeholder", credentials.dig(:aws, :access_key_id)
    assert_equal "dev_placeholder", credentials.dig(:aws, :secret_access_key)
    assert_equal "dev_placeholder", credentials.dig(:notifications, :from_email)
    assert_equal "dev_placeholder", credentials.dig(:omniauth, :google_oauth2, :client_id)
    assert_equal "dev_placeholder", credentials.dig(:omniauth, :google_oauth2, :client_secret)
  end

  test "dummy test credentials enable every supported OmniAuth provider" do
    assert_equal(
      %i[google_oauth2 microsoft_graph apple linkedin instagram],
      RecordingStudioUser.config.omniauth_provider_names
    )
    assert_includes User.devise_modules, :omniauthable
  end

  private

  def master_key_available?
    ENV["RAILS_MASTER_KEY"].to_s.strip.present? || File.exist?(Rails.root.join("config/master.key"))
  end
end
