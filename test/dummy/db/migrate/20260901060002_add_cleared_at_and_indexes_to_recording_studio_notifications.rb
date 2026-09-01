# frozen_string_literal: true

class AddClearedAtAndIndexesToRecordingStudioNotifications < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:recording_studio_notifications_notifications, :cleared_at)
      add_column :recording_studio_notifications_notifications, :cleared_at, :datetime
    end

    unless index_exists?(:recording_studio_notifications_notifications, %i[root_recording_id created_at],
                         name: "idx_rsn_notifications_root_created")
      add_index :recording_studio_notifications_notifications, %i[root_recording_id created_at],
                name: "idx_rsn_notifications_root_created"
    end

    unless index_exists?(:recording_studio_notifications_notifications, :recording_id,
                         name: "idx_rsn_notifications_recording")
      add_index :recording_studio_notifications_notifications, :recording_id,
                name: "idx_rsn_notifications_recording"
    end

    unless index_exists?(:recording_studio_notifications_deliveries, %i[channel status],
                         name: "idx_rsn_deliveries_channel_status")
      add_index :recording_studio_notifications_deliveries, %i[channel status],
                name: "idx_rsn_deliveries_channel_status"
    end
  end
end
