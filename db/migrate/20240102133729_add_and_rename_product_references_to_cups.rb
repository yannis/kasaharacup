# frozen_string_literal: true

class AddAndRenameProductReferencesToCups < ActiveRecord::Migration[7.1]
  def change
    add_reference :cups, :product_team, foreign_key: { to_table: :products }, null: true
    add_reference :cups, :product_full_junior, foreign_key: { to_table: :products }, null: true
    add_reference :cups, :product_full_adult, foreign_key: { to_table: :products }, null: true

    rename_column :cups, :product_junior_id, :product_individual_junior_id
    rename_column :cups, :product_adult_id, :product_individual_adult_id
  end
end
