class CreateKendocupFights < ActiveRecord::Migration
  def change
    create_table :fights do |t|
      t.belongs_to :individual_category, index: true
      t.belongs_to :team_category, index: true
      t.belongs_to :winner, index: true
      t.belongs_to :parent_fight_1, index: true
      t.belongs_to :parent_fight_2, index: true
      t.string :fighter_type
      t.belongs_to :fighter_1, index: true
      t.belongs_to :fighter_2, index: true
      t.integer :number
      t.string :score

      t.timestamps
    end
    add_index :fights, :number
  end
end
