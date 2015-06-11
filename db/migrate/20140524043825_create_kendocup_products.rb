class CreateKendocupProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :name_en
      t.string :name_fr

      t.text :description_en
      t.text :description_fr

      t.integer :fee_chf
      t.integer :fee_eu

      t.belongs_to :event
      t.belongs_to :cup

      t.timestamps
    end
  end
end
