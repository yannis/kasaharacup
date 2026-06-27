# frozen_string_literal: true

# Schema for the team-category feature, consolidated from the incremental
# migrations originally authored on this branch:
#   - team size on team_categories, backed by a CHECK constraint
#   - encounters (pool round-robin + elimination bracket in one table)
#   - team_fights (the individual bouts within an encounter)
#   - pool columns on teams
#
# Encounters reference teams via team_1_id / team_2_id / winner_id. Deleting a
# team mid-tournament (or the TeamCategory cascade destroying teams before
# encounters) would otherwise raise a raw FK violation; on_delete: :nullify
# blanks the slot instead so the encounter falls back to "to be decided".
class CreateTeamCategorySchema < ActiveRecord::Migration[8.1]
  def change
    add_column :team_categories, :team_size, :integer, default: 5, null: false
    add_check_constraint :team_categories, "team_size IN (3, 5)",
      name: "team_categories_team_size_check"

    create_table :encounters do |t|
      t.references :team_category, null: false, foreign_key: true
      # Round-1 bracket slots and unscored pool rows may have no team yet.
      t.references :team_1, foreign_key: {to_table: :teams, on_delete: :nullify}
      t.references :team_2, foreign_key: {to_table: :teams, on_delete: :nullify}
      t.references :winner, foreign_key: {to_table: :teams, on_delete: :nullify}
      # Track which sides have handed in a lineup. A position with one empty
      # side is only a forfeit once BOTH sides are submitted.
      t.boolean :lineup_1_set, null: false, default: false
      t.boolean :lineup_2_set, null: false, default: false
      # Pool play.
      t.integer :pool_number
      # Elimination bracket.
      t.integer :round
      t.integer :position
      t.integer :number
      t.integer :team_1_pool_number
      t.integer :team_1_pool_rank
      t.integer :team_2_pool_number
      t.integer :team_2_pool_rank
      t.references :parent_encounter_1, foreign_key: {to_table: :encounters}
      t.references :parent_encounter_2, foreign_key: {to_table: :encounters}
      # Persisted so recompute_winner! can skip a full pool re-rank while an
      # encounter is (and stays) incomplete.
      t.boolean :completed, null: false, default: false
      t.timestamps
    end
    add_index :encounters, [:team_category_id, :pool_number]
    add_index :encounters, [:team_category_id, :number],
      unique: true, where: "pool_number IS NULL",
      name: "index_encounters_on_category_and_number_bracket"
    # Bracket-only: pool encounters carry no round/position, so scope the index
    # to bracket rows rather than relying on Postgres NULL-distinct semantics.
    add_index :encounters, [:team_category_id, :round, :position],
      unique: true, where: "pool_number IS NULL",
      name: "index_encounters_on_category_and_round_and_position"

    create_table :team_fights do |t|
      t.references :encounter, null: false, foreign_key: true
      t.references :kenshi_1, foreign_key: {to_table: :kenshis}
      t.references :kenshi_2, foreign_key: {to_table: :kenshis}
      t.references :winner, foreign_key: {to_table: :kenshis}
      t.integer :position, null: false
      t.boolean :draw, null: false, default: false
      t.boolean :daihyosen, null: false, default: false
      t.timestamps
    end
    add_index :team_fights, [:encounter_id, :position], unique: true

    add_column :teams, :pool_number, :integer
    add_column :teams, :pool_position, :integer
    add_column :teams, :pool_rank, :integer
    add_column :teams, :seed, :integer
    add_index :teams, [:team_category_id, :pool_number]
  end
end
