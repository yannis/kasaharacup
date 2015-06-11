class AddRankToTeamsAndParticipations < ActiveRecord::Migration
  def change
    add_column :teams, :rank, :integer
    add_index :teams, :rank
    add_column :participations, :rank, :integer
    add_index :participations, :rank
  end
end
