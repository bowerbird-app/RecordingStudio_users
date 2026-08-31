# frozen_string_literal: true

class RestoreRecordingStudioUserIdentities < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:recording_studio_user_identities)

    create_table :recording_studio_user_identities, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :provider, :uid, null: false
      t.string :email
      t.timestamps null: false
      t.index %i[provider uid], unique: true
      t.index :user_id
      t.foreign_key :users, column: :user_id
    end
  end
end
