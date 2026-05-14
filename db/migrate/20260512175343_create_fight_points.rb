# frozen_string_literal: true

class CreateFightPoints < ActiveRecord::Migration[8.1]
  def change
    create_table :fight_points do |t|
      t.references :fight, null: false, foreign_key: true
      t.string :fighter_side, null: false
      t.string :kind, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :fight_points, [:fight_id, :position], unique: true
    add_index :fight_points, [:fight_id, :fighter_side]

    remove_column :fights, :fighter_1_score, :string
    remove_column :fights, :fighter_2_score, :string
  end
end
