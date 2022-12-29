# frozen_string_literal: true

class AddDisplayToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :display, :boolean, default: true, null: false
  end
end
