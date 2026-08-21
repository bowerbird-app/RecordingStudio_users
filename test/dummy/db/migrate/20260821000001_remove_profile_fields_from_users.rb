# frozen_string_literal: true

class RemoveProfileFieldsFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_column :users, :first_name if column_exists?(:users, :first_name)
    remove_column :users, :last_name if column_exists?(:users, :last_name)
    remove_column :users, :time_zone if column_exists?(:users, :time_zone)
    return unless column_exists?(:users, :additional_profile_attributes)

    remove_column :users, :additional_profile_attributes
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Profile fields belong on RecordingStudioUser::Profile, not User"
  end
end
