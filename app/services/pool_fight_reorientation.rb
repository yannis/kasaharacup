# frozen_string_literal: true

# Puts an individual category's existing pool fights in the order and on the
# sides Pools::FightOrder gives them: numbered 1 <> 2, 1 <> 3, 2 <> 3, the red
# fighter as fighter_1. PoolFightGenerator draws new pools that way; pools
# drawn before it keep CyclicPairing's order until this runs over them (see
# lib/tasks/temporary/pools.rake).
#
# A pool is rewritten whole or not at all: its fights trade numbers, and the
# numbers are unique within a pool. A pool is left alone, and reported, when a
# fight in it is scored — points are keyed by fighter side — or when a fight's
# fighters no longer make a pair of the pool. A kettei-sen is not part of the
# order and keeps its number, after the rest.
#
# The columns are written directly, which skips the pool panel broadcast: an
# admin already looking at the pool sees the new order on the next reload.
class PoolFightReorientation
  Result = Data.define(:reordered, :skipped)

  def initialize(category)
    @category = category
  end

  def call(dry_run: false)
    reordered = []
    skipped = []
    category.transaction do
      category.pools.sort_by(&:number).each do |pool|
        fights = cyclic_fights(pool)
        # Not drawn yet: PoolFightGenerator will draw it in the new order.
        next if fights.empty?

        targets = targets_for(pool, fights)
        next if targets&.all? { |fight, target| current(fight) == target }

        if targets.nil? || fights.any? { |fight| !fight.unscored? }
          skipped << pool.number
        else
          rewrite!(targets) unless dry_run
          reordered << pool.number
        end
      end
    end
    Result.new(reordered: reordered, skipped: skipped)
  end

  private attr_reader :category

  private def cyclic_fights(pool)
    category.pool_fights_by_number.fetch(pool.number, []).reject(&:tiebreaker)
  end

  # {fight => {number:, fighter_1_id:, fighter_2_id:}}, or nil when a fight's
  # fighters are not a pair the pool fights. The pool keeps the numbers it
  # has, handed out in the new order.
  private def targets_for(pool, fights)
    ids = pool.participations.map(&:kenshi_id)
    order = Pools::FightOrder.sides_for(ids.size).map { |white, red| [ids[red - 1], ids[white - 1]] }
    return nil unless fights.size == order.size

    numbers = fights.map(&:number).sort
    fights.to_h do |fight|
      index = order.index { |pair| pair.to_set == [fight.fighter_1_id, fight.fighter_2_id].to_set }
      return nil if index.nil?

      red, white = order[index]
      [fight, {number: numbers[index], fighter_1_id: red, fighter_2_id: white}]
    end
  end

  private def current(fight)
    {number: fight.number, fighter_1_id: fight.fighter_1_id, fighter_2_id: fight.fighter_2_id}
  end

  # Negated first, so no two fights of the pool ever hold the same number
  # while they trade.
  private def rewrite!(targets)
    targets.each_key { |fight| Fight.where(id: fight.id).update_all(number: -fight.number) }
    targets.each { |fight, target| Fight.where(id: fight.id).update_all(**target, updated_at: Time.current) }
  end
end
