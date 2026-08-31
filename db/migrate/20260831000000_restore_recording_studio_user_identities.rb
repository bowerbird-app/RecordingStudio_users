# frozen_string_literal: true

class RestoreRecordingStudioUserIdentities < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:recording_studio_user_identities)

    create_table :recording_studio_user_identities, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.timestamps null: false
    end

    add_index :recording_studio_user_identities, %i[provider uid], unique: true
    add_index :recording_studio_user_identities, :user_id
    add_foreign_key :recording_studio_user_identities, :users, column: :user_id
  end
end
