# frozen_string_literal: true

require "test_helper"

class ProfileLocalesTest < Minitest::Test
  def test_locale_is_allowlisted_by_default
    assert_includes RecordingStudioUser.config.additional_profile_attributes, :locale
    assert RecordingStudioUser::ProfileLocales.allowlisted?
  end

  def test_starting_set_matches_internationalization_dummy_languages
    assert_equal(
      [%w[English en], %w[Français fr], %w[日本語 ja]],
      RecordingStudioUser::ProfileLocales.options
    )
  end

  def test_select_options_lead_with_default_language_name
    I18n.with_locale(:en) do
      options = RecordingStudioUser::ProfileLocales.select_options

      assert_equal ["Default English", ""], options.first
      assert_includes options, %w[Français fr]
    end
    I18n.with_locale(:fr) do
      assert_equal ["Par défaut (English)", ""], RecordingStudioUser::ProfileLocales.select_options.first
    end
  end

  def test_select_options_follow_i18n_default_locale
    previous = I18n.default_locale
    I18n.default_locale = :fr

    I18n.with_locale(:en) do
      assert_equal ["Default Français", ""], RecordingStudioUser::ProfileLocales.select_options.first
    end
  ensure
    I18n.default_locale = previous
  end

  def test_select_options_follow_internationalization_default_locale
    intl = Module.new do
      def self.configuration
        Struct.new(:default_locale, :available_locales).new(:ja, nil)
      end
    end
    Object.const_set(:RecordingStudioInternationalization, intl)

    I18n.with_locale(:en) do
      assert_equal ["Default 日本語", ""], RecordingStudioUser::ProfileLocales.select_options.first
    end
  ensure
    Object.send(:remove_const, :RecordingStudioInternationalization) if
      defined?(RecordingStudioInternationalization)
  end

  def test_label_for_known_and_blank_codes
    assert_equal "English", RecordingStudioUser::ProfileLocales.label_for("en")
    assert_equal "Français", RecordingStudioUser::ProfileLocales.label_for("fr")
    assert_nil RecordingStudioUser::ProfileLocales.label_for("")
    assert_nil RecordingStudioUser::ProfileLocales.label_for(nil)
  end

  def test_unknown_saved_code_stays_on_the_select
    options = RecordingStudioUser::ProfileLocales.options("pt-BR")

    assert_includes options, %w[pt-BR pt-BR]
    assert_equal "pt-BR", RecordingStudioUser::ProfileLocales.label_for("pt-BR")
  end

  def test_without_internationalization_falls_back_to_the_starting_set
    refute defined?(RecordingStudioInternationalization)
    assert_nil RecordingStudioUser::ProfileLocales.from_internationalization
    assert_equal RecordingStudioUser::ProfileLocales::STARTING_SET, RecordingStudioUser::ProfileLocales.options
  end
end
