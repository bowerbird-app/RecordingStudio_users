# frozen_string_literal: true

require "test_helper"

class CodeSignInCopyTest < Minitest::Test
  def test_a_key_and_its_params_are_packed
    packed = RecordingStudioUser::CodeSignInCopy.pack(
      { key: "notifications.mail.settings_reason", product: "Notifications", count: 1 }
    )

    assert_equal "notifications.mail.settings_reason", packed["key"]
    assert_equal({ "product" => "Notifications", "count" => 1 }, packed["params"])
  end

  def test_literal_text_and_overlong_keys_are_rejected
    copy = RecordingStudioUser::CodeSignInCopy

    assert_raises(ArgumentError) { copy.pack("Enter your code") }
    assert_raises(ArgumentError) { copy.pack("a" * 81) }
    assert_raises(ArgumentError) { copy.pack({ key: "notifications.mail.reason", default: "nope" }) }
    assert_raises(ArgumentError) do
      copy.pack({ key: "notifications.mail.reason", one: "a", two: "b", three: "c", four: "d", five: "e" })
    end
  end

  def test_a_missing_key_falls_back_and_a_present_key_is_used
    I18n.backend.store_translations(:en, notifications: { mail: { hello: "Hello there" } })
    packed = RecordingStudioUser::CodeSignInCopy.pack("notifications.mail.hello")
    missing = RecordingStudioUser::CodeSignInCopy.pack("notifications.mail.not_defined")

    assert_equal "Hello there", RecordingStudioUser::CodeSignInCopy.text(packed, fallback: "Enter your code")
    assert_equal "Enter your code", RecordingStudioUser::CodeSignInCopy.text(missing, fallback: "Enter your code")
    assert_nil RecordingStudioUser::CodeSignInCopy.text(missing, fallback: nil)
  end

  def test_a_tampered_copy_shape_voids_the_pair
    copy = RecordingStudioUser::CodeSignInCopy

    assert_nil copy.pair({ "key" => "Not a key" }, nil)
    assert_nil copy.pair({ "key" => "Enter your code" }, nil)
  end
end
