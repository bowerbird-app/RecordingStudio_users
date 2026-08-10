# frozen_string_literal: true

class CreateRecordingStudioUsersProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_users_profiles, id: :uuid do |t|
      t.string :display_name
      t.text :biography
      t.string :locale
      t.string :time_zone
      t.timestamps
    end
  end
end
