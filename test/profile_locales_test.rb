# frozen_string_literal: true

require "test_helper"

class ProfileLocalesTest < Minitest::Test
  def setup
    @previous_locales = I18n.available_locales
    @previous_default = I18n.default_locale
    @previous_locale = I18n.locale
    I18n.available_locales = %i[en]
    I18n.default_locale = :en
    I18n.locale = :en
  end

  def teardown
    I18n.available_locales = @previous_locales
    I18n.default_locale = @previous_default
    restored_locale = @previous_locale.to_sym
    I18n.locale =
      if @previous_locales.map(&:to_sym).include?(restored_locale)
        restored_locale
      else
        @previous_default
      end
    Object.send(:remove_const, :RecordingStudioInternationalization) if
      defined?(RecordingStudioInternationalization)
  end

  def test_locale_is_allowlisted_by_default
    assert_includes RecordingStudioUser.config.additional_profile_attributes, :locale
    assert RecordingStudioUser::ProfileLocales.allowlisted?
  end

  def test_options_follow_i18n_available_locales
    I18n.available_locales = %i[en fr]

    assert_equal [%w[English en], %w[Français fr]], RecordingStudioUser::ProfileLocales.options
    refute_includes RecordingStudioUser::ProfileLocales.options, %w[日本語 ja]
  end

  def test_options_include_only_the_host_locales
    I18n.available_locales = %i[en de]

    assert_equal [%w[English en], %w[de de]], RecordingStudioUser::ProfileLocales.options
  end

  def test_select_options_lead_with_default_language_name
    I18n.available_locales = %i[en fr]

    I18n.with_locale(:en) do
      options = RecordingStudioUser::ProfileLocales.select_options

      assert_equal ["Default English", ""], options.first
      assert_includes options, %w[Français fr]
    end
  end

  def test_select_options_follow_i18n_default_locale
    I18n.available_locales = %i[en fr]
    I18n.default_locale = :fr

    I18n.with_locale(:en) do
      assert_equal ["Default Français", ""], RecordingStudioUser::ProfileLocales.select_options.first
    end
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
  end

  def test_internationalization_available_locales_win_over_i18n
    intl = Module.new do
      def self.configuration
        locale = Struct.new(:name, :code)
        Struct.new(:default_locale, :available_locales).new(
          :en,
          [locale.new("Deutsch", "de"), locale.new("Italiano", "it")]
        )
      end
    end
    Object.const_set(:RecordingStudioInternationalization, intl)
    I18n.available_locales = %i[en fr]

    assert_equal [%w[Deutsch de], %w[Italiano it]], RecordingStudioUser::ProfileLocales.options
  end

  def test_label_for_known_and_blank_codes
    I18n.available_locales = %i[en fr]

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

  def test_without_internationalization_falls_back_to_i18n_available_locales
    refute defined?(RecordingStudioInternationalization)
    assert_nil RecordingStudioUser::ProfileLocales.from_internationalization
    assert_equal RecordingStudioUser::ProfileLocales.from_available_locales,
                 RecordingStudioUser::ProfileLocales.options
    assert_equal [%w[English en]], RecordingStudioUser::ProfileLocales.options
  end
end
