class CreateKendocupTeams < ActiveRecord::Migration
  def change
    create_table :teams do |t|
      t.string :name
      t.belongs_to :team_category, index: true
    end
  end
end
