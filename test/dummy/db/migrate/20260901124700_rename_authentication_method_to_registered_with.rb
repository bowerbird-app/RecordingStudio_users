class RenameAuthenticationMethodToRegisteredWith < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:users, :authentication_method)
    return if column_exists?(:users, :registered_with)

    if check_constraint_exists?(:users, name: "users_authentication_method_check")
      remove_check_constraint :users, name: "users_authentication_method_check"
    end

    rename_column :users, :authentication_method, :registered_with
    add_check_constraint :users, "registered_with IN ('password', 'otp')", name: "users_registered_with_check"
  end

  def down
    return unless column_exists?(:users, :registered_with)
    return if column_exists?(:users, :authentication_method)

    if check_constraint_exists?(:users, name: "users_registered_with_check")
      remove_check_constraint :users, name: "users_registered_with_check"
    end

    rename_column :users, :registered_with, :authentication_method
    add_check_constraint :users, "authentication_method IN ('password', 'otp')", name: "users_authentication_method_check"
  end
end
