# frozen_string_literal: true

# Moves one participation into a pool of its individual category — the admin's
# drag-and-drop pool-correction tool, which also adds a late-registering
# (unpooled) participant to a pool or splits it off into a brand-new pool. A
# free move: the participant is appended last in the destination, and a real
# source pool's positions are compacted to close the gap, so pools may end up
# unequal sizes. An unpooled source (pool_number nil) has no pool to compact or
# regenerate; a destination no participant holds yet is created fresh.
#
# Because pool cyclic fights and the elimination bracket are derived from pool
# membership and ranks, a move rebuilds them: the affected pools' fights are
# regenerated, ranks reset, and any bracket cleared. When that would discard
# real work — a non-pristine pool fight or an existing bracket — the move
# refuses unless `force` is set, so the caller can confirm first.
#
# Individual analog of TeamPoolMove (Participation/Fight instead of
# Team/Encounter).
class PoolMembershipMove
  Result = Data.define(:status, :from_pool, :to_pool, :created_pool, :emptied_pools,
    :bracket_cleared, :message)

  def initialize(participation:, to_pool_number:, force: false)
    @participation = participation
    @category = participation.category
    # A blank destination un-pools the participant (pool_number -> nil); the
    # unpooled panel is the drop target for that.
    @to_pool = to_pool_number.presence&.to_i
    @from_pool = participation.pool_number
    @force = force
  end

  def call
    return result(:noop) if to_pool == from_pool

    reasons = destructive_reasons
    return result(:needs_confirmation, message: confirmation_message(reasons)) if reasons.any? && !force

    fights_generated = category.pool_fights.exists?
    bracket_existed = category.bracket_fights.any?
    created = to_pool.present? && pool_new?(to_pool)

    category.transaction do
      move_member!
      compact_source!
      wipe_pool_fights!
      affected_pools.each { |pool_number| regenerate!(pool_number) } if fights_generated
      reset_ranks!
      clear_bracket! if bracket_existed
    end

    result(:ok, created_pool: created, emptied_pools: emptied_pools, bracket_cleared: bracket_existed)
  end

  private attr_reader :participation, :category, :to_pool, :from_pool, :force

  private def affected_pools
    [from_pool, to_pool].compact.uniq
  end

  # The moved member always loses its old pool_rank: a stale rank is meaningless
  # in its new pool, and would otherwise linger forever when un-pooling — where
  # reset_ranks! (scoped to the affected pools) never revisits the now
  # pool_number-nil record. (TeamPoolMove has the same latent gap; fixed here.)
  private def move_member!
    participation.update!(pool_number: to_pool, pool_position: next_position, pool_rank: nil)
  end

  private def next_position
    return nil if to_pool.nil?

    (max_position(to_pool) || 0) + 1
  end

  private def compact_source!
    return if from_pool.nil?

    category.participations.where(pool_number: from_pool).order(:pool_position, :id)
      .each_with_index { |member, index| member.update!(pool_position: index + 1) }
  end

  # destroy_all (not delete_all): Fight owns fight_points (dependent: :destroy),
  # so let the dependent destroys fire and leave no orphan rows.
  private def wipe_pool_fights!
    return if affected_pools.empty?

    category.pool_fights.where(pool_number: affected_pools).destroy_all
  end

  private def regenerate!(pool_number)
    PoolFightGenerator.new(category, pool_number: pool_number).call
  end

  # Matches how IndividualCategoryBracketBuilder clears the tree on a force
  # rebuild.
  private def clear_bracket!
    category.bracket_fights.destroy_all
  end

  private def reset_ranks!
    category.participations.where(pool_number: affected_pools).update_all(pool_rank: nil)
  end

  private def destructive_reasons
    reasons = affected_pools.reject { |pool_number| pool_pristine?(pool_number) }
      .map { |pool_number| "Pool #{pool_number} has recorded results" }
    reasons << "a bracket has been generated" if category.bracket_fights.any?
    reasons
  end

  private def pool_pristine?(pool_number)
    pool_fights(pool_number).all?(&:pristine?)
  end

  private def pool_fights(pool_number)
    category.pool_fights.where(pool_number: pool_number).includes(:fight_points).to_a
  end

  private def pool_new?(pool_number)
    !category.participations.exists?(pool_number: pool_number)
  end

  private def max_position(pool_number)
    category.participations.where(pool_number: pool_number).maximum(:pool_position)
  end

  private def emptied_pools
    return [] if from_pool.nil?

    category.participations.exists?(pool_number: from_pool) ? [] : [from_pool]
  end

  private def confirmation_message(reasons)
    "#{reasons.join(", ")} — moving this participant will rebuild the affected pools. Move anyway?"
  end

  private def result(status, created_pool: false, emptied_pools: [], bracket_cleared: false, message: nil)
    Result.new(status:, from_pool:, to_pool:, created_pool:, emptied_pools:, bracket_cleared:, message:)
  end
end
