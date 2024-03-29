# frozen_string_literal: true

class CreateHeadlines  < ActiveRecord::Migration[7.0]
  def change
    create_table :headlines do |t|
      t.string :title_fr
      t.string :title_en
      t.text :content_fr
      t.text :content_en
      t.belongs_to :cup, index: true
      t.boolean :shown, default: false

      t.timestamps
    end
  end
end
