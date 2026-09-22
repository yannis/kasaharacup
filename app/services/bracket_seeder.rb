# frozen_string_literal: true

# Pure single-elimination seeding over abstract Slots. Given an ordered,
# rank-major list of Slot(pool_number, pool_rank, payload), returns the round-1
# pairing as [slot_or_nil, slot_or_nil] pairs (nil = a bye) plus the shape of
# the tree built over them. Domain-agnostic: callers build the slots and turn
# the results into their own records.
#
# The draw is the organizers' own rule, recovered from the 2025 posters — see
# docs/superpowers/specs/2026-09-22-compact-bracket-draw-design.md. Each half
# reads down in ascending pool order, and is ALWAYS padded with byes up to a
# power-of-two unit count, so that the only advantage anyone carries is a
# first-round bye and no winner ever sits out a round once they have started
# fighting. The design document opened by arguing padding should go; checking
# the generated brackets against the posters reversed that, because without it
# the free round lands on a runner-up. The cost is byes at an awkward field
# size — nine pools draw 7 a half, 33 pools draw 31 — and that trade is the
# whole point rather than a regression.
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
  # The one piece of the draw anyone outside this class asks for: SeedPoolOrder
  # seeds against it, because the seeding and the draw must share one definition
  # of the cut, or a category is seeded for a tree the bracket does not build
  # and nothing fails to say so. Everything it is built from lives in Halves.
  def self.half_pools(pool_count)
    ranks = Halves.top_ranks(pool_count)

    (1..pool_count).partition { |pool| ranks[pool] == 1 }
  end

  # The pool-count arithmetic the draw is built from: pure functions of how many
  # pools there are, with no Slots in sight. Nested because half_pools is the
  # only part of it that is anyone else's business.
  module Halves
    # Units per half. Each half holds one qualifier from every pool, so the pool
    # count IS its entry count; BracketTree.half_size states the padding rule
    # that both seeders draw by.
    module_function def unit_count(pool_count)
      BracketTree.half_size(pool_count)
    end

    # Which UNITS hold a bye in each half. Both halves hold the same entries
    # here — one qualifier per pool — where a bracket-only field splits
    # unevenly.
    module_function def bye_units(pool_count)
      BracketPositions.bye_units(unit_count(pool_count), pool_count, pool_count)
    end

    # One half's units as groups of pool ordinals: a bye pool alone, the rest in
    # consecutive pairs. Pools ascend, which is how every poster reads.
    module_function def unit_groups(pool_count, byes)
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
    # a pool's two qualifiers always land in opposite halves. A pool holding a
    # bye should be the pool WINNER in that half, so those fix themselves first.
    #
    # Where a half needs more byes than the field has winners to give — nine
    # pools want 7 byes a half out of 9 pools — a pool is claimed by both halves
    # and only the top can have it. The bottom's bye then falls on a runner-up.
    # That is unavoidable once byes outnumber pools, and it is the price of a
    # perfect tree at an awkward field size.
    module_function def top_ranks(pool_count)
      top_byes, bottom_byes = bye_units(pool_count)
      top_groups = unit_groups(pool_count, top_byes)

      ranks = {}
      # A bye unit holds one pool, so its group is the one of size one — which
      # is what a bye POOL is, with no second walk needed to name it.
      top_groups.each { |group| ranks[group.first] = 1 if group.one? }
      unit_groups(pool_count, bottom_byes).each { |group| ranks[group.first] ||= 2 if group.one? }
      top_groups.each do |group|
        next if group.one?

        first, second = group
        ranks[first] ||= (ranks[second] == 1) ? 2 : 1
        ranks[second] ||= 3 - ranks[first]
      end
      ranks
    end
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
    top_byes, bottom_byes = Halves.bye_units(pool_numbers.size)
    [half_units(top_byes, top: true), half_units(bottom_byes, top: false)]
  end

  private def half_units(byes, top:)
    Halves.unit_groups(pool_numbers.size, byes).map do |group|
      entries = group.map { |ordinal| slot_for(pool_numbers[ordinal - 1], rank_for(ordinal, top: top)) }
      (entries.size == 1) ? [entries.first, nil] : entries
    end
  end

  private def rank_for(ordinal, top:)
    rank = top_ranks.fetch(ordinal)
    top ? rank : 3 - rank
  end

  private def top_ranks
    @top_ranks ||= Halves.top_ranks(pool_numbers.size)
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
