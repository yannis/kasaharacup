# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :documents do |t|
      t.string :name, null: false
      t.belongs_to :category, polymorphic: true, null: false

      t.timestamps
    end
    add_index :documents, [:name, :category_type, :category_id], unique: true
  end
end
