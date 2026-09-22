# frozen_string_literal: true

class IndividualCategoryBracketBuilder
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
    seeder.first_round_pairs.map.with_index(1) do |(slot_1, slot_2), position|
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
      attrs[:fighter_1_id] = slot_1.payload&.kenshi_id if slot_1
      attrs[:fighter_2_id] = slot_2.payload&.kenshi_id if slot_2
      category.fights.create!(attrs)
    end
  end

  private def create_parent_rounds(first_round)
    pending = []
    collect_nodes(tree_shape, first_round, pending)
    number = first_round.size

    pending.group_by { |node| node[:round] }.sort.each do |round, nodes|
      nodes.each_with_index do |node, index|
        number += 1
        node[:record] = category.fights.create!(
          number: number,
          round: round,
          position: index + 1,
          fighter_type: "Kenshi",
          parent_fight_1: resolve_node(node[:parent_1]),
          parent_fight_2: resolve_node(node[:parent_2])
        )
      end
    end
  end

  private def collect_nodes(shape, leaves, out)
    return [leaves[shape], 1] if shape.is_a?(Integer)

    node = {}
    parent_1, round_1 = collect_nodes(shape.first, leaves, out)
    out << node
    parent_2, round_2 = collect_nodes(shape.last, leaves, out)
    node.merge!(parent_1: parent_1, parent_2: parent_2, round: [round_1, round_2].max + 1)
    [node, node[:round]]
  end

  private def resolve_node(node)
    node.is_a?(Hash) ? node[:record] : node
  end

  private def seeder
    @seeder ||= BracketSeeder.new(slot_specs)
  end

  private def tree_shape
    seeder.tree_shape
  end

  private def slot_specs
    @slot_specs ||= (1..category.out_of_pool.to_i).flat_map do |pool_rank|
      pool_numbers.map do |pool_number|
        BracketSeeder::Slot.new(
          pool_number: pool_number,
          pool_rank: pool_rank,
          payload: participations_by_slot[[pool_number, pool_rank]]
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
