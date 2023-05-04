class AddRemarksToKenshis < ActiveRecord::Migration[7.0]
  class Kenshi < ActiveRecord::Base
  end

  def up
    unless Kenshi.column_names.include?("remarks")
      add_column :kenshis, :remarks, :text
    end
  end

  def down
    remove_column :kenshis, :remarks
  end
end
