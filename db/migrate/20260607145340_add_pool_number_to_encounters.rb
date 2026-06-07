# frozen_string_literal: true

class AddPoolNumberToEncounters < ActiveRecord::Migration[8.1]
  def change
    add_column :encounters, :pool_number, :integer
    add_index :encounters, [:team_category_id, :pool_number]
  end
end
