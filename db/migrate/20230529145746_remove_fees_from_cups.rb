# frozen_string_literal: true

class RemoveFeesFromCups < ActiveRecord::Migration[7.0]
  def change
    remove_column :cups, :adult_fees_chf, :integer, null: false, default: 0
    remove_column :cups, :adult_fees_eur, :integer, null: false, default: 0
    remove_column :cups, :junior_fees_chf, :integer, null: false, default: 0
    remove_column :cups, :junior_fees_eur, :integer, null: false, default: 0
  end
end
