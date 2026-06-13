# frozen_string_literal: true

class AddBracketColumnsToEncounters < ActiveRecord::Migration[8.1]
  def change
    add_column :encounters, :round, :integer
    add_column :encounters, :position, :integer
    add_column :encounters, :number, :integer
    add_column :encounters, :team_1_pool_number, :integer
    add_column :encounters, :team_1_pool_rank, :integer
    add_column :encounters, :team_2_pool_number, :integer
    add_column :encounters, :team_2_pool_rank, :integer

    add_reference :encounters, :parent_encounter_1,
      foreign_key: {to_table: :encounters}, index: true
    add_reference :encounters, :parent_encounter_2,
      foreign_key: {to_table: :encounters}, index: true

    change_column_null :encounters, :team_1_id, true
    change_column_null :encounters, :team_2_id, true

    add_index :encounters, [:team_category_id, :number],
      unique: true, where: "pool_number IS NULL",
      name: "index_encounters_on_category_and_number_bracket"
    # Bracket-only: pool encounters carry no round/position, so scope the index to
    # bracket rows rather than relying on Postgres NULL-distinct semantics.
    add_index :encounters, [:team_category_id, :round, :position],
      unique: true, where: "pool_number IS NULL",
      name: "index_encounters_on_category_and_round_and_position"
  end
end
