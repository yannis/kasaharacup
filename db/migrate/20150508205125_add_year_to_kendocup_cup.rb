class AddYearToKendocupCup < ActiveRecord::Migration[7.0]
  def change
    add_column :cups, :year, :integer, uniq: true, index: true
  end
end
