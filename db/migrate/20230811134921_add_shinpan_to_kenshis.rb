# frozen_string_literal: true

class AddShinpanToKenshis < ActiveRecord::Migration[7.0]
  def change
    add_column :kenshis, :shinpan, :boolean, default: false, null: false, index: true
  end
end
