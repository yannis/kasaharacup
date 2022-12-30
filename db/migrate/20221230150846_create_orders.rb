# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_enum :order_states, %w[pending paid cancelled]

    create_table :orders do |t|

      t.references :user, null: false, foreign_key: true
      t.references :cup, null: false, foreign_key: true
      t.enum :state, :enum, enum_type: :order_states, null: false, default: "pending"
      t.timestamp :state_at, null: true

      t.timestamps
    end

    add_reference :purchases, :order, null: true, foreign_key: true
  end
end
