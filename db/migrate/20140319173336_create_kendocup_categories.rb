class CreateKendocupCategories < ActiveRecord::Migration
  def change
    create_table :individual_categories do |t|
      t.string :name
      t.integer :pool_size
      t.integer :out_of_pool
      t.integer :min_age
      t.integer :max_age
      t.text :description_en
      t.text :description_fr
      t.belongs_to :cup, index: true

      t.timestamps
    end

    create_table :team_categories do |t|
      t.string :name
      t.integer :pool_size
      t.integer :out_of_pool
      t.integer :min_age
      t.integer :max_age
      t.text :description_en
      t.text :description_fr
      t.belongs_to :cup, index: true

      t.timestamps
    end
  end
end
