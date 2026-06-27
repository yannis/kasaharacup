# frozen_string_literal: true

# Moves one team into a pool of its team category — the admin's drag-and-drop
# pool-correction tool, which also adds a late-registering (unpooled) team to a
# pool or splits it off into a brand-new pool. A free move: the team is appended
# last in the destination, and a real source pool's positions are compacted to
# close the gap, so pools may end up unequal sizes. An unpooled source
# (pool_number nil) has no pool to compact or regenerate; a destination no team
# yet holds is created fresh.
#
# Because pool encounters and the elimination bracket are derived
# from pool membership and ranks, a move rebuilds them: the affected pools'
# encounters are regenerated, ranks reset, and any bracket cleared. When that
# would discard real work — a non-pristine destination/source pool encounter or
# an existing bracket — the move refuses unless `force` is set, so the caller
# can confirm first.
class TeamPoolMove
  Result = Data.define(:status, :from_pool, :to_pool, :created_pool, :emptied_pools,
    :bracket_cleared, :message)

  def initialize(team:, to_pool_number:, force: false)
    @team = team
    @category = team.team_category
    # A blank destination un-pools the team (pool_number -> nil); the unpooled
    # panel is the drop target for that.
    @to_pool = to_pool_number.presence&.to_i
    @from_pool = team.pool_number
    @force = force
  end

  def call
    return result(:noop) if to_pool == from_pool

    reasons = destructive_reasons
    return result(:needs_confirmation, message: confirmation_message(reasons)) if reasons.any? && !force

    # Whether the pool phase has been generated at all (category-wide): a pool
    # with < 2 teams has no encounters of its own, so a per-pool check would skip
    # regenerating a destination that only now has enough teams to need
    # encounters.
    encounters_generated = category.encounters.where.not(pool_number: nil).exists?
    bracket_existed = category.bracket_encounters.any?
    created = to_pool.present? && pool_new?(to_pool)

    category.transaction do
      move_team!
      compact_source!
      wipe_pool_encounters!
      affected_pools.each { |pool_number| regenerate!(pool_number) } if encounters_generated
      reset_ranks!
      clear_bracket! if bracket_existed
    end

    result(:ok, created_pool: created, emptied_pools: emptied_pools, bracket_cleared: bracket_existed)
  end

  private attr_reader :team, :category, :to_pool, :from_pool, :force

  # The real pools touched by this move. A nil source (unpooled team) contributes
  # nothing — and is excluded so a wipe/query never hits bracket or ad-hoc
  # encounters, which also carry pool_number nil.
  private def affected_pools
    [from_pool, to_pool].compact.uniq
  end

  # The moved team always loses its old pool_rank: a stale rank is meaningless
  # in its new pool, and would otherwise linger when un-pooling — where
  # reset_ranks! (scoped to the affected pools) never revisits the now
  # pool_number-nil team.
  private def move_team!
    team.update!(pool_number: to_pool, pool_position: next_position, pool_rank: nil)
  end

  # Appended last in the destination pool; nil (no position) when un-pooling.
  private def next_position
    return nil if to_pool.nil?

    (max_position(to_pool) || 0) + 1
  end

  # Renumber the source pool's remaining teams to 1..n in their existing order,
  # so the slot the moved team vacated does not leave a gap. No-op for an
  # unpooled source.
  private def compact_source!
    return if from_pool.nil?

    category.teams.where(pool_number: from_pool).order(:pool_position, :id)
      .each_with_index { |team, index| team.update!(pool_position: index + 1) }
  end

  # destroy_all (not delete_all): Encounter owns team_fights (dependent:
  # :destroy), which own polymorphic fight_points — let the dependent destroys
  # fire so no orphan rows survive.
  private def wipe_pool_encounters!
    return if affected_pools.empty?

    category.encounters.where(pool_number: affected_pools).destroy_all
  end

  private def regenerate!(pool_number)
    PoolEncounterGenerator.new(category, pool_number: pool_number).call
  end

  # Highest round first: bracket encounters reference their parents via
  # parent_encounter_*_id, so a parent cannot be destroyed while a child still
  # points at it. (Same order the bracket builder uses on rebuild.)
  private def clear_bracket!
    category.bracket_encounters.order(round: :desc).destroy_all
  end

  private def reset_ranks!
    category.teams.where(pool_number: affected_pools).update_all(pool_rank: nil)
  end

  private def destructive_reasons
    reasons = affected_pools.reject { |pool_number| pool_pristine?(pool_number) }
      .map { |pool_number| "Pool #{pool_number} has recorded results" }
    reasons << "a bracket has been generated" if category.bracket_encounters.any?
    reasons
  end

  private def pool_pristine?(pool_number)
    pool_encounters(pool_number).all?(&:pristine?)
  end

  private def pool_encounters(pool_number)
    category.encounters.where(pool_number: pool_number)
      .includes(team_fights: :fight_points).to_a
  end

  private def pool_new?(pool_number)
    !category.teams.exists?(pool_number: pool_number)
  end

  private def max_position(pool_number)
    category.teams.where(pool_number: pool_number).maximum(:pool_position)
  end

  private def emptied_pools
    return [] if from_pool.nil?

    category.teams.exists?(pool_number: from_pool) ? [] : [from_pool]
  end

  private def confirmation_message(reasons)
    "#{reasons.join(", ")} — moving this team will rebuild the affected pools. Move anyway?"
  end

  private def result(status, created_pool: false, emptied_pools: [], bracket_cleared: false, message: nil)
    Result.new(status:, from_pool:, to_pool:, created_pool:, emptied_pools:, bracket_cleared:, message:)
  end
end
