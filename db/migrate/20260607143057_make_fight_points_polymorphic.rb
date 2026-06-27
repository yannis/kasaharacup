# frozen_string_literal: true

class MakeFightPointsPolymorphic < ActiveRecord::Migration[8.1]
  def up
    # A renamed column keeps its FK constraint in Postgres; a polymorphic
    # association cannot carry a single-table FK, so drop it first.
    remove_foreign_key :fight_points, :fights

    # Drop the old indexes BEFORE the rename. On the PG adapter, rename_column
    # auto-renames conventionally-named indexes (index_fight_points_on_fight_id*
    # -> *_scorable_id*), so removing them by their old names afterward raises
    # "index does not exist" and rolls the migration back.
    remove_index :fight_points, name: "index_fight_points_on_fight_id_and_position"
    remove_index :fight_points, name: "index_fight_points_on_fight_id_and_fighter_side"
    remove_index :fight_points, name: "index_fight_points_on_fight_id"

    add_column :fight_points, :scorable_type, :string
    rename_column :fight_points, :fight_id, :scorable_id
    execute("UPDATE fight_points SET scorable_type = 'Fight'")
    change_column_null :fight_points, :scorable_type, false

    add_index :fight_points, [:scorable_type, :scorable_id]
    add_index :fight_points, [:scorable_type, :scorable_id, :position], unique: true,
      name: "index_fight_points_on_scorable_and_position"
    add_index :fight_points, [:scorable_type, :scorable_id, :fighter_side],
      name: "index_fight_points_on_scorable_and_side"
  end

  def down
    remove_index :fight_points, name: "index_fight_points_on_scorable_and_side"
    remove_index :fight_points, name: "index_fight_points_on_scorable_and_position"
    remove_index :fight_points, [:scorable_type, :scorable_id]

    execute("DELETE FROM fight_points WHERE scorable_type <> 'Fight'")
    rename_column :fight_points, :scorable_id, :fight_id
    remove_column :fight_points, :scorable_type

    add_index :fight_points, [:fight_id, :position], unique: true,
      name: "index_fight_points_on_fight_id_and_position"
    add_index :fight_points, [:fight_id, :fighter_side],
      name: "index_fight_points_on_fight_id_and_fighter_side"
    add_index :fight_points, :fight_id, name: "index_fight_points_on_fight_id"
    add_foreign_key :fight_points, :fights
  end
end
