# frozen_string_literal: true

require "test_helper"

class DeliveryPayloadRegistryTest < Minitest::Test
  def setup
    @registry = RecordingStudioNotifications::DeliveryPayloadRegistry.new
  end

  def test_register_and_resolve
    @registry.register(:test_type) { |notification:, delivery:| { title: "Hi", body: "Body" } }

    notification = Struct.new(:notification_type).new("test_type")
    result = @registry.resolve(notification: notification, delivery: nil)

    assert_equal({ title: "Hi", body: "Body" }, result)
  end

  def test_resolve_returns_nil_without_resolver
    notification = Struct.new(:notification_type).new("missing")
    assert_nil @registry.resolve(notification: notification, delivery: nil)
  end

  def test_delivery_payload_for_falls_back_to_persisted_content
    notification = Struct.new(:notification_type, :title, :body, :url).new("generic", "Title", "Body", "/x")
    payload = RecordingStudioNotifications.send(:persisted_delivery_payload, notification)

    assert_equal "Title", payload.title
    assert_equal "Body", payload.body
    assert_equal "/x", payload.url
  end

  def test_public_api_methods_exist
    assert_respond_to RecordingStudioNotifications, :register_delivery_payload_resolver
    assert_respond_to RecordingStudioNotifications, :delivery_payload_for
  end
end
