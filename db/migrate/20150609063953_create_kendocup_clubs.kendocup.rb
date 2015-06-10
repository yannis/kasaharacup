# This migration comes from kendocup (originally 20140320142056)
class CreateKendocupClubs < ActiveRecord::Migration
  def change
    create_table :clubs do |t|
      t.string :name

      t.timestamps
    end
  end
end
