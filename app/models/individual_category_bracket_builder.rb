# frozen_string_literal: true

class IndividualCategoryBracketBuilder
  Slot = Data.define(:pool_number, :pool_rank, :participation)

  def initialize(category, rebuild_started: false)
    @category = category
    @rebuild_started = rebuild_started
  end

  def call
    return [] if slot_specs.empty?

    category.transaction do
      if category.bracket_fights.empty?
        create_new_bracket
      elsif rebuild_started
        category.bracket_fights.destroy_all
        create_new_bracket
      else
        update_existing_bracket
      end
    end
    category.bracket_fights.bracket_order.to_a
  end

  private attr_reader :category, :rebuild_started

  private def create_new_bracket
    first_round_fights = create_first_round_fights
    create_parent_rounds(first_round_fights)
  end

  private def update_existing_bracket
    category.bracket_fights.includes(:winner).where(round: 1).find_each do |fight|
      [1, 2].each { |slot| update_fighter_slot(fight, slot) }
    end
  end

  private def update_fighter_slot(fight, slot)
    return if fight.winner.present?

    pool_number = fight.public_send(:"fighter_#{slot}_pool_number")
    pool_rank = fight.public_send(:"fighter_#{slot}_pool_rank")
    return if pool_number.blank? || pool_rank.blank?

    participation = participations_by_slot[[pool_number, pool_rank]]
    new_kenshi_id = participation&.kenshi_id
    return if new_kenshi_id == fight.public_send(:"fighter_#{slot}_id")

    # The kenshi is sourced from a valid participation in the category, so we can
    # bypass fighters_participate_in_category (which would issue an exists? per
    # fighter per fight and dominate the cost of a rebuild).
    fight.update_columns(
      "fighter_#{slot}_id": new_kenshi_id,
      fighter_type: "Kenshi",
      updated_at: Time.current
    )
  end

  private def create_first_round_fights
    first_round_pairs.map.with_index(1) do |(slot_1, slot_2), position|
      attrs = {
        number: position,
        round: 1,
        position: position,
        fighter_type: "Kenshi",
        fighter_1_pool_number: slot_1&.pool_number,
        fighter_1_pool_rank: slot_1&.pool_rank,
        fighter_2_pool_number: slot_2&.pool_number,
        fighter_2_pool_rank: slot_2&.pool_rank
      }
      attrs[:fighter_1_id] = slot_1.participation&.kenshi_id if slot_1
      attrs[:fighter_2_id] = slot_2.participation&.kenshi_id if slot_2
      category.fights.create!(attrs)
    end
  end

  private def create_parent_rounds(child_fights)
    fights = child_fights
    round = 2
    number = child_fights.size

    while fights.size > 1
      fights = fights.each_slice(2).map.with_index(1) do |(parent_fight_1, parent_fight_2), position|
        number += 1
        category.fights.create!(
          number: number,
          round: round,
          position: position,
          fighter_type: "Kenshi",
          parent_fight_1: parent_fight_1,
          parent_fight_2: parent_fight_2
        )
      end
      round += 1
    end
  end

  private def first_round_pairs
    entries = slot_specs
    return [] if entries.empty?
    return [[entries.first, nil]] if entries.size == 1

    top, bottom = assign_halves(entries)
    return [[top.first, bottom.first]] if bracket_size == 2

    build_half_units(top) + build_half_units(bottom)
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

  private def bracket_size
    return 0 if slot_specs.empty?

    2**Math.log2(slot_specs.size).ceil
  end

  private def slot_specs
    @slot_specs ||= (1..category.out_of_pool.to_i).flat_map do |pool_rank|
      pool_numbers.map do |pool_number|
        Slot.new(
          pool_number: pool_number,
          pool_rank: pool_rank,
          participation: participations_by_slot[[pool_number, pool_rank]]
        )
      end
    end
  end

  private def pool_numbers
    @pool_numbers ||= category.participations
      .where.not(pool_number: nil)
      .distinct
      .pluck(:pool_number)
      .sort
  end

  private def participations_by_slot
    @participations_by_slot ||= category.participations
      .includes(:kenshi)
      .where.not(pool_number: nil)
      .where.not(pool_rank: nil)
      .index_by { |p| [p.pool_number, p.pool_rank] }
  end
end
