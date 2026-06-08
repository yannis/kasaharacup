# frozen_string_literal: true

# Pure single-elimination seeding over abstract Slots. Given an ordered,
# rank-major list of Slot(pool_number, pool_rank, payload), returns the round-1
# pairing as [slot_or_nil, slot_or_nil] pairs (nil = a bye). Domain-agnostic:
# callers build the slots and turn the resulting pairs into their own records.
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
    low_block = pool_numbers.first((pool_numbers.size / 2.0).ceil)
    top = []
    bottom = []
    entries.each do |slot|
      in_low_block = low_block.include?(slot.pool_number)
      ((slot.pool_rank.odd? == in_low_block) ? top : bottom) << slot
    end
    [sort_by_strength(top), sort_by_strength(bottom)]
  end

  # Build the round-1 units (pairs; [slot, nil] for byes) for one half, ordered
  # by leading fighter so the round-1 column reads in pool-number order within
  # the half. half_size is an even power of two (the B == 2 case returns
  # earlier), so the post-bye `rest` cross_pool_match receives is always
  # even-sized. Slots are unique by (pool_number, pool_rank), so
  # `half_slots - byes` removes exactly the byes.
  private def build_half_units(half_slots)
    half_size = bracket_size / 2
    byes = select_byes(half_slots, half_size - half_slots.size)
    fights = cross_pool_match(sort_by_strength(half_slots - byes))
    units = byes.map { |slot| [slot, nil] } + fights
    units.sort_by { |pair| [pair.first.pool_number, pair.first.pool_rank] }
  end

  # Byes go to evenly-spaced pool winners (rank-1s) within the half, so the bye
  # advantage is distributed across the pool-number range rather than always
  # landing on the lowest-numbered pools. When a half has more byes than winners
  # (a small field in a large bracket), the spread spills over the half's entries
  # in rank-major order, so a pool may then receive more than one bye. Returns []
  # when there are no byes — never forces one, which would drop a fighter.
  private def select_byes(slots, byes_count)
    return [] if byes_count <= 0

    winners = slots.select { |slot| slot.pool_rank == 1 }.sort_by(&:pool_number)
    source = (byes_count <= winners.size) ? winners : sort_by_strength(slots)
    Array.new(byes_count) { |j| source[j * source.size / byes_count] }
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
  # i + half. Same-pool-free because select_byes caps every pool at <= rest/2.
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
