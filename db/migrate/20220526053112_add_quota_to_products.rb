# frozen_string_literal: true

class AddQuotaToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :quota, :integer, index: true, null: true
  end
end
