# frozen_string_literal: true

require "test_helper"
require "active_record"
require "active_support/notifications"

class RegistrationCompletedTest < Minitest::Test
  def setup
    @events = []
    @subscriber = ActiveSupport::Notifications.subscribe(
      RecordingStudioUser::RegistrationCompleted::EVENT
    ) do |_name, _start, _finish, _id, payload|
      @events << payload
    end
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber)
  end

  def test_emit_instruments_with_user_id_and_method
    RecordingStudioUser::RegistrationCompleted.emit!(user_id: "user-1", method: :password)

    assert_equal 1, @events.size
    assert_equal({ user_id: "user-1", method: :password }, @events.first)
  end

  def test_emit_adds_source_only_when_present
    RecordingStudioUser::RegistrationCompleted.emit!(
      user_id: "user-1",
      method: :otp,
      source: { "kind" => "kit_download", :recording_id => 9, :early => false }
    )
    RecordingStudioUser::RegistrationCompleted.emit!(user_id: "user-2", method: :password, source: nil)

    assert_equal(
      {
        user_id: "user-1",
        method: :otp,
        source: { kind: "kit_download", recording_id: 9, early: false }
      },
      @events[0]
    )
    assert_equal({ user_id: "user-2", method: :password }, @events[1])
    refute @events[1].key?(:source)
  end

  def test_emit_rejects_an_invalid_source
    assert_raises(ArgumentError) do
      RecordingStudioUser::RegistrationCompleted.emit!(
        user_id: "user-1",
        method: :oauth,
        source: { kind: { nested: true } }
      )
    end
    assert_empty @events
  end

  def test_emit_rejects_unknown_method
    assert_raises(ArgumentError) do
      RecordingStudioUser::RegistrationCompleted.emit!(user_id: "user-1", method: :sms)
    end
    assert_empty @events
  end

  def test_event_name_is_stable
    assert_equal "registration.completed.recording_studio_user",
                 RecordingStudioUser::RegistrationCompleted::EVENT
  end
end
