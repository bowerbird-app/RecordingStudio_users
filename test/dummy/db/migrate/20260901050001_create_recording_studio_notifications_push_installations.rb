# frozen_string_literal: true

class CreateRecordingStudioNotificationsPushInstallations < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_notifications_push_installations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :recipient_type, null: false
      t.uuid :recipient_id, null: false
      t.string :firebase_installation_id, null: false
      t.string :legacy_fcm_token
      t.string :user_agent
      t.string :platform
      t.string :label
      t.datetime :last_seen_at
      t.datetime :disabled_at

      t.timestamps
    end

    add_index :recording_studio_notifications_push_installations,
              %i[recipient_type recipient_id firebase_installation_id],
              unique: true,
              name: "idx_rsnp_installations_recipient_fid"
    add_index :recording_studio_notifications_push_installations,
              %i[recipient_type recipient_id],
              name: "idx_rsnp_installations_recipient"
    add_index :recording_studio_notifications_push_installations,
              :firebase_installation_id,
              name: "idx_rsnp_installations_fid"
    add_index :recording_studio_notifications_push_installations,
              :disabled_at,
              name: "idx_rsnp_installations_disabled"
  end
end
