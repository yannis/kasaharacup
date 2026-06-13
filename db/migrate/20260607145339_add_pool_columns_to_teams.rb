# frozen_string_literal: true

class AddPoolColumnsToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :pool_number, :integer
    add_column :teams, :pool_position, :integer
    add_column :teams, :pool_rank, :integer
    add_column :teams, :seed, :integer
    add_index :teams, [:team_category_id, :pool_number]
  end
end
