# frozen_string_literal: true

# Records WHO ordered each side's fighters, which lineup_#{slot}_set alone
# cannot say: EncounterLineupSeeder confirms both sides the moment an admin
# opens a panel, so that flag reads true for an order nobody typed. Everything
# that protects hand-entered work from being re-drawn — the bracket swap's
# confirmation prompt, TeamPoolMove's, and the bracket builder's non-force
# update — asks Encounter#pristine?, which now reads these columns instead.
#
# Backfilled from lineup_#{slot}_set, which does copy forward the ambiguity
# this column exists to remove — deliberately, because the two mistakes are not
# symmetric. Crediting a merely auto-seeded order to an admin costs one
# dismissable prompt. NOT crediting an order an admin typed costs the order
# itself: Encounter#pristine? is the only guard on
# TeamCategoryBracketBuilder#update_existing_bracket, where a re-resolved slot
# runs #invalidate_matchup and destroys the bouts with no prompt at all. That
# reader does ask #unscored? first, but a lineup typed this morning and not yet
# fought is unscored, so the check does not save it.
#
# The over-crediting decays on its own: #invalidate_matchup clears all four
# columns together, and EncounterLineupSeeder's re-fill writes by_admin false,
# so a row stops over-prompting the first time it is genuinely re-drawn.
class AddLineupSetByAdminToEncounters < ActiveRecord::Migration[8.1]
  def up
    add_column :encounters, :lineup_1_set_by_admin, :boolean, default: false, null: false
    add_column :encounters, :lineup_2_set_by_admin, :boolean, default: false, null: false

    execute(<<~SQL.squish)
      UPDATE encounters
         SET lineup_1_set_by_admin = lineup_1_set,
             lineup_2_set_by_admin = lineup_2_set
       WHERE lineup_1_set OR lineup_2_set
    SQL
  end

  def down
    remove_column :encounters, :lineup_1_set_by_admin
    remove_column :encounters, :lineup_2_set_by_admin
  end
end
