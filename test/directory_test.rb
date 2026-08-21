# frozen_string_literal: true

require "test_helper"

class DirectoryTest < Minitest::Test
  def test_display_name_falls_back_to_email_without_a_profile
    user = Struct.new(:email, :id).new("ada@example.com", nil)

    assert_equal "ada@example.com", RecordingStudioUser.display_name_for(user)
  end

  def test_empty_allowlist_drops_extra_profile_keys
    extras = RecordingStudioUser::Directory.filtered_additional_profile_attributes(
      { locale: "en", email: "secret@example.com" }
    )

    assert_empty extras
  end

  def test_allowlist_keeps_configured_keys_and_drops_protected_ones
    original = RecordingStudioUser.config.additional_profile_attributes
    RecordingStudioUser.config.additional_profile_attributes = %i[locale preferred_name]

    extras = RecordingStudioUser::Directory.filtered_additional_profile_attributes(
      {
        locale: "en",
        preferred_name: "Ada",
        email: "secret@example.com",
        password: "nope"
      }
    )

    assert_equal({ "locale" => "en", "preferred_name" => "Ada" }, extras)
  ensure
    RecordingStudioUser.config.additional_profile_attributes = original
  end
end
