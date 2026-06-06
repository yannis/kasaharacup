# frozen_string_literal: true

class AddPoolColumnsToFights < ActiveRecord::Migration[8.1]
  def change
    add_column :fights, :pool_number, :integer
    add_column :fights, :draw, :boolean, null: false, default: false
    add_column :fights, :tiebreaker, :boolean, null: false, default: false
    add_index :fights, [:individual_category_id, :pool_number]
  end
end
