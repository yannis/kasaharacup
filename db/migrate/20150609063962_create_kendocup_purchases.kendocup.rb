# This migration comes from kendocup (originally 20140524043826)
class CreateKendocupPurchases < ActiveRecord::Migration
  def change
    create_table :purchases do |t|
      t.belongs_to :kenshi, index: true
      t.belongs_to :product, index: true

      t.timestamps
    end
  end
end
