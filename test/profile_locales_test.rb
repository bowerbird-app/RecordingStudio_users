# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ProfileLocalesTest < Minitest::Test
  def test_locale_is_allowlisted_by_default
    assert_includes RecordingStudioUser.config.additional_profile_attributes, :locale
    assert RecordingStudioUser::ProfileLocales.allowlisted?
  end

  def test_starting_set_matches_internationalization_dummy_languages
    assert_equal(
      [["English", "en"], ["Français", "fr"], ["日本語", "ja"]],
      RecordingStudioUser::ProfileLocales.options
    )
  end

  def test_select_options_lead_with_site_default
    options = RecordingStudioUser::ProfileLocales.select_options

    assert_equal ["Use the site default", ""], options.first
    assert_includes options, ["Français", "fr"]
  end

  def test_label_for_known_and_blank_codes
    assert_equal "English", RecordingStudioUser::ProfileLocales.label_for("en")
    assert_equal "Français", RecordingStudioUser::ProfileLocales.label_for("fr")
    assert_nil RecordingStudioUser::ProfileLocales.label_for("")
    assert_nil RecordingStudioUser::ProfileLocales.label_for(nil)
  end

  def test_unknown_saved_code_stays_on_the_select
    options = RecordingStudioUser::ProfileLocales.options("pt-BR")

    assert_includes options, ["pt-BR", "pt-BR"]
    assert_equal "pt-BR", RecordingStudioUser::ProfileLocales.label_for("pt-BR")
  end

  def test_internationalization_locales_win_when_that_gem_is_loaded
    RecordingStudioUser::ProfileLocales.stub :from_internationalization, [["Deutsch", "de"]] do
      assert_equal [["Deutsch", "de"]], RecordingStudioUser::ProfileLocales.options
      assert_equal "Deutsch", RecordingStudioUser::ProfileLocales.label_for("de")
    end
  end
end
