# frozen_string_literal: true

class AddPositionToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :position, :integer
    add_column :products, :display, :boolean, default: true, null: false
    Cup.find_each do |cup|
      cup.products.order(:name_en).each.with_index(1) do |product, index|
        product.update!(position: index)
      end
    end
  end
end
