# frozen_string_literal: true

# Pure single-elimination seeding over abstract Slots. Given an ordered,
# rank-major list of Slot(pool_number, pool_rank, payload), returns the round-1
# pairing as [slot_or_nil, slot_or_nil] pairs (nil = a bye). Domain-agnostic:
# callers build the slots and turn the resulting pairs into their own records.
#
# ASSUMES complete rank layers: every pool_number it is fed appears at every
# pool_rank in the input (the pooled builder guarantees this). Sparse input —
# e.g. bracket-only slot lists — breaks assign_halves balance and select_byes
# uniqueness; that mode uses BracketOnlySeeder instead.
class BracketSeeder
  Slot = Data.define(:pool_number, :pool_rank, :payload)

  def initialize(slots)
    @slots = slots
  end

  def first_round_pairs
    entries = @slots
    return [] if entries.empty?
    return [[entries.first, nil]] if entries.size == 1

    top, bottom = assign_halves(entries)
    return [[top.first, bottom.first]] if bracket_size == 2

    build_half_units(top) + build_half_units(bottom)
  end

  def bracket_size
    return 0 if @slots.empty?

    2**Math.log2(@slots.size).ceil
  end

  # The tree built over first_round_pairs, as nested indices into it (see
  # BracketTree). The builders can no longer derive the shape by pairing
  # adjacent units, because the compact draw's halves are not the same size.
  def tree_shape
    @tree_shape ||= BracketTree.shape(*unit_half_sizes)
  end

  # The low/high cut over a category's pool numbers, public so SeedPoolOrder can
  # seed into the same split assign_halves will later apply. One definition or
  # the separation is a coincidence: a change here that the seeding service did
  # not follow would mis-seed every category while both their specs stayed green.
  def self.low_block(pool_numbers)
    pool_numbers.first((pool_numbers.size / 2.0).ceil)
  end

  # Today's halves are equal powers of two; a later task replaces this with the
  # real per-half unit counts once the halves can differ.
  private def unit_half_sizes
    count = first_round_pairs.size
    [count / 2, count - count / 2]
  end

  # Derived from the input (was a DB query on the category in the old builder).
  private def pool_numbers
    @pool_numbers ||= @slots.map(&:pool_number).uniq.sort
  end

  # Split entries into a top and bottom half. The pools are cut into a low block
  # (the first half of pool numbers) and a high block. A low-block pool sends its
  # rank-1 to the top half and rank-2 to the bottom; a high-block pool does the
  # reverse (odd ranks follow rank-1, even ranks follow rank-2). This keeps each
  # pool's rank-1 and rank-2 in opposite halves, and — because the low/high cut
  # spans the whole pool-number range — lets evenly-spaced byes (see select_byes)
  # fall one per half.
  private def assign_halves(entries)
    low_block = self.class.low_block(pool_numbers)
    top = []
    bottom = []
    entries.each do |slot|
      in_low_block = low_block.include?(slot.pool_number)
      ((slot.pool_rank.odd? == in_low_block) ? top : bottom) << slot
    end
    [sort_by_strength(top), sort_by_strength(bottom)]
  end

  # Build the round-1 units (pairs; [slot, nil] for byes) for one half.
  # half_size is an even power of two (the B == 2 case returns earlier), so the
  # post-bye `rest` cross_pool_match receives is always even-sized. Slots are
  # unique by (pool_number, pool_rank), so `half_slots - byes` removes exactly
  # the byes.
  private def build_half_units(half_slots)
    half_size = bracket_size / 2
    byes = select_byes(half_slots, half_size - half_slots.size)
    fights = cross_pool_match(sort_by_strength(half_slots - byes))
    place(byes, fights)
  end

  # Plain pool-number order is the most readable column — neighbouring pools sit
  # next to each other — and because select_byes already spreads the byes over
  # the pool range, it often separates them in every round by itself. When it
  # falls short at any depth, place them structurally instead. Same greedy-then-
  # guaranteed shape as cross_pool_match.
  private def place(byes, fights)
    bye_units = byes.map { |slot| [slot, nil] }
    natural = by_pool(bye_units + fights)
    balanced?(natural) ? natural : spread_byes(bye_units, fights)
  end

  # Byes take the half's most-spread positions, so they land in distinct round-2
  # slots (and distinct quarters, eighths, ... as far as their number allows)
  # rather than meeting each other and cancelling out; the fights fill what is
  # left. The positions are used in ascending order, so both groups still read
  # down the column in pool-number order.
  private def spread_byes(bye_units, fights)
    units = Array.new(bye_units.size + fights.size)
    positions = BracketPositions.spread_order(units.size).first(bye_units.size).sort
    by_pool(bye_units).each_with_index { |unit, i| units[positions[i]] = unit }
    open = units.each_index.reject { |i| units[i] }
    by_pool(fights).each_with_index { |unit, i| units[open[i]] = unit }
    units
  end

  # Byes are spread as evenly as the bracket allows when no round-2 slot holds
  # more than one more of them than another — and the same of every deeper
  # round, so a column never ties at round 2 while clumping its byes into one
  # quarter. Checking round 2 alone would accept exactly that.
  private def balanced?(units)
    depth = 2
    while depth <= units.size
      counts = units.each_slice(depth).map { |group| group.count { |unit| unit.last.nil? } }
      return false if counts.max - counts.min > 1

      depth *= 2
    end
    true
  end

  private def by_pool(units)
    units.sort_by { |pair| [pair.first.pool_number, pair.first.pool_rank] }
  end

  # Byes go to evenly-spaced pool winners (rank-1s) within the half, so the bye
  # advantage is distributed across the pool-number range rather than always
  # landing on the lowest-numbered pools. When a half has more byes than winners
  # (a small field in a large bracket), *every* winner takes one and the surplus
  # spills over the remaining entries by strength, so a runner-up never holds a
  # bye while a winner fights. Returns [] when there are no byes — never forces
  # one, which would drop a fighter.
  private def select_byes(slots, byes_count)
    return [] if byes_count <= 0

    winners = slots.select { |slot| slot.pool_rank == 1 }.sort_by(&:pool_number)
    byes = if byes_count <= winners.size
      evenly_spaced(winners, byes_count)
    else
      winners + evenly_spaced(sort_by_strength(slots - winners), byes_count - winners.size)
    end
    keep_rest_matchable(slots, byes, winners)
  end

  # cross_pool_match can only guarantee a cross-pool draw while no pool holds
  # more than half of `rest`. Spreading the byes over the pool range usually
  # leaves that true, but a half whose byes nearly fill it can strand two
  # entries of one pool together. Hand that pool's strongest leftover a bye in
  # exchange for the weakest bye held elsewhere, until the cap holds again.
  # Only non-winner byes are traded away, so every pool winner keeps its bye.
  private def keep_rest_matchable(slots, byes, winners)
    slots.size.times do
      rest = slots - byes
      pool = dominant_pool(rest)
      break unless pool

      traded_out = sort_by_strength(byes - winners).rfind { |slot| slot.pool_number != pool }
      break unless traded_out

      traded_in = sort_by_strength(rest.select { |slot| slot.pool_number == pool }).first
      byes = byes - [traded_out] + [traded_in]
    end
    byes
  end

  # The one pool holding more than half of `rest`, if any — at most one can.
  # A single-pool half always has one, and nothing can be done about it there.
  private def dominant_pool(rest)
    rest.group_by(&:pool_number).find { |_pool, members| members.size * 2 > rest.size }&.first
  end

  # Take `count` entries spaced evenly across the whole of `source`, endpoints
  # included: 2 of 3 picks the first and last, not the first and second the way
  # `j * size / count` did. A lone pick takes the front (the strongest entry),
  # there being no range to spread it over. Asking for more than `source` holds
  # would repeat entries — entering one competitor twice and dropping another —
  # so refuse rather than corrupt the draw.
  private def evenly_spaced(source, count)
    raise ArgumentError, "cannot spread #{count} picks over #{source.size} entries" if count > source.size
    return source.first(1) if count == 1

    Array.new(count) { |j| source[j * (source.size - 1) / (count - 1)] }
  end

  # Match the (even-sized, strength-sorted) `rest` into cross-pool fights. The
  # greedy pass gives the most legible draw (a winner vs another pool's
  # runner-up) but is a heuristic that can still leave a same-pool pair even when
  # a cross-pool matching exists; grouped_cross_pool is the guaranteed fallback.
  private def cross_pool_match(rest)
    fights = greedy_cross_pool(rest)
    same_pool?(fights) ? grouped_cross_pool(rest) : fights
  end

  # Pair each stronger entry with the next weaker entry from a different pool.
  # `|| 0` only fires when no different-pool entry remains (a single pool filling
  # the half, i.e. P == 1, where a same-pool meeting is unavoidable).
  private def greedy_cross_pool(rest)
    count = rest.size / 2
    weaker = rest.last(count)
    rest.first(count).map do |slot_1|
      index = weaker.index { |slot| slot.pool_number != slot_1.pool_number } || 0
      [slot_1, weaker.delete_at(index)]
    end
  end

  # Guaranteed cross-pool matching: group by pool (largest first), pair i with
  # i + half. Same-pool-free because select_byes holds every pool to <= rest/2
  # (see keep_rest_matchable); a single-pool half is the one exception.
  private def grouped_cross_pool(rest)
    grouped = rest.sort_by { |slot|
      [-rest.count { |other| other.pool_number == slot.pool_number }, slot.pool_number, slot.pool_rank]
    }
    half = rest.size / 2
    (0...half).map { |i| [grouped[i], grouped[i + half]] }
  end

  private def same_pool?(fights)
    fights.any? { |slot_1, slot_2| slot_1 && slot_2 && slot_1.pool_number == slot_2.pool_number }
  end

  private def sort_by_strength(slots)
    slots.sort_by { |slot| strength_key(slot) }
  end

  # Rank-major: lower rank, then lower pool number, is stronger.
  private def strength_key(slot)
    [slot.pool_rank, slot.pool_number]
  end
end
