# frozen_string_literal: true

class AddPoolRankToParticipations < ActiveRecord::Migration[8.1]
  def change
    add_column :participations, :pool_rank, :integer
    add_index :participations, :pool_rank

    rename_column :fights, :fighter_1_pool_position, :fighter_1_pool_rank
    rename_column :fights, :fighter_2_pool_position, :fighter_2_pool_rank
  end
end
