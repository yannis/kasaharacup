class AddTimestampsToKendocupTeams < ActiveRecord::Migration
  def change
    change_table :teams do |t|
      t.timestamps
    end
  end
end
