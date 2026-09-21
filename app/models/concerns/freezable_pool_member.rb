# frozen_string_literal: true

# The model half of the pools freeze (issue #1319, R6), shared by the two
# things that carry a pool number: Participation (individual categories) and
# Team (team ones). Includers implement three hooks:
#
#   freeze_category         -> the category whose flags govern this record
#   freeze_category_moving? -> is this save reassigning it to another category?
#   freeze_category_left    -> the category it is leaving, nil if it is not
#
# This exists because ActiveAdmin's plain Participation and Team forms permit
# pool_number / pool_position directly
# (app/admin/participation.rb, app/admin/team.rb), bypassing the move services
# and every controller guard with them. A rule that only lives in a controller
# cannot close that door, and neither can one that only lives in the UI.
#
# The same two forms also permit the category association — team_category_id on
# one side, category_id / category_type on the other — which is the other half
# of that door. Reassigning a pooled record empties a slot in the formation it
# leaves without either pool attribute changing, so watching only the pool
# attributes would let the frozen draw be taken apart one row at a time.
#
# What is deliberately NOT guarded: pool_rank, rank, seed and the results. The
# freeze protects the FORMATION — who is in which pool — while the pool phase
# goes on being played and recorded.
module FreezablePoolMember
  extend ActiveSupport::Concern

  included do
    validate :pools_not_frozen
    before_destroy :refuse_if_pools_frozen
  end

  # The error sits on pool_number for a move as well as for a pool write: what
  # the freeze protects is the row's place in the formation, and that is the
  # attribute naming it.
  private def pools_not_frozen
    return unless formation_membership_changing?
    return unless disturbed_categories.any? { |category| formation_frozen?(category) }

    errors.add(:pool_number, :pools_frozen)
  end

  # A pool write disturbs the formation the record sits in. A move to another
  # category disturbs two — the one it leaves and the one it joins — but only
  # while the record carries a pool number: an unpooled row is part of no
  # formation, so re-categorising it changes nothing the freeze protects.
  private def formation_membership_changing?
    return true if will_save_change_to_pool_number? || will_save_change_to_pool_position?

    freeze_category_moving? && (pool_number.present? || pool_number_was.present?)
  end

  private def disturbed_categories
    [freeze_category, (freeze_category_left if freeze_category_moving?)].compact
  end

  # The same rule the controllers apply through
  # Admin::FreezeGuard#guard_frozen_pools! — both flags close the formation, a
  # frozen bracket included (R5). Checking only the pools flag here would leave
  # the ActiveAdmin form as a back door the drag path refuses: with the pools
  # open and the bracket frozen, a row could still be moved between pools, and
  # the frozen tree would then describe a formation that no longer exists.
  private def formation_frozen?(category)
    category.pools_frozen? || category.bracket_frozen?
  end

  # Two exemptions, both deliberate.
  #
  # A record with no pool number is not part of the formation, so removing it
  # changes nothing the freeze protects. This is not a way around the rule
  # either: leaving a pool means writing pool_number, which the validation
  # above refuses, so a pooled record cannot be emptied out and then dropped.
  #
  # Keyed on the pools flag alone, unlike the validation above: a bracket-only
  # category has no pool numbers at all, so a bracket clause here would protect
  # nothing the tree actually references.
  #
  # A cascading destroy is exempt because four parents dependent: :destroy into
  # these rows — Cup -> categories -> participations/teams, Kenshi ->
  # participations, Team -> participations, TeamCategory -> teams. Throwing
  # here would make a frozen category, its cup and every kenshi registered in
  # it undeletable, each failing with an opaque pool_number error on a record
  # the admin never touched. Deleting the parent is already a far bigger
  # decision than the one this guard is protecting.
  private def refuse_if_pools_frozen
    return if destroyed_by_association
    return if pool_number.blank?
    return unless freeze_category&.pools_frozen?

    errors.add(:base, :pools_frozen_destroy)
    throw :abort
  end

  private def freeze_category = raise NotImplementedError

  private def freeze_category_moving? = raise NotImplementedError

  private def freeze_category_left = raise NotImplementedError
end
