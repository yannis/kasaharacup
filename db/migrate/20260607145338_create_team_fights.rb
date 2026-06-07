# frozen_string_literal: true

class CreateTeamFights < ActiveRecord::Migration[8.1]
  def change
    create_table :team_fights do |t|
      t.references :encounter, null: false, foreign_key: true
      t.references :kenshi_1, null: true, foreign_key: {to_table: :kenshis}
      t.references :kenshi_2, null: true, foreign_key: {to_table: :kenshis}
      t.references :winner, null: true, foreign_key: {to_table: :kenshis}
      t.integer :position, null: false
      t.boolean :draw, null: false, default: false
      t.boolean :daihyosen, null: false, default: false
      t.timestamps
    end
    add_index :team_fights, [:encounter_id, :position], unique: true
  end
end
