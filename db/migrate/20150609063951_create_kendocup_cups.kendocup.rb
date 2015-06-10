# This migration comes from kendocup (originally 20140319165902)
class CreateKendocupCups < ActiveRecord::Migration
  def change
    create_table :cups do |t|
      t.date      :start_on
      t.date      :end_on
      t.datetime  :deadline

      t.timestamps
    end
  end
end
