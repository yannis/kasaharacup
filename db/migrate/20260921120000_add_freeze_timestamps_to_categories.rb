# frozen_string_literal: true

# Freeze flags for the two derived structures organizers settle during a cup:
# the pool formation and the elimination bracket (issue #1319). Two nullable
# datetimes per category rather than booleans — the admin panel badge shows
# when a category was frozen, and nil is the natural "not frozen".
#
# No index: every read is on a category already loaded by id.
class AddFreezeTimestampsToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :individual_categories, :pools_frozen_at, :datetime
    add_column :individual_categories, :bracket_frozen_at, :datetime
    add_column :team_categories, :pools_frozen_at, :datetime
    add_column :team_categories, :bracket_frozen_at, :datetime
  end
end
