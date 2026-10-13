# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

class LocalesTest < Minitest::Test
  def setup
    @previous_load_path = I18n.load_path.dup
    @previous_backend = I18n.backend
    @previous_locale = I18n.locale
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations(*Dir[File.join(engine_locales_dir, "*.yml")])
    I18n.locale = :en
  end

  def teardown
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    assert_equal @previous_load_path, I18n.load_path,
                 "locales tests must not mutate I18n.load_path"
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_engine_exposes_english_locale_paths
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    existent = RecordingStudioUser::Engine.paths["config/locales"].existent.map { |path| File.expand_path(path) }

    assert_includes existent, locale_path
  end

  def test_lib_sources_do_not_append_i18n_load_path
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  def test_dummy_french_covers_every_engine_english_key
    english_legacy = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en", "recording_studio_user"))
    french_legacy = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr", "recording_studio_user"))
    missing_legacy = english_legacy - french_legacy

    assert_empty missing_legacy,
                 "dummy fr.yml is missing recording_studio_user keys present in engine en.yml: #{missing_legacy.join(', ')}"

    english_nested = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en", "recording_studio", "users"))
    french_nested = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr", "recording_studio", "users"))
    missing_nested = english_nested - french_nested

    assert_empty missing_nested,
                 "dummy fr.yml is missing recording_studio.users keys present in engine en.yml: #{missing_nested.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "User", I18n.t("recording_studio_user.profile.unnamed_user")
      assert_equal "Welcome back", I18n.t("recording_studio_user.auth.login_title")
      assert_equal "Profile updated.", I18n.t("recording_studio_user.profile.updated")
      assert_equal "My Profile", I18n.t("recording_studio_user.profile.my_profile")
      assert_equal "Users", I18n.t("recording_studio.users.admin.section.title")
      assert_equal "Total users", I18n.t("recording_studio.users.admin.widget.total_users")
      assert_equal "User", RecordingStudioUser::Copy.legacy_t("profile.unnamed_user")
      assert_equal "Welcome back", RecordingStudioUser::Copy.legacy_t("auth.login_title")
    end
  end

  def test_legacy_first_lookup_prefers_host_legacy_override
    I18n.backend.store_translations(:en, {
                                      recording_studio_user: { profile: { updated: "HOST Legacy Profile updated." } },
                                      recording_studio: { users: { profile: { updated: "HOST Nested Profile updated." } } }
                                    })

    assert_equal "HOST Legacy Profile updated.",
                 RecordingStudioUser::Copy.legacy_t("profile.updated")
  end

  def test_legacy_first_lookup_falls_through_to_nested_when_legacy_missing
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations(:en, {
                                      recording_studio: { users: { profile: { updated: "Nested Profile updated." } } }
                                    })
    I18n.locale = :en

    assert_equal "Nested Profile updated.",
                 RecordingStudioUser::Copy.legacy_t("profile.updated")
  end

  def test_legacy_first_lookup_matches_bare_i18n_when_neither_key_exists
    I18n.backend = I18n::Backend::Simple.new
    I18n.locale = :en

    bare = I18n.t("recording_studio_user.profile.updated",
                  default: [:"recording_studio.users.profile.updated"])
    via_copy = RecordingStudioUser::Copy.legacy_t("profile.updated")

    assert_equal bare, via_copy
    assert_match(/translation missing/i, via_copy)
  end

  def test_copy_call_sites_do_not_pass_english_string_defaults
    roots = [
      File.expand_path("../lib", __dir__),
      File.expand_path("../app", __dir__)
    ]
    files = roots.flat_map { |root| Dir[File.join(root, "**", "*.{rb,erb}")] }

    offenders = files.select do |path|
      source = File.read(path)
      source.match?(/\b(?:Copy\.(?:legacy_)?t|rsu_t)\([^;\n]*default:\s*["']/)
    end

    assert_empty offenders,
                 "Copy.t / legacy_t / rsu_t must not pass English string default: in #{offenders.join(', ')}"
  end

  def test_login_title_follows_english_until_the_host_overrides
    configuration = RecordingStudioUser::Configuration.new

    I18n.with_locale(:en) { assert_equal "Welcome back", configuration.login_title }

    configuration.login_title = "Sign in to Acme"
    I18n.with_locale(:en) { assert_equal "Sign in to Acme", configuration.login_title }
  end

  def test_quoted_yes_no_style_keys_resolve_without_default
    # Guard against Psych loading bare yes/no/on/off as booleans if added later.
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en", "recording_studio", "users")
    booleanish = flatten_keys(tree).grep(/(^|\.)(yes|no|on|off|true|false|null)$/i)

    booleanish.each do |key|
      assert_kind_of String, I18n.t("recording_studio.users.#{key}"),
                     "booleanish key recording_studio.users.#{key} must resolve to a String"
    end
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale, *segments)
    yaml = YAML.safe_load_file(path, aliases: true)
    segments.reduce(yaml.fetch(locale)) { |node, segment| node.fetch(segment) }
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end
end
