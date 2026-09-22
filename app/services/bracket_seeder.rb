# frozen_string_literal: true

# Pure single-elimination seeding over abstract Slots. Given an ordered,
# rank-major list of Slot(pool_number, pool_rank, payload), returns the round-1
# pairing as [slot_or_nil, slot_or_nil] pairs (nil = a bye) plus the shape of
# the tree built over them. Domain-agnostic: callers build the slots and turn
# the results into their own records.
#
# The draw is the organizers' own rule, recovered from the 2025 posters — see
# docs/superpowers/specs/2026-09-22-compact-bracket-draw-design.md. Each half
# reads down in ascending pool order, and a half is padded with byes up to a
# power-of-two unit count WHEN THAT IS CHEAP, so that the only advantage anyone
# carries is a bye held by a pool winner. Padding is refused once it would cost
# more byes than fights: at nine pools it would draw 7 byes and 1 fight per
# half, which is the padded tree this design replaced.
#
# ASSUMES complete rank layers: every pool_number it is fed appears at every
# pool_rank. Sparse input — e.g. bracket-only slot lists — uses
# BracketOnlySeeder instead.
class BracketSeeder
  Slot = Data.define(:pool_number, :pool_rank, :payload)

  def initialize(slots)
    @slots = slots
  end

  def first_round_pairs
    @first_round_pairs ||= unit_halves.flatten(1)
  end

  def tree_shape
    @tree_shape ||= BracketTree.shape(unit_halves.first.size, unit_halves.last.size)
  end

  # The pool ORDINALS (1-based, in ascending pool-number order) whose WINNER
  # sits in each half, as [top, bottom].
  #
  # Public because SeedPoolOrder seeds against it: the seeding and the draw must
  # share one definition of the cut, or a category is seeded for a tree the
  # bracket does not build and nothing fails to say so.
  def self.half_pools(pool_count)
    ranks = top_ranks(pool_count)

    (1..pool_count).partition { |pool| ranks[pool] == 1 }
  end

  # Units per half, always a power of two, so the half is a PERFECT tree: byes
  # exist only in round 1 and no winner ever sits out a round once they have
  # started fighting. A ragged half would leave one unit a level shallower and
  # its winner skipping a round, which is what the organizers never draw.
  #
  # The cost is byes. Nine pools draw 7 per half rather than 1, and 33 pools
  # draw 31. That is accepted: a later-round skip is worse than a first-round
  # bye, and a bye is what every poster uses to absorb an awkward field size.
  def self.half_unit_count(pool_count)
    2**Math.log2([(pool_count / 2.0).ceil, 1].max).ceil
  end

  # Which UNITS hold a bye in each half, most-protected first, so the byes are
  # spread as widely as the half allows and meet each other as late as it can
  # manage. Where byes outnumber the units' round-2 pairings they must meet
  # earlier; nothing can be done about that.
  def self.bye_units(pool_count)
    units = half_unit_count(pool_count)
    count = 2 * units - pool_count
    return [[], []] if count.zero?

    order = BracketPositions.spread_order(BracketTree.shape(units, units))
    top = order.select { |unit| unit < units }.first(count).sort
    bottom = order.filter_map { |unit| unit - units if unit >= units }.first(count).sort
    [top, bottom]
  end

  # The pool ORDINALS holding a bye in each half. A bye unit takes one pool and
  # a fight unit two, so walking the pools up the column fixes which pool each
  # bye lands on.
  def self.bye_pools(pool_count)
    bye_units(pool_count).map do |byes|
      unit_groups(pool_count, byes).each_with_index.filter_map { |group, unit| group.first if byes.include?(unit) }
    end
  end

  # One half's units as groups of pool ordinals: a bye pool alone, the rest in
  # consecutive pairs. Pools ascend, which is how every poster reads.
  def self.unit_groups(pool_count, byes)
    groups = []
    pool = 1
    unit = 0
    while pool <= pool_count
      groups << (byes.include?(unit) ? [pool] : [pool, pool + 1])
      pool += groups.last.size
      unit += 1
    end
    groups
  end

  # Each pool's rank in the TOP half; the bottom half takes the complement, so
  # a pool's two qualifiers always land in opposite halves. A pool holding a bye
  # should be the pool WINNER in that half, so those fix themselves first.
  #
  # Where a half needs more byes than the field has winners to give — nine pools
  # want 7 byes a half out of 9 pools — a pool is claimed by both halves and
  # only the top can have it. The bottom's bye then falls on a runner-up. That
  # is unavoidable once byes outnumber pools, and it is the price of a perfect
  # tree at an awkward field size.
  def self.top_ranks(pool_count)
    top_byes, bottom_byes = bye_pools(pool_count)
    ranks = {}
    top_byes.each { |pool| ranks[pool] = 1 }
    bottom_byes.each { |pool| ranks[pool] ||= 2 }
    unit_groups(pool_count, bye_units(pool_count).first).each do |group|
      next if group.size == 1

      first, second = group
      ranks[first] ||= (ranks[second] == 1) ? 2 : 1
      ranks[second] = (ranks[first] == 1) ? 2 : 1 if ranks[second].nil?
    end
    ranks
  end

  private def unit_halves
    @unit_halves ||= base_case || (two_qualifiers? ? rule_a_halves : fallback_halves)
  end

  # A one-entry field is a bye; a two-entry field is a single final. The halving
  # would otherwise hand each half of a two-entry field a bye and draw a final
  # between them.
  private def base_case
    return [[], []] if @slots.empty?
    return [[], [[@slots.first, nil]]] if @slots.size == 1
    return [[], [[@slots.first, @slots.last]]] if @slots.size == 2

    nil
  end

  private def two_qualifiers?
    ranks == [1, 2]
  end

  # The two-qualifiers-per-pool draw every category uses. Each half is a column
  # of units read top to bottom in ascending pool order: a bye unit holds one
  # pool winner, every other unit holds two consecutive pools. The bottom half
  # takes the complementary rank for every pool, so a pool's two qualifiers
  # always land in opposite halves.
  private def rule_a_halves
    top_byes, bottom_byes = self.class.bye_units(pool_numbers.size)
    [half_units(top_byes, top: true), half_units(bottom_byes, top: false)]
  end

  private def half_units(byes, top:)
    self.class.unit_groups(pool_numbers.size, byes).map do |group|
      entries = group.map { |ordinal| slot_for(pool_numbers[ordinal - 1], rank_for(ordinal, top: top)) }
      (entries.size == 1) ? [entries.first, nil] : entries
    end
  end

  private def rank_for(ordinal, top:)
    rank = top_ranks.fetch(ordinal)
    top ? rank : 3 - rank
  end

  private def top_ranks
    @top_ranks ||= self.class.top_ranks(pool_numbers.size)
  end

  # out_of_pool other than 2 is out of scope for the poster rule: its
  # winner/runner-up alternation does not extend past two qualifiers. Keying the
  # halves on the pool's ORDINAL plus its rank keeps a pool's qualifiers out of
  # one half and holds the halves within one entry of each other, so the
  # one-bye-per-half cap survives. Nothing more is claimed; a spec pins it.
  private def fallback_halves
    top = []
    bottom = []
    ranks.each do |rank|
      pool_numbers.each_with_index do |pool_number, index|
        ((index + 1 + rank).even? ? top : bottom) << slot_for(pool_number, rank)
      end
    end
    [units(with_leading_bye(top)), units(with_trailing_bye(bottom))]
  end

  # Step 2. A half holding an odd number of entries gives its OUTERMOST entry
  # the bye: the first unit in the top half, the last in the bottom.
  private def with_leading_bye(column)
    column.size.odd? ? column.first(1) + [nil] + column.drop(1) : column
  end

  private def with_trailing_bye(column)
    column.size.odd? ? column + [nil] : column
  end

  private def units(column)
    column.each_slice(2).map { |first, second| [first, second] }
  end

  private def pool_numbers
    @pool_numbers ||= @slots.map(&:pool_number).uniq.sort
  end

  private def ranks
    @ranks ||= @slots.map(&:pool_rank).uniq.sort
  end

  private def slot_for(pool_number, pool_rank)
    @by_key ||= @slots.index_by { |slot| [slot.pool_number, slot.pool_rank] }
    @by_key[[pool_number, pool_rank]]
  end
end
