# frozen_string_literal: true

require "test_helper"
require "yaml"
require "active_support/encrypted_file"

class DummyCredentialsTest < Minitest::Test
  PLACEHOLDER = "dev_placeholder"

  TRACKED_CREDENTIALS = [
    "test/dummy/config/credentials.yml.enc",
    "test/dummy/config/credentials/development.yml.enc",
    "test/dummy/config/credentials/test.yml.enc"
  ].freeze

  def test_only_dummy_credentials_files_are_committed
    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- '*.yml.enc'`.split("\n").reject(&:empty?).sort
    end

    assert_equal TRACKED_CREDENTIALS.sort, tracked
  end

  def test_encrypted_credentials_files_are_present
    TRACKED_CREDENTIALS.each do |relative|
      path = File.expand_path("../#{relative}", __dir__)
      assert File.exist?(path), "Expected #{path} for shared dummy credentials"
      assert File.size(path).positive?
    end
  end

  def test_master_key_is_gitignored_and_untracked
    gitignore = File.read(File.expand_path("../.gitignore", __dir__))
    assert_includes gitignore, "test/dummy/config/master.key"
    assert_includes gitignore, "config/master.key"
    assert_includes gitignore, "test/dummy/config/credentials/*.key"
    refute_includes gitignore, "!test/dummy/config/credentials/development.key"
    refute_includes gitignore, "!test/dummy/config/credentials/test.key"

    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- config/master.key test/dummy/config/master.key test/dummy/config/credentials/*.key`.strip
    end
    assert_equal "", tracked, "credential key files must not be committed"
  end

  def test_dummy_credentials_decrypt_when_master_key_is_available
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    parsed = YAML.safe_load(
      ActiveSupport::EncryptedFile.new(
        content_path: dummy_credentials_path,
        key_path: dummy_master_key_path,
        env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true
      ).read
    )

    assert_operator parsed.fetch("secret_key_base").to_s.length, :>=, 64
    assert_equal PLACEHOLDER, parsed.dig("gem_template", "api_key")
    assert_equal PLACEHOLDER, parsed.dig("smtp", "user_name")
    assert_equal PLACEHOLDER, parsed.dig("smtp", "password")
    assert_equal PLACEHOLDER, parsed.dig("aws", "access_key_id")
    assert_equal PLACEHOLDER, parsed.dig("aws", "secret_access_key")
    assert_equal PLACEHOLDER, parsed.dig("notifications", "from_email")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "google_oauth2", "client_id")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "google_oauth2", "client_secret")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "microsoft_graph", "client_id")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "microsoft_graph", "client_secret")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "apple", "client_id")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "apple", "client_secret")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "apple", "team_id")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "apple", "key_id")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "apple", "pem")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "linkedin", "client_id")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "linkedin", "client_secret")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "instagram", "client_id")
    assert_equal PLACEHOLDER, parsed.dig("omniauth", "instagram", "client_secret")
  end

  def test_environment_credentials_decrypt_when_master_key_is_available
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    development = decrypt_yaml(
      "test/dummy/config/credentials/development.yml.enc",
      "test/dummy/config/credentials/development.key"
    )
    test_creds = decrypt_yaml(
      "test/dummy/config/credentials/test.yml.enc",
      "test/dummy/config/credentials/test.key"
    )

    assert_operator development.fetch("secret_key_base").to_s.length, :>=, 64
    assert_equal PLACEHOLDER, development.dig("omniauth", "google_oauth2", "client_id")
    refute development.fetch("omniauth").key?("microsoft_graph")

    assert_operator test_creds.fetch("secret_key_base").to_s.length, :>=, 64
    %w[google_oauth2 microsoft_graph apple linkedin instagram].each do |provider|
      assert_equal PLACEHOLDER, test_creds.dig("omniauth", provider, "client_id")
      assert_equal PLACEHOLDER, test_creds.dig("omniauth", provider, "client_secret")
    end
  end

  def test_dummy_omniauth_fallback_does_not_use_env_secrets
    initializer = File.read(File.expand_path("../test/dummy/config/initializers/recording_studio_user.rb", __dir__))
    workflow = File.read(File.expand_path("../.github/workflows/ci.yml", __dir__))

    assert_includes initializer, "providers_from_credentials"
    assert_includes initializer, "Dummy::OmniauthFallbacks"
    assert_includes initializer, "dev_placeholder"
    refute_includes initializer, "ENV["
    refute_includes workflow, "secrets.RAILS_MASTER_KEY"
    refute_includes workflow, "RAILS_MASTER_KEY"
  end

  def test_dummy_development_boots_google_omniauth_without_a_master_key
    output = boot_dummy_without_master_key("development")

    assert_includes output, "BOOT_OK"
    assert_includes output, "providers=google_oauth2"
    refute_includes output, "microsoft_graph"
  end

  def test_dummy_test_boots_every_omniauth_provider_without_a_master_key
    output = boot_dummy_without_master_key("test")

    assert_includes output, "BOOT_OK"
    assert_includes output, "providers=google_oauth2,microsoft_graph,apple,linkedin,instagram"
  end

  private

  def dummy_credentials_path
    File.expand_path("../test/dummy/config/credentials.yml.enc", __dir__)
  end

  def dummy_master_key_path
    File.expand_path("../test/dummy/config/master.key", __dir__)
  end

  def decrypt_yaml(content_relative, key_relative)
    YAML.safe_load(
      ActiveSupport::EncryptedFile.new(
        content_path: File.expand_path("../#{content_relative}", __dir__),
        key_path: File.expand_path("../#{key_relative}", __dir__),
        env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true
      ).read
    )
  end

  def master_key_available?
    ENV["RAILS_MASTER_KEY"].to_s.strip.present? || File.exist?(dummy_master_key_path)
  end

  def boot_dummy_without_master_key(rails_env)
    dummy = File.expand_path("../test/dummy", __dir__)
    hidden = hide_dummy_key_files(dummy)
    env = ENV.to_h.except("RAILS_MASTER_KEY").merge(
      "BUNDLE_GEMFILE" => File.join(dummy, "Gemfile"),
      "RAILS_ENV" => rails_env,
      "DISABLE_SIMPLECOV" => "true"
    )
    command = [
      "bundle", "exec", "rails", "runner",
      <<~'RUBY'.strip
        names = RecordingStudioUser.config.omniauth_provider_names
        puts "BOOT_OK"
        puts "providers=#{names.join(",")}"
      RUBY
    ]
    output = Bundler.with_unbundled_env do
      Dir.chdir(dummy) { IO.popen(env, command, err: %i[child out], &:read) }
    end
    status = Process.last_status
    assert status.success?, output
    output
  ensure
    restore_dummy_key_files(hidden)
  end

  def hide_dummy_key_files(dummy)
    %w[
      config/master.key
      config/credentials/development.key
      config/credentials/test.key
    ].filter_map do |relative|
      path = File.join(dummy, relative)
      next unless File.exist?(path)

      hidden = "#{path}.hidden-for-test"
      File.rename(path, hidden)
      [path, hidden]
    end
  end

  def restore_dummy_key_files(hidden)
    Array(hidden).each do |original, backup|
      File.rename(backup, original) if backup && File.exist?(backup)
    end
  end
end
