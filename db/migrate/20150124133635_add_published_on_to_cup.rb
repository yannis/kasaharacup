class AddPublishedOnToCup < ActiveRecord::Migration
  def change
    add_column :cups, :published_on, :date
  end
end
