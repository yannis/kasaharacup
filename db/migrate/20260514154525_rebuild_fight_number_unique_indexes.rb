# frozen_string_literal: true

class RebuildFightNumberUniqueIndexes < ActiveRecord::Migration[8.1]
  def up
    remove_index :fights, name: "index_fights_on_individual_category_id_and_number"
    add_index :fights,
      [:individual_category_id, :number],
      unique: true,
      where: "pool_number IS NULL",
      name: "index_fights_on_category_and_number_bracket"
    add_index :fights,
      [:individual_category_id, :pool_number, :number],
      unique: true,
      where: "pool_number IS NOT NULL",
      name: "index_fights_on_category_and_pool_and_number"
  end

  def down
    remove_index :fights, name: "index_fights_on_category_and_pool_and_number"
    remove_index :fights, name: "index_fights_on_category_and_number_bracket"
    add_index :fights, [:individual_category_id, :number], unique: true,
      name: "index_fights_on_individual_category_id_and_number"
  end
end
