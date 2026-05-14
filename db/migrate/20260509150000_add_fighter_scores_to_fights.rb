# frozen_string_literal: true

class AddFighterScoresToFights < ActiveRecord::Migration[8.1]
  def change
    add_column :fights, :fighter_1_score, :string
    add_column :fights, :fighter_2_score, :string
  end
end
