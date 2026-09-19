# frozen_string_literal: true

# Records WHO ordered each side's fighters, which lineup_#{slot}_set alone
# cannot say: EncounterLineupSeeder confirms both sides the moment an admin
# opens a panel, so that flag reads true for an order nobody typed. Everything
# that protects hand-entered work from being re-drawn — the bracket swap's
# confirmation prompt, TeamPoolMove's, and the bracket builder's non-force
# update — asks Encounter#pristine?, which now reads these columns instead.
#
# No backfill, deliberately. Copying lineup_#{slot}_set forward would copy the
# very ambiguity this column exists to remove, and keep every already-opened
# encounter prompting for ever. The cost is one-off and bounded: an order
# entered by hand BEFORE this migration is no longer prompted about — and only
# ever on an encounter with no recorded result at all, since every reader
# requires #unscored? first.
class AddLineupSetByAdminToEncounters < ActiveRecord::Migration[8.1]
  def change
    add_column :encounters, :lineup_1_set_by_admin, :boolean, default: false, null: false
    add_column :encounters, :lineup_2_set_by_admin, :boolean, default: false, null: false
  end
end
