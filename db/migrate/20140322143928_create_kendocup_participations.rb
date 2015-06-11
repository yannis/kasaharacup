class CreateKendocupParticipations < ActiveRecord::Migration
  def change
    create_table :participations do |t|
      t.references :category, polymorphic: true
      t.belongs_to :team, index: true
      t.belongs_to :kenshi, index: true
      t.integer :pool_number
      t.integer :pool_position
      t.boolean :ronin

      t.timestamps
    end
    add_index :participations, :pool_number
    add_index :participations, [:category_id, :category_type]
  end
end
