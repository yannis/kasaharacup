# frozen_string_literal: true

class CreateEncounters < ActiveRecord::Migration[8.1]
  def change
    create_table :encounters do |t|
      t.references :team_category, null: false, foreign_key: true
      t.references :team_1, null: false, foreign_key: {to_table: :teams}
      t.references :team_2, null: false, foreign_key: {to_table: :teams}
      t.references :winner, null: true, foreign_key: {to_table: :teams}
      # Track which sides have handed in a lineup. A position with one empty
      # side is only a forfeit once BOTH sides are submitted.
      t.boolean :lineup_1_set, null: false, default: false
      t.boolean :lineup_2_set, null: false, default: false
      t.timestamps
    end
  end
end
