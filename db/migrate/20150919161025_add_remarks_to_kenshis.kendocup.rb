# This migration comes from kendocup (originally 20150910090301)
class AddRemarksToKenshis < ActiveRecord::Migration
  def change
    add_column :kenshis, :remarks, :text
  end
end
