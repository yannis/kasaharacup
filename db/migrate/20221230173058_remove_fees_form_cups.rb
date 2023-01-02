# frozen_string_literal: true

class RemoveFeesFormCups < ActiveRecord::Migration[7.0]
  def change
    remove_column :cups, :junior_fees_chf, :integer
    remove_column :cups, :junior_fees_eur, :integer
    remove_column :cups, :adult_fees_chf, :integer
    remove_column :cups, :adult_fees_eur, :integer
  end
end
