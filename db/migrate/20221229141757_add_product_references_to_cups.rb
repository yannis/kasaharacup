# frozen_string_literal: true

class AddProductReferencesToCups < ActiveRecord::Migration[7.0]
  def change
    add_reference :cups, :product_junior, foreign_key: { to_table: :products }, null: true
    add_reference :cups, :product_adult, foreign_key: { to_table: :products }, null: true
  end
end
