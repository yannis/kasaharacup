class AddYearToKendocupCup < ActiveRecord::Migration
  def change
    add_column :cups, :year, :integer, uniq: true, index: true
  end
end
