# frozen_string_literal: true

class AddCanceledAtToCups < ActiveRecord::Migration[7.0]
  def change
    add_column :cups, :canceled_at, :datetime, null: true, default: nil
  end
end
