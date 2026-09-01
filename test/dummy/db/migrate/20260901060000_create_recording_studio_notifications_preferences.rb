# frozen_string_literal: true

class CreateRecordingStudioNotificationsPreferences < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:recording_studio_notifications_preferences)

    create_table :recording_studio_notifications_preferences, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :recipient_type, null: false
      t.uuid :recipient_id, null: false
      t.string :notification_type, null: false
      t.string :channel, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :recording_studio_notifications_preferences,
              %i[recipient_type recipient_id notification_type channel],
              unique: true,
              name: "idx_rsn_preferences_recipient_type"
    add_index :recording_studio_notifications_preferences, %i[notification_type channel],
              name: "idx_rsn_preferences_type_channel"
  end
end
