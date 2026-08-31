# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/migrate/20260831000000_restore_recording_studio_user_identities")

class RestoreRecordingStudioUserIdentitiesTest < ActiveSupport::TestCase
  test "up repairs indexes and foreign key on a retained identities table" do
    connection = ActiveRecord::Base.connection
    remove_index_if_present(connection, %i[user_id provider])
    remove_index_if_present(connection, :user_id)
    connection.remove_foreign_key(:recording_studio_user_identities, :users) if
      connection.foreign_key_exists?(:recording_studio_user_identities, :users)

    RestoreRecordingStudioUserIdentities.new.up

    assert connection.index_exists?(
      :recording_studio_user_identities,
      %i[provider uid],
      unique: true
    )
    assert connection.index_exists?(
      :recording_studio_user_identities,
      %i[user_id provider],
      unique: true
    )
    assert connection.index_exists?(:recording_studio_user_identities, :user_id)
    assert connection.foreign_key_exists?(
      :recording_studio_user_identities,
      :users,
      column: :user_id
    )
  end

  private

  def remove_index_if_present(connection, columns)
    return unless connection.index_exists?(:recording_studio_user_identities, columns)

    connection.remove_index(:recording_studio_user_identities, column: columns)
  end
end
