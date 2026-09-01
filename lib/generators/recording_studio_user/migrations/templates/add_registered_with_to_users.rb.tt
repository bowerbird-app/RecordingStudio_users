class AddRegisteredWithToUsers < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:users, :registered_with)
    return if column_exists?(:users, :authentication_method)

    add_column :users, :registered_with, :string, null: false, default: "password"
    add_check_constraint :users, "registered_with IN ('password', 'otp')", name: "users_registered_with_check"

    execute <<~SQL.squish
      UPDATE users SET registered_with = 'password' WHERE registered_with IS NULL
    SQL
  end

  def down
    return unless column_exists?(:users, :registered_with)

    if check_constraint_exists?(:users, name: "users_registered_with_check")
      remove_check_constraint :users, name: "users_registered_with_check"
    end

    remove_column :users, :registered_with
  end
end
