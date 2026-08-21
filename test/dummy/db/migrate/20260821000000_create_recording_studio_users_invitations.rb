# frozen_string_literal: true

class CreateRecordingStudioUsersInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_users_invitations, id: :uuid do |t|
      t.string :email, null: false
      t.uuid :root_recording_id, null: false
      t.string :role, null: false
      t.string :inviter_type, null: false
      t.string :inviter_id, null: false
      t.string :token_digest, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end

    add_index :recording_studio_users_invitations, :token_digest, unique: true
    add_index :recording_studio_users_invitations,
              %i[root_recording_id email status],
              name: "idx_rs_users_invitations_root_email_status"
    add_foreign_key :recording_studio_users_invitations,
                    :recording_studio_recordings,
                    column: :root_recording_id,
                    on_delete: :cascade
  end
end
