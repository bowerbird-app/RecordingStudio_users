# frozen_string_literal: true

require "test_helper"

class FcmAdapterTest < Minitest::Test
  class FakeRecipient
    attr_reader :id

    def initialize(id:)
      @id = id
    end
  end

  Notification = Struct.new(:id, :title, :body, :url, :recipient, :metadata, :notification_type, keyword_init: true)
  Delivery = Struct.new(:id)

  class FakeInstallation
    attr_accessor :firebase_installation_id, :legacy_fcm_token, :disabled_at, :seen

    def initialize(fid:, legacy: nil)
      @firebase_installation_id = fid
      @legacy_fcm_token = legacy
      @disabled_at = nil
      @seen = false
    end

    def delivery_token
      firebase_installation_id.to_s.presence || legacy_fcm_token.to_s.presence
    end

    def disable!(reason: nil)
      _ = reason
      @disabled_at = Time.now
      self
    end

    def touch_seen!
      @seen = true
    end
  end

  class FakeInstallationClass
    def initialize(records)
      @records = records
    end

    def active
      self
    end

    def for_recipient(_recipient)
      self
    end

    def to_a
      @records
    end

    def exists?
      @records.any?
    end
  end

  class FakeClient
    attr_reader :calls

    def initialize(results)
      @results = results.dup
      @calls = []
    end

    def send_message(**kwargs)
      @calls << kwargs
      @results.shift || { ok: false, status: 500, disable: false, error_message: "exhausted" }
    end
  end

  def setup
    @configuration = RecordingStudioNotificationsPush::Configuration.new
    @configuration.firebase_project_id = "demo-project"
    @configuration.firebase_service_account_json = '{"type":"service_account"}'
  end

  def test_delivers_to_active_installations_and_succeeds_when_one_ok
    installations = [
      FakeInstallation.new(fid: "fid-1"),
      FakeInstallation.new(fid: "fid-2")
    ]
    client = FakeClient.new([
                              { ok: false, status: 404, disable: true, error_message: "NOT_FOUND" },
                              { ok: true, status: 200, disable: false }
                            ])
    adapter = RecordingStudioNotificationsPush::FcmAdapter.new(
      configuration: @configuration,
      client: client,
      installation_class: FakeInstallationClass.new(installations)
    )

    assert adapter.deliver(
      notification: Notification.new(
        id: "n1",
        title: "Hello",
        body: "World",
        url: "/pages/1",
        recipient: FakeRecipient.new(id: "user-1"),
        notification_type: :generic
      ),
      delivery: Delivery.new("d1")
    )

    assert_equal 2, client.calls.size
    assert_equal "fid-1", client.calls.first[:token]
    assert_equal "n1", client.calls.first.dig(:data, "notification_id")
    assert_nil client.calls.first.dig(:data, "icon")
    assert installations.first.disabled_at
    assert installations.last.seen
  end

  def test_includes_icon_from_notification_metadata
    installations = [FakeInstallation.new(fid: "fid-1")]
    client = FakeClient.new([{ ok: true, status: 200, disable: false }])
    adapter = RecordingStudioNotificationsPush::FcmAdapter.new(
      configuration: @configuration,
      client: client,
      installation_class: FakeInstallationClass.new(installations)
    )

    assert adapter.deliver(
      notification: Notification.new(
        id: "n-icon",
        title: "Coral",
        body: "Banner",
        url: "/pages/1",
        recipient: FakeRecipient.new(id: "user-1"),
        metadata: { icon: "/push-icon-coral.png" },
        notification_type: :generic
      ),
      delivery: Delivery.new("d-icon")
    )

    assert_equal "/push-icon-coral.png", client.calls.first.dig(:data, "icon")
    assert_equal "/push-icon-coral.png", client.calls.first.dig(:data, "image")
  end

  def test_raises_when_no_installations
    adapter = RecordingStudioNotificationsPush::FcmAdapter.new(
      configuration: @configuration,
      client: FakeClient.new([]),
      installation_class: FakeInstallationClass.new([])
    )

    error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) do
      adapter.deliver(
        notification: Notification.new(
          id: "n1",
          title: "Hello",
          recipient: FakeRecipient.new(id: "user-1"),
          notification_type: :generic
        ),
        delivery: Delivery.new("d1")
      )
    end
    assert_match(/no active push installations/, error.message)
    refute adapter.available_for?(recipient: FakeRecipient.new(id: "user-1"))
  end

  def test_raises_when_all_sends_fail
    installations = [FakeInstallation.new(fid: "fid-1")]
    client = FakeClient.new([{ ok: false, status: 500, disable: false, error_message: "boom" }])
    adapter = RecordingStudioNotificationsPush::FcmAdapter.new(
      configuration: @configuration,
      client: client,
      installation_class: FakeInstallationClass.new(installations)
    )

    error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) do
      adapter.deliver(
        notification: Notification.new(
          id: "n1",
          title: "Hello",
          recipient: FakeRecipient.new(id: "user-1"),
          notification_type: :generic
        ),
        delivery: Delivery.new("d1")
      )
    end
    assert_match(/boom/, error.message)
  end

  def test_missing_service_account_surfaces_from_client
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_project_id = "demo"
    configuration.firebase_service_account_json = nil
    adapter = RecordingStudioNotificationsPush::FcmAdapter.new(
      configuration: configuration,
      installation_class: FakeInstallationClass.new([FakeInstallation.new(fid: "fid-1")])
    )

    error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) do
      adapter.deliver(
        notification: Notification.new(
          id: "n1",
          title: "Hello",
          recipient: FakeRecipient.new(id: "user-1"),
          notification_type: :generic
        ),
        delivery: Delivery.new("d1")
      )
    end
    assert_match(/FIREBASE_SERVICE_ACCOUNT_JSON/, error.message)
  end

  def test_resolved_delivery_payload_is_used_without_persisting_code
    installations = [FakeInstallation.new(fid: "fid-1")]
    client = FakeClient.new([{ ok: true, status: 200, disable: false }])
    adapter = RecordingStudioNotificationsPush::FcmAdapter.new(
      configuration: @configuration,
      client: client,
      installation_class: FakeInstallationClass.new(installations)
    )
    notification = Notification.new(
      id: "n-otp",
      title: "Safe title",
      body: nil,
      recipient: FakeRecipient.new(id: "user-1"),
      notification_type: :login_otp
    )
    delivery = Delivery.new("d-otp")

    RecordingStudioNotifications.register_delivery_payload_resolver(:login_otp) do |notification:, delivery:|
      raise "unexpected notification" unless notification.id == "n-otp"
      raise "unexpected delivery" unless delivery.id == "d-otp"

      { title: "Your sign-in code", body: "123456 is your code." }
    end

    adapter.deliver(notification: notification, delivery: delivery)

    assert_equal "Your sign-in code", client.calls.first[:title]
    assert_equal "123456 is your code.", client.calls.first[:body]
    assert_nil notification.body
  end
end
