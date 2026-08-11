# frozen_string_literal: true

class AddRecordingStudioUserProfileFields < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :first_name, :string, null: false, default: ""
    add_column :users, :last_name, :string, null: false, default: ""
    add_column :users, :time_zone, :string, null: false, default: "UTC"

    change_column_default :users, :first_name, from: "", to: nil
    change_column_default :users, :last_name, from: "", to: nil
    change_column_default :users, :time_zone, from: "UTC", to: nil
  end
end
