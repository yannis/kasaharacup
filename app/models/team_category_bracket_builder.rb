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

  # Wires parent_encounter_1/2 for rounds >= 2 from the seeder's tree shape.
  # BracketTree hands the internal nodes back in-order with their round already
  # assigned; grouping by round creates them column by column, so `position`
  # reads down each column and every parent exists before its child.
  #
  # A round-1 bye's occupant is deterministic and its winner never changes, so
  # seed it straight into the child slot at build time (first fill — no
  # sub-state to invalidate).
  private def create_parent_rounds(first_round)
    number = first_round.size

    BracketTree.internal_nodes(tree_shape).group_by { |node| node[:round] }.sort.each do |round, nodes|
      nodes.each_with_index do |node, index|
        number += 1
        parent_1 = BracketTree.parent_record(node[:parent_1], first_round)
        parent_2 = BracketTree.parent_record(node[:parent_2], first_round)
        node[:record] = category.encounters.create!(
          number: number,
          round: round,
          position: index + 1,
          parent_encounter_1: parent_1,
          parent_encounter_2: parent_2,
          team_1_id: (parent_1.bye_team&.id if parent_1.bye?),
          team_2_id: (parent_2.bye_team&.id if parent_2.bye?)
        )
      end
    end
  end

  private def update_existing_bracket
    category.bracket_encounters.where(round: 1)
      .includes(team_fights: :fight_points).find_each do |encounter|
      # A non-force update only fills freshly-resolved slots; it must never
      # disturb an encounter with work in progress (a hand-entered lineup,
      # scored bouts, or a recorded winner). Re-resolving such a slot would
      # invalidate that side's lineup and destroy its points. Discarding that
      # work is what the explicit "Force rebuild" path (rebuild_started) is for.
      #
      # An order the panel merely auto-seeded is not work in progress: nobody
      # chose it, and the slot it describes is about to hold another team
      # anyway. See Encounter#hand_ordered?.
      next unless encounter.pristine?

      [1, 2].each { |slot| update_team_slot(encounter, slot) }
    end
  end

  private def update_team_slot(encounter, slot)
    pool_number = encounter.public_send(:"team_#{slot}_pool_number")
    pool_rank = encounter.public_send(:"team_#{slot}_pool_rank")
    return if pool_number.blank? || pool_rank.blank?

    team = pool_slots.competitor_at(pool_number, pool_rank)
    encounter.assign_team_to_slot(slot, team)
  end

  private def seeder
    @seeder ||= if category.bracket_only?
      BracketOnlySeeder.new(category.teams.order(:id), random: random)
    else
      BracketSeeder.new(slot_specs)
    end
  end

  private def tree_shape
    seeder.tree_shape
  end

  private def first_round_pairs
    @first_round_pairs ||= if category.bracket_only?
      # Bracket-only round-1 slots carry no pool metadata; wrapping teams in
      # nil-filled Slots keeps create_first_round_encounters shared between modes.
      seeder.first_round_pairs.map { |pair|
        pair.map { |team| team && BracketSeeder::Slot.new(pool_number: nil, pool_rank: nil, payload: team) }
      }
    else
      seeder.first_round_pairs
    end
  end

  private def slot_specs
    @slot_specs ||= (1..category.out_of_pool.to_i).flat_map do |pool_rank|
      pool_numbers.map do |pool_number|
        BracketSeeder::Slot.new(
          pool_number: pool_number,
          pool_rank: pool_rank,
          payload: pool_slots.competitor_at(pool_number, pool_rank)
        )
      end
    end
  end

  # Shared with BracketWaitingEntries: one definition of "who is pool 3's
  # runner-up", or the waiting area and this re-resolve would eventually
  # disagree.
  private def pool_slots
    @pool_slots ||= CategoryPoolSlots.new(category)
  end

  private def pool_numbers = pool_slots.pool_numbers
end
