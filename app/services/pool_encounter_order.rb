# frozen_string_literal: true

# A team category's pool ties in the order they are fought: pool by pool, and
# within a pool in the classical order of the teams' pool positions — 1 <> 2,
# 1 <> 3, 2 <> 3. Not the order the generator drew them in:
# Pools::CyclicPairing draws a pool of three as (1,2), (3,2), (3,1).
#
# The ties come from the category's Encounter records rather than from that
# pairing. An admin can swap a tie's teams or move a team between pools after
# the draw, so the records are what the pool actually is. A tie keeps the sides
# its record gives it; only its place in the order comes from the positions.
#
# Feeds both pool documents — the running order (TeamCategoryPoolOrderPdf) and
# the stack of match sheets (TeamCategoryPoolMatchesPdf) — so a sheet's place
# in the stack is the place the order gives it.
class PoolEncounterOrder
  # `position` of `pool_count` is where the tie sits in its own pool; `order`
  # is where it sits in the whole category's running order. The label is what
  # both documents print, so the list's rows and the sheets in the stack name a
  # tie the same way — in the language of the session that printed them.
  Tie = Data.define(:encounter, :pool_number, :position, :pool_count, :order) do
    def label = "#{I18n.t("pool_fight_order.pool")} #{pool_number} — #{position}/#{pool_count}"
  end

  def initialize(team_category)
    @team_category = team_category
  end

  def call
    rows_by_pool.flatten.each_with_index.map { |row, index| Tie.new(**row, order: index + 1) }
  end

  private attr_reader :team_category

  # Pools in number order, each already in fighting order. Read through
  # #encounters_by_pool_number so the whole category, teams included, is loaded
  # at once rather than one query per pool.
  private def rows_by_pool
    by_pool = team_category.encounters_by_pool_number
    by_pool.keys.sort.map do |number|
      encounters = by_pool.fetch(number)
      encounters.each_with_index.map do |encounter, index|
        {encounter: encounter, pool_number: number, position: index + 1, pool_count: encounters.size}
      end
    end
  end
end
