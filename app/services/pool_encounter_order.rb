# frozen_string_literal: true

# A team category's pool ties in the order they are fought: the pools
# interleaved, so a tie from another pool sits between a team's two
# appearances. Fought pool by pool they would not: Pools::CyclicPairing draws a
# pool of three as (1,2), (3,2), (3,1), which puts team 3 on the court twice in
# a row.
#
# The ties come from the category's Encounter records rather than from that
# pairing. The generator drew them from it, but an admin can afterwards swap a
# tie's teams or move a team between pools, so the records are what the pool
# actually is and the formula is only where it started.
#
# Feeds both pool documents — the running order (TeamCategoryPoolOrderPdf) and
# the stack of match sheets (TeamCategoryPoolMatchesPdf) — so a sheet's place
# in the stack is the place the order gives it.
class PoolEncounterOrder
  # `position` of `pool_count` is where the tie sits in its own pool; `order`
  # is where it sits in the whole category's running order.
  Tie = Data.define(:encounter, :pool_number, :position, :pool_count, :order) do
    def label = "Pool #{pool_number} — #{position}/#{pool_count}"
  end

  def initialize(team_category)
    @team_category = team_category
  end

  # Round by round: the first tie of every pool, then the second of every pool,
  # and so on. A pool that has run out is skipped, so an uneven pool's tail
  # trails at the end — once it is the only pool left there is nothing to
  # separate its ties with.
  def call
    pools = rows_by_pool
    depth = pools.map(&:size).max || 0
    (0...depth).flat_map { |round| pools.filter_map { |rows| rows[round] } }
      .each_with_index.map { |row, index| Tie.new(**row, order: index + 1) }
  end

  private attr_reader :team_category

  # Pools in number order, and within a pool in the order the generator drew
  # them. Read through #encounters_by_pool_number so the whole category is
  # loaded at once rather than one query per pool.
  private def rows_by_pool
    by_pool = team_category.encounters_by_pool_number
    by_pool.keys.sort.map do |number|
      encounters = by_pool.fetch(number).sort_by(&:id)
      encounters.each_with_index.map do |encounter, index|
        {encounter: encounter, pool_number: number, position: index + 1, pool_count: encounters.size}
      end
    end
  end
end
