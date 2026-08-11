# frozen_string_literal: true

require "test_helper"

class ProfilePreferencesTest < Minitest::Test
  def test_locale_options_use_all_host_locales_as_sorted_bcp_47_tags
    I18n.stub(:available_locales, [:fr, :en_GB, :"en-GB", :en, :fr]) do
      assert_equal [
        ["en", "en"],
        ["en-GB", "en-GB"],
        ["fr", "fr"]
      ], RecordingStudioUsers::ProfilePreferences.locale_options
    end
  end

  def test_time_zone_options_store_iana_identifiers_and_show_current_offsets
    at = Time.utc(2026, 1, 15, 12)
    options = RecordingStudioUsers::ProfilePreferences.time_zone_options(at:)
    new_york = options.find { |_label, value| value == "America/New_York" }

    assert_equal ["(UTC-05:00) America/New York", "America/New_York"], new_york
    assert_equal options.map(&:last).uniq, options.map(&:last)
    assert_match(/\A\(UTC[+-]\d{2}:\d{2}\) /, options.first.first)
  end

  def test_time_zone_options_are_sorted_by_offset_then_label
    at = Time.utc(2026, 1, 15, 12)
    options = RecordingStudioUsers::ProfilePreferences.time_zone_options(at:)
    sortable = options.map do |label, value|
      offset = TZInfo::Timezone.get(value).period_for_utc(at).utc_total_offset
      [offset, label, value]
    end

    assert_equal sortable.sort, sortable
  end

  def test_with_legacy_value_preserves_unknown_values_without_duplicates
    options = [["en-US", "en-US"]]

    assert_equal options, RecordingStudioUsers::ProfilePreferences.with_legacy_value(options, "en-US")
    assert_equal ["en AU (saved value)", "en_AU"],
                 RecordingStudioUsers::ProfilePreferences.with_legacy_value(options, "en_AU").last
  end
end