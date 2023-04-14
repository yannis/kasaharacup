# frozen_string_literal: true

class AddStripeCustomerIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :stripe_customer_id, :string, null: true
    add_index :users, :stripe_customer_id, unique: true
  end
end
