# This migration comes from kendocup (originally 20150508205125)
class AddYearToKendocupCup < ActiveRecord::Migration
  def change
    add_column :cups, :year, :integer, uniq: true, index: true
  end
end
