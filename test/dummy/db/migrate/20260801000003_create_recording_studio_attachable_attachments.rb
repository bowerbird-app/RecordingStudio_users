# frozen_string_literal: true

class CreateRecordingStudioAttachableAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_attachable_attachments, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :attachment_kind, null: false
      t.string :original_filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.index :attachment_kind
      t.index %i[attachment_kind content_type], name: "idx_rs_attachable_kind_type"
    end

    add_index :recording_studio_recordings,
              :parent_recording_id,
              name: "idx_rs_attachable_parent_active",
              where: "recordable_type = 'RecordingStudioAttachable::Attachment' AND trashed_at IS NULL"
    add_index :recording_studio_recordings,
              :root_recording_id,
              name: "idx_rs_attachable_root_active",
              where: "recordable_type = 'RecordingStudioAttachable::Attachment' AND trashed_at IS NULL"
  end
end
