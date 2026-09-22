# frozen_string_literal: true

# Pure single-elimination seeding over abstract Slots. Given an ordered,
# rank-major list of Slot(pool_number, pool_rank, payload), returns the round-1
# pairing as [slot_or_nil, slot_or_nil] pairs (nil = a bye) plus the shape of
# the tree built over them. Domain-agnostic: callers build the slots and turn
# the results into their own records.
#
# The draw is the organizers' own rule, recovered from the 2025 posters — see
# docs/superpowers/specs/2026-09-22-compact-bracket-draw-design.md. Each half
# reads down in ascending pool order and the tree is built by recursive halving
# rather than padded to a power of two, so a field of 18 draws 8 round-1 fights
# and 2 byes where the padded tree drew 2 fights and 14 byes.
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
  # bracket does not build and nothing fails to say so. That is exactly what the
  # low_block cut below did once the halves stopped being a low/high split.
  def self.half_pools(pool_count)
    (1..pool_count).partition { |ordinal| top_slot_index(ordinal, pool_count).even? }
  end

  # Where a pool's top-half entry sits in that column. Roles alternate — an even
  # index is a pool winner, an odd index a runner-up — and an odd pool count
  # parks the half's bye at index 1, shifting every pool from the second on one
  # slot along.
  def self.top_slot_index(ordinal, pool_count)
    (pool_count.odd? && ordinal >= 2) ? ordinal : ordinal - 1
  end

  # DEPRECATED, deleted by the SeedPoolOrder task. The halves are no longer a
  # low/high cut over the pool numbers, and nothing in here uses this any more —
  # but SeedPoolOrder and its spec still call it, and moving them onto
  # half_pools changes how every category is seeded, which belongs in its own
  # commit rather than buried in this one.
  def self.low_block(pool_numbers)
    pool_numbers.first((pool_numbers.size / 2.0).ceil)
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

  # Step 1, for the two-qualifiers-per-pool draw every category uses. The top
  # half alternates winner/runner-up down the column with the pools taking the
  # free slots in ascending order; the bottom half takes the complementary rank
  # for every pool, in the same order. Step 2 then pairs consecutive entries,
  # and a column's empty slot becomes that half's bye.
  private def rule_a_halves
    [units(top_column), units(bottom_column)]
  end

  private def top_column
    column = Array.new(pool_numbers.size + (pool_numbers.size.odd? ? 1 : 0))
    pool_numbers.each_with_index do |pool_number, index|
      slot_index = self.class.top_slot_index(index + 1, pool_numbers.size)
      column[slot_index] = slot_for(pool_number, slot_index.even? ? 1 : 2)
    end
    column
  end

  private def bottom_column
    column = pool_numbers.each_with_index.map { |pool_number, index|
      slot_index = self.class.top_slot_index(index + 1, pool_numbers.size)
      slot_for(pool_number, slot_index.even? ? 2 : 1)
    }
    pool_numbers.size.odd? ? column + [nil] : column
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
