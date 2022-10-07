class AddDescriptionToCups < ActiveRecord::Migration[7.0]
  def change
    add_column :cups, :description_en, :text
    add_column :cups, :description_fr, :text
  end
end
