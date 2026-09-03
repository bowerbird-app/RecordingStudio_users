# frozen_string_literal: true

require "test_helper"

class EventTest < Minitest::Test
  Notification = Struct.new(:id, :title, :body, :url, :recipient, :metadata, keyword_init: true)

  def test_wrap_normalizes_title_body_and_url
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(
        id: "1",
        title: "Hi\nthere",
        body: "Body",
        url: "/safe",
        recipient: Object.new,
        metadata: { a: 1, icon: "/push-icon-coral.png" }
      )
    )

    assert_equal "1", event.id
    assert_equal "Hi there", event.title
    assert_equal "Body", event.body
    assert_equal "/safe", event.url
    assert_equal({ a: 1, icon: "/push-icon-coral.png" }, event.metadata)
    assert_equal "/push-icon-coral.png", event.icon
  end

  def test_rejects_unsafe_urls
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "T", url: "javascript:alert(1)")
    )

    assert_nil event.url
  end

  def test_rejects_unsafe_icons
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "T", metadata: { icon: "javascript:alert(1)" })
    )

    assert_nil event.icon
  end

  def test_metadata_is_memoized
    notification = Notification.new(
      id: "1",
      title: "T",
      metadata: { icon: "/push-icon-coral.png" }
    )
    event = RecordingStudioNotificationsPush::Event.wrap(notification)

    assert_same event.metadata, event.metadata
    assert_equal "/push-icon-coral.png", event.icon
  end

  def test_allows_absolute_http_icons_without_host_allowlist
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(
        id: "1",
        title: "T",
        metadata: {
          icon: "http://127.0.0.1:3000/push-icon-teal.png",
          image: "http://127.0.0.1:3000/push-icon-teal.png"
        }
      )
    )

    assert_equal "http://127.0.0.1:3000/push-icon-teal.png", event.icon
    assert_equal "http://127.0.0.1:3000/push-icon-teal.png", event.image
  end
end
