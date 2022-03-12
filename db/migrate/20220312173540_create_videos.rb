# frozen_string_literal: true

class CreateVideos < ActiveRecord::Migration[7.0]
  def change
    create_table :videos do |t|
      t.string :url, null: false, index: {unique: true}
      t.string :name, null: false
      t.references :category, polymorphic: true, null: false

      t.timestamps
    end

    add_index :videos, [:name, :category_type, :category_id], unique: true
  end
end
