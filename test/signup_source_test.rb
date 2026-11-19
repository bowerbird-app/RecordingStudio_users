# frozen_string_literal: true

require "test_helper"

class SignupSourceTest < Minitest::Test
  def setup
    @session = {}
    @request = Struct.new(:session, :remote_ip).new(@session, "127.0.0.1")
  end

  def test_remember_round_trips_scalars_and_stores_strings
    source = {
      "kind" => "press_contact",
      :recording_id => 42,
      :early => false,
      :label => :kit,
      :note => nil,
      :ready => true,
      :offset => -3
    }

    stored = RecordingStudioUser.remember_signup_source!(request: @request, source: source)

    assert_equal(
      { kind: "press_contact", recording_id: 42, early: false, label: :kit, note: nil, ready: true, offset: -3 },
      stored
    )
    assert_equal RecordingStudioUser::SignupSource::SESSION_KEY, @session.keys.first
    raw = @session.fetch(RecordingStudioUser::SignupSource::SESSION_KEY)
    assert raw.keys.all?(String)
    assert raw.values.all?(String)

    assert_equal stored, RecordingStudioUser::SignupSource.take!(@session)
    assert_nil @session[RecordingStudioUser::SignupSource::SESSION_KEY]
    assert_nil RecordingStudioUser::SignupSource.take!(@session)
  end

  def test_eight_keys_are_accepted
    source = (1..8).to_h { |number| [:"k#{number}", number] }

    assert_equal source, RecordingStudioUser.remember_signup_source!(request: @request, source: source)
  end

  def test_invalid_shapes_raise_and_do_not_write_the_session
    long_key = "k" * 41
    long_string = "x" * 256
    rejected = [
      nil,
      "press_contact",
      { "bad-key" => "x" },
      { "1kind" => "x" },
      { long_key => "x" },
      { kind: long_string },
      { kind: { nested: true } },
      { kind: ["press"] },
      { kind: 1.5 },
      (1..9).to_h { |number| [:"k#{number}", number] },
      { "kind" => "one", :kind => "two" }
    ]

    rejected.each do |source|
      assert_raises(ArgumentError) do
        RecordingStudioUser.remember_signup_source!(request: @request, source: source)
      end
      assert_empty @session
    end
  end

  def test_start_otp_challenge_rejects_a_bad_source_before_writing
    assert_raises(ArgumentError) do
      RecordingStudioUser.start_otp_challenge!(
        request: @request,
        email: "person@example.com",
        source: { "bad-key" => "press" }
      )
    end

    assert_empty @session
  end

  def test_remember_requires_a_request
    error = assert_raises(ArgumentError) do
      RecordingStudioUser.remember_signup_source!(request: nil, source: { kind: "kit" })
    end

    assert_match(/request is required/, error.message)
  end

  def test_a_corrupt_session_value_is_dropped
    @session[RecordingStudioUser::SignupSource::SESSION_KEY] = { "kind" => { "nested" => true } }

    assert_nil RecordingStudioUser::SignupSource.take!(@session)
    assert_nil @session[RecordingStudioUser::SignupSource::SESSION_KEY]
  end

  def test_a_forty_character_key_and_a_255_character_string_are_kept
    key = "k" * 40
    value = "v" * 255

    stored = RecordingStudioUser.remember_signup_source!(
      request: @request,
      source: { key => value }
    )

    assert_equal({ key.to_sym => value }, stored)
  end
end
