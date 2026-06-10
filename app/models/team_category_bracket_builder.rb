# frozen_string_literal: true

# Builds a single-elimination bracket of Encounters for a TeamCategory. Pooled
# categories seed from pool standings (teams.pool_number / pool_rank via
# BracketSeeder); bracket-only categories (TeamCategory#bracket_only?) draw
# directly from teams via BracketOnlySeeder, fully resolved at creation with
# no pool metadata. Mirrors IndividualCategoryBracketBuilder but operates on
# Teams/Encounters, and FORWARD-PROPAGATES resolved teams into child slots
# (see Encounter#assign_team_to_slot) rather than resolving lazily on read.
class TeamCategoryBracketBuilder
  def initialize(category, rebuild_started: false, random: Random.new)
    @category = category
    @rebuild_started = rebuild_started
    @random = random
  end

  def call
    return [] if first_round_pairs.empty?

    category.transaction do
      if category.bracket_encounters.empty?
        create_new_bracket
      elsif rebuild_started
        # Higher rounds hold FKs to their parents; destroy children first.
        category.bracket_encounters.order(round: :desc).destroy_all
        create_new_bracket
      else
        update_existing_bracket
      end
    end
    category.bracket_encounters.bracket_order.to_a
  end

  private attr_reader :category, :rebuild_started, :random

  private def create_new_bracket
    first_round = create_first_round_encounters
    create_parent_rounds(first_round)
  end

  private def create_first_round_encounters
    first_round_pairs.map.with_index(1) do |(slot_1, slot_2), position|
      attrs = {
        number: position,
        round: 1,
        position: position,
        team_1_pool_number: slot_1&.pool_number,
        team_1_pool_rank: slot_1&.pool_rank,
        team_2_pool_number: slot_2&.pool_number,
        team_2_pool_rank: slot_2&.pool_rank
      }
      attrs[:team_1_id] = slot_1.payload&.id if slot_1
      attrs[:team_2_id] = slot_2.payload&.id if slot_2
      category.encounters.create!(attrs)
    end
  end

  # Wires parent_encounter_1/2 for rounds >= 2. A round-1 bye's occupant is
  # deterministic and its winner never changes, so seed it straight into the
  # child slot at build time (first fill — no sub-state to invalidate).
  private def create_parent_rounds(child_encounters)
    encounters = child_encounters
    round = 2
    number = child_encounters.size

    while encounters.size > 1
      encounters = encounters.each_slice(2).map.with_index(1) do |(parent_1, parent_2), position|
        number += 1
        category.encounters.create!(
          number: number,
          round: round,
          position: position,
          parent_encounter_1: parent_1,
          parent_encounter_2: parent_2,
          team_1_id: (parent_1.bye_team&.id if parent_1&.bye?),
          team_2_id: (parent_2.bye_team&.id if parent_2&.bye?)
        )
      end
      round += 1
    end
  end

  private def update_existing_bracket
    category.bracket_encounters.where(round: 1).find_each do |encounter|
      [1, 2].each { |slot| update_team_slot(encounter, slot) }
    end
  end

  private def update_team_slot(encounter, slot)
    return if encounter.winner.present?

    pool_number = encounter.public_send(:"team_#{slot}_pool_number")
    pool_rank = encounter.public_send(:"team_#{slot}_pool_rank")
    return if pool_number.blank? || pool_rank.blank?

    team = teams_by_slot[[pool_number, pool_rank]]
    encounter.assign_team_to_slot(slot, team)
  end

  private def first_round_pairs
    @first_round_pairs ||= if category.bracket_only?
      bracket_only_pairs
    else
      BracketSeeder.new(slot_specs).first_round_pairs
    end
  end

  # Bracket-only round-1 slots carry no pool metadata; wrapping teams in
  # nil-filled Slots keeps create_first_round_encounters shared between modes.
  private def bracket_only_pairs
    BracketOnlySeeder.new(category.teams.order(:id), random: random).first_round_pairs.map do |pair|
      pair.map { |team| team && BracketSeeder::Slot.new(pool_number: nil, pool_rank: nil, payload: team) }
    end
  end

  private def slot_specs
    @slot_specs ||= (1..category.out_of_pool.to_i).flat_map do |pool_rank|
      pool_numbers.map do |pool_number|
        BracketSeeder::Slot.new(
          pool_number: pool_number,
          pool_rank: pool_rank,
          payload: teams_by_slot[[pool_number, pool_rank]]
        )
      end
    end
  end

  private def pool_numbers
    @pool_numbers ||= category.teams
      .where.not(pool_number: nil)
      .distinct
      .pluck(:pool_number)
      .sort
  end

  private def teams_by_slot
    @teams_by_slot ||= category.teams
      .where.not(pool_number: nil)
      .where.not(pool_rank: nil)
      .index_by { |team| [team.pool_number, team.pool_rank] }
  end
end
