class AddDeviseFieldsToUsers < ActiveRecord::Migration
  def change
    ## Database authenticatable
    # add_column :users, :email, :string,  null: false, default: ""
    add_column :users, :encrypted_password, :string, null: false, default: ""

    # ## Recoverable
    add_column :users,   :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime

    # ## Rememberable
    add_column :users, :remember_created_at, :datetime

    # ## Trackable
    add_column :users,  :sign_in_count, :integer, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users,   :current_sign_in_ip, :string
    add_column :users,   :last_sign_in_ip, :string

    # # Confirmable
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string # Only if using reconfirmable

    ## Lockable
    # add_column :users, :integer,  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
    # add_column :users, :string,   :unlock_token # Only if unlock strategy is :email or :both
    # add_column :users, :datetime, :locked_at

    # omiauthable
    # add_column :users, :provider, :string
    # add_column :users, :uid, :string
  end
end
