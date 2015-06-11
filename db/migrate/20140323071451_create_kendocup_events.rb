class CreateKendocupEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.belongs_to :cup, index: true
      t.string :name_en
      t.string :name_fr
      t.datetime :start_on
      t.integer :duration

      t.timestamps
    end
  end
end
