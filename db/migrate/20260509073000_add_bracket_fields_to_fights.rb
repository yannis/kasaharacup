# frozen_string_literal: true

class AddBracketFieldsToFights < ActiveRecord::Migration[8.1]
  def change
    add_column :fights, :round, :integer
    add_column :fights, :position, :integer
    add_column :fights, :fighter_1_pool_number, :integer
    add_column :fights, :fighter_1_pool_position, :integer
    add_column :fights, :fighter_2_pool_number, :integer
    add_column :fights, :fighter_2_pool_position, :integer

    change_column_null :fights, :fighter_1_id, true
    change_column_null :fights, :fighter_2_id, true

    add_index :fights, %i[individual_category_id round position], unique: true
  end
end
