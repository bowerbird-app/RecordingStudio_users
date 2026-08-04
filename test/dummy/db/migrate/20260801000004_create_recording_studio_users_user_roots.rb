# frozen_string_literal: true

class CreateRecordingStudioUsersUserRootsInDummy < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_users_user_roots, id: :uuid do |t|
      t.string :user_type, null: false
      t.uuid :user_id, null: false
      t.timestamps
    end

    add_index :recording_studio_users_user_roots,
              %i[user_type user_id],
              unique: true,
              name: "idx_recording_studio_users_user_roots_owner"
  end
end
