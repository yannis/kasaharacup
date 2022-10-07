class AddDescriptionToCups < ActiveRecord::Migration[7.0]
  def change
    add_column :cups, :description, :text
  end
end
