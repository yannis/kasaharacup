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

  # Units per half. A half of P entries needs at least ceil(P / 2) units;
  # padding up to a power of two makes it a PERFECT tree, so no winner ever
  # waits out a round and the only advantage in the draw is a bye — which
  # bye_pools then hands to a pool winner. Without padding, a half of 3 units
  # leaves one unit a level shallower and its winner skips a round, which can
  # be a runner-up.
  #
  # Padding is refused once it would cost more byes than fights. Nine pools
  # would draw 7 byes and 1 fight per half; that is the padded power-of-two
  # tree this design exists to replace, and the organizers' own Ladies sheet
  # declines it too.
  def self.half_unit_count(pool_count)
    natural = (pool_count / 2.0).ceil
    padded = 2**Math.log2([natural, 1].max).ceil

    ((2 * padded - pool_count) <= (pool_count - padded)) ? padded : natural
  end

  # The pool ORDINALS holding a bye in each half, as [top, bottom].
  #
  # A bye takes a whole unit, so the pools between two byes must still pair up:
  # every gap has to be even, which puts consecutive byes an ODD number of pools
  # apart. Spacing them by three satisfies that and spreads them, so no two byes
  # ever share a round-2 node. The top counts up from the first pool and the
  # bottom down from the last, mirroring each other. Where that would give one
  # pool a bye in BOTH halves — impossible, since a pool sends its winner to
  # only one of them — the bottom shifts two pools inward, which keeps every gap
  # even.
  def self.bye_pools(pool_count)
    count = 2 * half_unit_count(pool_count) - pool_count
    return [[], []] if count.zero?

    top = Array.new(count) { |i| 1 + 3 * i }
    bottom = Array.new(count) { |i| pool_count - 3 * i }.sort
    bottom = Array.new(count) { |i| pool_count - 2 - 3 * i }.sort if (top & bottom).any?
    [top, bottom]
  end

  # One half's units as groups of pool ordinals: a bye pool alone, the rest in
  # consecutive pairs. Pools ascend, which is how every poster reads.
  def self.unit_groups(pool_count, byes)
    groups = []
    pool = 1
    while pool <= pool_count
      groups << (byes.include?(pool) ? [pool] : [pool, pool + 1])
      pool += groups.last.size
    end
    groups
  end

  # Each pool's rank in the TOP half; the bottom half takes the complement, so
  # a pool's two qualifiers always land in opposite halves. A pool holding a bye
  # must be the pool WINNER in that half, so those fix themselves first and the
  # rest alternate, which keeps a unit reading winner against runner-up wherever
  # the byes leave room.
  def self.top_ranks(pool_count)
    top_byes, bottom_byes = bye_pools(pool_count)
    ranks = {}
    top_byes.each { |pool| ranks[pool] = 1 }
    bottom_byes.each { |pool| ranks[pool] = 2 }
    unit_groups(pool_count, top_byes).each do |group|
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
    top_byes, bottom_byes = self.class.bye_pools(pool_numbers.size)
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
