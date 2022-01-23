class AddFeeFieldsToCups < ActiveRecord::Migration[7.0]
  def change
    add_column :cups, :junior_fees_chf, :integer
    add_column :cups, :junior_fees_eur, :integer
    add_column :cups, :adult_fees_chf, :integer
    add_column :cups, :adult_fees_eur, :integer
  end
end
