class CreatePurchases < ActiveRecord::Migration[7.0]
  def change
    create_table :purchases do |t|
      t.belongs_to :kenshi, index: true
      t.belongs_to :product, index: true

      t.timestamps
    end
  end
end
