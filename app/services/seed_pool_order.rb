# frozen_string_literal: true

# Which pool each seed of a category goes into, so the seeds meet as late as
# the bracket allows. Given a pool count it returns the pool numbers 1..count
# reordered — the i-th seed takes the i-th number:
#
#   SeedPoolOrder.order(4)  # => [1, 3, 4, 2]
#
# Cuts the numbers with BracketSeeder.low_block — the same call assign_halves
# makes — orders each block recursively, then snakes the two results together. A
# low-block pool sends its winner to the top half of the tree and a high-block
# pool sends its winner to the bottom, so sharing the cut is what makes the
# separation structural rather than a coincidence that would drift the next time
# the seeder is touched.
#
# The separation is over POOL WINNERS. assign_halves routes a slot by
# `pool_rank.odd? == in_low_block`, so a seed that only comes second in its pool
# is sent to the half its own pool winner did not take — which can be the half
# the other top seed went to. Seeds 1 and 2 therefore meet no earlier than the
# final whenever both win their pools, and can meet in a semifinal when one of
# them does not. Keeping them apart in that case would need assign_halves itself
# to know about seeds.
#
# The snake — rather than a plain alternation — is what reproduces the standard
# draw. Alternating strictly would send every odd seed to the low block, which
# separates seeds 1 and 2 but then hands seed 1 the strongest remaining
# opponent at every stage: projected semifinals 1 v 3 and 2 v 4. The snake
# gives the layout BracketPositions already documents for the team side, where
# each seed meets the weakest one left.
#
# An odd count leaves the high block one pool short. At three pools that block
# is a single pool: seed 2 takes it and seed 3 has nowhere to go but the top
# half, beside seed 1. Every larger count has room.
#
# The guarantee is in the rule, not in the database: assign_halves cuts the
# pool numbers the bracket builder finds on the participations, so a later
# hand-correction that adds a pool or empties one moves the cut. Seeding holds
# for the layout the reset produced.
module SeedPoolOrder
  # low, high, high, low — repeated.
  SNAKE = [0, 1, 1, 0].freeze
  private_constant :SNAKE

  def self.order(count)
    return [] if count < 1

    ordered((1..count).to_a)
  end

  private_class_method def self.ordered(pools)
    return pools if pools.size <= 1

    low = BracketSeeder.low_block(pools)
    snake(ordered(low), ordered(pools.drop(low.size)))
  end

  # Takes from whichever block still has entries when the other runs out: the
  # blocks differ in length for an odd pool count.
  private_class_method def self.snake(low, high)
    blocks = [low.dup, high.dup]
    Array.new(low.size + high.size) do |i|
      block = blocks[SNAKE[i % 4]]
      block = blocks.find(&:any?) if block.empty?
      block.shift
    end
  end
end
