# This migration comes from kendocup (originally 20140618094105)
class AddTimestampsToKendocupTeams < ActiveRecord::Migration
  def change
    change_table :teams do |t|
      t.timestamps
    end
  end
end
