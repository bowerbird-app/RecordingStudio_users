# frozen_string_literal: true

class AddAccessLookupIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :recording_studio_accesses,
              %i[actor_type actor_id role],
              name: "index_recording_studio_accesses_on_actor_and_role",
              if_not_exists: true
    add_index :recording_studio_recordings,
              %i[recordable_type recordable_id parent_recording_id trashed_at],
              name: "index_recording_studio_recordings_on_recordable_parent_trashed",
              if_not_exists: true
  end
end
