# This migration comes from kendocup (originally 20150429202547)
class AddRankToTeamsAndParticipations < ActiveRecord::Migration
  def change
    add_column :teams, :rank, :integer
    add_index :teams, :rank
    add_column :participations, :rank, :integer
    add_index :participations, :rank
  end
end
