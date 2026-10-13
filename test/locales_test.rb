# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_engine_does_not_append_i18n_load_path
    engine = File.read(File.expand_path("../lib/recording_studio_user/engine.rb", __dir__))

    refute_includes engine, 'initializer "recording_studio_user.i18n"'
    refute_includes engine, "i18n.load_path"
    refute_includes engine, "I18n.load_path"
  end

  def test_packaged_locales_have_no_probe_or_test_only_keys
    packaged = Gem::Specification.load(
      File.expand_path("../recording_studio_user.gemspec", __dir__)
    ).files.grep(%r{\Aconfig/locales/.*\.yml\z})

    assert_equal ["config/locales/en.yml"], packaged.sort

    packaged.each do |relative|
      source = File.read(File.expand_path("../#{relative}", __dir__))
      refute_match(/\bHOST\b/, source, "#{relative} must not ship HOST probe strings")
      refute_match(/\bprobe\b/i, source, "#{relative} must not ship probe keys")
      refute_match(/test[_-]?only/i, source, "#{relative} must not ship test-only keys")
    end
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "User", I18n.t("recording_studio_user.profile.unnamed_user")
      assert_equal "Welcome back", I18n.t("recording_studio_user.auth.login_title")
      assert_equal "Profile updated.", I18n.t("recording_studio_user.profile.updated")
      assert_equal "My Profile", I18n.t("recording_studio_user.profile.my_profile")
    end
  end

  def test_login_title_follows_english_until_the_host_overrides
    configuration = RecordingStudioUser::Configuration.new

    I18n.with_locale(:en) { assert_equal "Welcome back", configuration.login_title }

    configuration.login_title = "Sign in to Acme"
    I18n.with_locale(:en) { assert_equal "Sign in to Acme", configuration.login_title }
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio_user")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end
end
