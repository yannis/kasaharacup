# frozen_string_literal: true

# The model half of the pools freeze (issue #1319, R6), shared by the two
# things that carry a pool number: Participation (individual categories) and
# Team (team ones). Includers implement one hook:
#
#   freeze_category -> the category whose pools flag governs this record
#
# This exists because ActiveAdmin's plain Participation and Team forms permit
# pool_number / pool_position directly
# (app/admin/participation.rb, app/admin/team.rb), bypassing the move services
# and every controller guard with them. A rule that only lives in a controller
# cannot close that door, and neither can one that only lives in the UI.
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

  private def pools_not_frozen
    return unless will_save_change_to_pool_number? || will_save_change_to_pool_position?
    return unless freeze_category&.pools_frozen?

    errors.add(:pool_number, :pools_frozen)
  end

  # Two exemptions, both deliberate.
  #
  # A record with no pool number is not part of the formation, so removing it
  # changes nothing the freeze protects. This is not a way around the rule
  # either: leaving a pool means writing pool_number, which the validation
  # above refuses, so a pooled record cannot be emptied out and then dropped.
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

    errors.add(:base, :pools_frozen)
    throw :abort
  end

  private def freeze_category = raise NotImplementedError
end
