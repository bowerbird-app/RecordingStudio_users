# frozen_string_literal: true

module PushTestHelper
  class FakeFcmClient
    attr_reader :calls

    def initialize
      @calls = []
    end

    def send_message(**kwargs)
      @calls << kwargs
      { ok: true, status: 200, disable: false }
    end
  end

  def with_stubbed_fcm_client
    client = FakeFcmClient.new
    adapter = RecordingStudioNotificationsPush::FcmAdapter.new(
      configuration: RecordingStudioNotificationsPush.configuration,
      client: client
    )
    RecordingStudioNotifications.register_channel(RecordingStudioNotificationsPush.configuration.channel, adapter)
    yield client
  end

  def create_push_installation!(user, fid:)
    RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: user,
      firebase_installation_id: fid
    )
  end
end
