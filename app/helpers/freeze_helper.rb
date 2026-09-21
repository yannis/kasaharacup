# frozen_string_literal: true

# Paths and dom ids for the pool / bracket freeze controls (issue #1319).
#
# Both are needed in two view contexts that cannot share a `helpers.` prefix:
# the ActiveAdmin show pages render the chrome partials from Arbre, and
# Admin::Freezing re-renders the very same partials into a Turbo Stream. Keeping
# the mapping here means the page and the broadcast cannot target different ids.
module FreezeHelper
  FREEZE_SURFACES = {
    ["IndividualCategory", :pools] =>
      {prefix: "individual_pools", path: :admin_individual_category_pool_freeze_path},
    ["IndividualCategory", :bracket] =>
      {prefix: "individual_tree", path: :admin_individual_category_bracket_freeze_path},
    ["TeamCategory", :pools] =>
      {prefix: "team_pools", path: :admin_team_category_pool_freeze_path},
    ["TeamCategory", :bracket] =>
      {prefix: "team_bracket", path: :admin_team_category_bracket_freeze_path}
  }.freeze

  def freeze_path(category, flag)
    public_send(surface_for(category, flag)[:path], category)
  end

  # The flag's state, read through the flag rather than by name, so the control
  # partial serves all four surfaces without a local variable per branch.
  #
  # Template locals are avoided here on purpose: erb_lint runs Rubocop over each
  # ERB tag in isolation, so a local assigned in one tag and read in the next
  # looks like a useless assignment, and the pre-commit hook's -a deletes the
  # assignment and leaves the read behind.
  def freeze_freezable?(category, flag)
    (flag.to_sym == :bracket) ? category.bracket_freezable? : category.pools_freezable?
  end

  def freeze_frozen_at(category, flag)
    (flag.to_sym == :bracket) ? category.bracket_frozen_at : category.pools_frozen_at
  end

  # The chrome container the freeze broadcast replaces. Always rendered, even
  # when the panel has no links to show, so the broadcast never misses a target.
  def freeze_actions_dom_id(category, flag)
    "#{surface_for(category, flag)[:prefix]}_actions_#{category.id}"
  end

  private def surface_for(category, flag)
    FREEZE_SURFACES.fetch([category.class.name, flag.to_sym])
  end
end
