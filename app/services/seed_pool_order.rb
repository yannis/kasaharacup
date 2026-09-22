# frozen_string_literal: true

# Which pool each seed of a category goes into, so the seeds meet as late as
# the bracket allows. Given a pool count it returns the pool numbers 1..count
# reordered — the i-th seed takes the i-th number:
#
#   SeedPoolOrder.order(4)  # => [1, 2, 4, 3]
#
# Cuts the numbers with BracketSeeder.half_pools — the same call the draw makes
# — orders each half recursively, then snakes the two results together. The
# seeder reads a pool's half off its ordinal in the alternating layout, so
# sharing that call is what makes the separation structural rather than a
# coincidence that would drift the next time the seeder is touched.
#
# The separation is over POOL WINNERS. The draw alternates the two roles down
# each column, so a pool sends its winner to the half half_pools names and its
# runner-up to the other one — and a seed that only comes second in its pool
# lands in the half its own pool winner did not take, which can be the half the
# other top seed went to. Seeds 1 and 2 therefore meet no earlier than the final
# whenever both win their pools, and can meet in a semifinal when one of them
# does not. Keeping them apart in that case would need the draw itself to know
# about seeds.
#
# The snake — rather than a plain alternation — is what reproduces the standard
# draw. Alternating strictly would send every odd seed to the top half, which
# separates seeds 1 and 2 but then hands seed 1 the strongest remaining
# opponent at every stage: projected semifinals 1 v 3 and 2 v 4. The snake
# gives the layout BracketPositions already documents for the team side, where
# each seed meets the weakest one left — and it IS that layout: both the snake
# and the within-half recursion are BracketPositions', walked over pool numbers
# here and over unit positions there.
#
# Seeds 1 and 2 land in opposite halves at every pool count. Quarter separation
# — seed 1 against seed 4 in the top half, seed 2 against seed 3 in the bottom —
# also holds everywhere except five pools, whose bottom half splits one unit
# against two and whose shallow quarter is the single unit `1.2 v 2.2`, holding
# no pool winner for a seed to occupy. Three pools is the other thin case: the
# bottom half is a single pool, so seed 3 has nowhere to go but beside seed 1.
#
# The guarantee is in the rule, not in the database: half_pools cuts the pool
# numbers the bracket builder finds on the participations, so a later
# hand-correction that adds a pool or empties one moves the cut. Seeding holds
# for the layout the reset produced.
module SeedPoolOrder
  def self.order(count)
    return [] if count < 1

    top, bottom = BracketSeeder.half_pools(count)
    BracketPositions.snake(ordered(top), ordered(bottom))
  end

  # The pool each of `seed_count` seeds goes to, as ZERO-BASED indices into
  # target_sizes, in seed order. Both poolers walk the order this way, so the
  # walk lives here rather than once in each of them.
  #
  # The cursor advances rather than re-searching from the front: restarting at
  # the first pool for every seed would pile them all into it until it alone
  # reached target size, instead of giving each seed its own. The size check
  # only bites when the seeds outnumber the pools and the order wraps —
  # wrapping onto a pool already at target size would overfill it, so the
  # cursor skips past. A seed is one of the members target_sizes was computed
  # from, so a pool with room always exists and the skip always terminates.
  def self.assign(seed_count, target_sizes)
    indices = order(target_sizes.size).map { |number| number - 1 }
    filled = Array.new(target_sizes.size, 0)
    cursor = 0
    Array.new(seed_count) do
      index = indices[cursor % indices.size]
      while filled[index] >= target_sizes[index]
        cursor += 1
        index = indices[cursor % indices.size]
      end
      filled[index] += 1
      cursor += 1
      index
    end
  end

  # Within a half the winner-bearing pools sit one per unit in ascending order
  # and the compact tree splits that unit list contiguously, so a prefix of the
  # pool list is exactly a subtree — which is why only the top-level cut had to
  # change while the sub-cuts stay a plain ceil-half prefix. That prefix
  # recursion is BracketTree.split, and reading the protected order off it is
  # BracketPositions' job; a half of pool numbers is the same problem as a half
  # of unit positions, and doing it here too is how the two would drift.
  #
  # The size guard stays at this call site: BracketTree.split recurses forever
  # on an empty list, and half_pools hands back an empty bottom half at one pool.
  private_class_method def self.ordered(pools)
    return pools if pools.size <= 1

    BracketPositions.protected_order(BracketTree.split(pools, ceil_first: true), mirror: false)
  end
end
