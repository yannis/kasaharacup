# frozen_string_literal: true

class AddRegisterableAtToCups < ActiveRecord::Migration[7.0]
  def change
    add_column :cups, :registerable_at, :datetime, null: true
  end
end
