# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  def test_french_locale_has_every_english_key
    english = flatten_keys(locale_tree("en.yml"))
    french = flatten_keys(locale_tree("fr.yml"))
    missing = english - french

    assert_empty missing, "fr.yml is missing keys present in en.yml: #{missing.join(', ')}"
  end

  def test_unnamed_user_key_still_resolves
    I18n.with_locale(:en) do
      assert_equal "User", I18n.t("recording_studio_user.profile.unnamed_user")
    end
    I18n.with_locale(:fr) do
      assert_equal "Utilisateur", I18n.t("recording_studio_user.profile.unnamed_user")
    end
  end

  def test_login_title_follows_locale_until_the_host_overrides
    configuration = RecordingStudioUser::Configuration.new

    I18n.with_locale(:en) { assert_equal "Welcome back", configuration.login_title }
    I18n.with_locale(:fr) { assert_equal "Heureux de vous revoir", configuration.login_title }

    configuration.login_title = "Sign in to Acme"
    I18n.with_locale(:fr) { assert_equal "Sign in to Acme", configuration.login_title }
  end

  private

  def locale_tree(filename)
    path = File.expand_path("../config/locales/#{filename}", __dir__)
    yaml = YAML.safe_load_file(path, aliases: true)
    locale = File.basename(filename, ".yml")
    yaml.fetch(locale).fetch("recording_studio_user")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end
end
