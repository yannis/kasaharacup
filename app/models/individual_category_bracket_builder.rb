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

  # Split entries into a top and bottom half. For the i-th pool (0-based, sorted
  # by number) and a qualifier of rank r, the entry goes to the top half when
  # (i + r) is even, otherwise the bottom half. rank-1 and rank-2 differ by one
  # in parity, so they always land in opposite halves; the per-pool starting
  # side alternates, mixing winners and runners-up into both halves.
  private def assign_halves(entries)
    top = []
    bottom = []
    sorted_pools = entries.group_by(&:pool_number).sort_by { |pool_number, _| pool_number }
    sorted_pools.each_with_index do |(_pool_number, slots), pool_index|
      slots.sort_by(&:pool_rank).each do |slot|
        ((pool_index + slot.pool_rank).even? ? top : bottom) << slot
      end
    end
    [sort_by_strength(top), sort_by_strength(bottom)]
  end

  # Build the round-1 units (pairs; [slot, nil] for byes) for one half, spread
  # across that half's B/4 positions via canonical placement. half_size is an
  # even power of two (the B == 2 case returns earlier), so the post-bye `rest`
  # cross_pool_match receives is always even-sized. Slots are unique by
  # (pool_number, pool_rank), so `half_slots - byes` removes exactly the byes.
  private def build_half_units(half_slots)
    half_size = bracket_size / 2
    byes = select_byes(half_slots, half_size - half_slots.size)
    fights = cross_pool_match(sort_by_strength(half_slots - byes))
    units = byes.map { |slot| [slot, nil] } + fights
    ordered = units.sort_by { |pair| pair.compact.map { |slot| strength_key(slot) }.min }
    canonical_seed_placement(half_size / 2).map { |seed| ordered[seed - 1] }
  end

  # Byes go to the strongest entries, but each pool must keep at most
  # fighters_per_pool fighters so the rest can be matched cross-pool, so an
  # over-represented pool is forced to give up its strongest entries as byes
  # first. Never force a bye when there are none to give (byes_count <= 0) — that
  # would drop a fighter; the matcher handles same-pool pairs instead.
  private def select_byes(slots, byes_count)
    return [] if byes_count <= 0

    fighters_per_pool = (slots.size - byes_count) / 2
    byes = slots.group_by(&:pool_number).flat_map do |_pool_number, pool_slots|
      forced = pool_slots.size - fighters_per_pool
      forced.positive? ? sort_by_strength(pool_slots).first(forced) : []
    end
    return sort_by_strength(slots).first(byes_count) if byes.size > byes_count

    byes + sort_by_strength(slots - byes).first(byes_count - byes.size)
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

  private def canonical_seed_placement(size)
    return [] if size < 1

    placement = [1]
    while placement.size < size
      total = placement.size * 2
      placement = placement.flat_map { |seed| [seed, total + 1 - seed] }
    end
    placement
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
