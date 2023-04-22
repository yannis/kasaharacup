class AddRemarksToKenshis < ActiveRecord::Migration[7.0]
  def change
    add_column :kenshis, :remarks, :text
  end
end
