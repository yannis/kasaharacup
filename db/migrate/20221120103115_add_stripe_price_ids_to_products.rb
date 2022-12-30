# frozen_string_literal: true

class AddStripePriceIdsToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :cups, :stripe_adult_price_id, :string, null: true, index: true
    add_column :cups, :stripe_junior_price_id, :string, null: true, index: true

    add_column :products, :stripe_price_id, :string, null: true, index: true
  end
end
