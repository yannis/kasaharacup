# frozen_string_literal: true

class CompetitionTreeComponent < ViewComponent::Base
  def initialize(category:, admin: false)
    @category = category
    @admin = admin
  end

  private attr_reader :category, :admin

  CARD_WIDTH = 224
  CARD_HEIGHT = 80
  BYE_CARD_HEIGHT = 40
  ROUND_GAP = 48
  MATCH_GAP = 8
  PADDING = 8

  private def rounds
    @rounds ||= begin
      fights = category.fights
        .includes(:fighter_1, :fighter_2, :winner, :fight_points)
        .bracket_order.to_a
      Fight.preload_parents(fights)
      fights.group_by(&:round)
    end
  end

  private def canvas_width
    return 0 if rounds.empty?

    PADDING * 2 + rounds.keys.max * CARD_WIDTH + (rounds.keys.max - 1) * ROUND_GAP
  end

  private def canvas_height
    return 0 if rounds.empty?

    PADDING * 2 + first_round_slots * (CARD_HEIGHT + MATCH_GAP) - MATCH_GAP
  end

  private def first_round_slots
    [rounds.fetch(1, []).size, 1].max
  end

  private def match_style(fight)
    "left: #{match_left(fight)}px; top: #{match_top(fight)}px;"
  end

  private def match_left(fight)
    PADDING + (fight.round - 1) * (CARD_WIDTH + ROUND_GAP)
  end

  private def match_top(fight)
    height = fight.bye? ? BYE_CARD_HEIGHT : CARD_HEIGHT
    PADDING + (fight_center_y(fight) - height / 2.0).round
  end

  private def fight_center_y(fight)
    slot_height = CARD_HEIGHT + MATCH_GAP
    span = 2**(fight.round - 1)
    first_slot = (fight.position - 1) * span

    slot_height * (first_slot + (span / 2.0)) - MATCH_GAP / 2.0
  end

  private def connector_paths
    rounds.values.flatten.filter_map do |fight|
      next unless render_fight?(fight)

      parent_paths(fight)
    end.flatten
  end

  private def parent_paths(fight)
    connector_parents(fight).map do |parent_fight|
      connector_path(parent_fight, fight)
    end
  end

  private def connector_parents(fight)
    parent_fights(fight).flat_map do |parent_fight|
      visible_connector_parent(parent_fight)
    end
  end

  private def visible_connector_parent(fight)
    return [fight] if render_fight?(fight)
    return connector_parents(fight) if hidden_pass_through_fight?(fight)

    []
  end

  private def connector_path(parent_fight, fight)
    start_x = match_left(parent_fight) + CARD_WIDTH
    start_y = PADDING + fight_center_y(parent_fight).round
    end_x = match_left(fight)
    end_y = PADDING + fight_center_y(fight).round
    elbow_x = start_x + (end_x - start_x) / 2

    "M #{start_x} #{start_y} H #{elbow_x} V #{end_y} H #{end_x}"
  end

  private def tree_dom_id
    helpers.dom_id(category, :competition_tree)
  end

  private def fighter_name(fight, slot)
    fighter = fight.public_send(:"resolved_fighter_#{slot}")
    return poster_name_for(fighter) if fighter.present?

    parent_fight = visible_fighter_parent(fight.public_send(:"parent_fight_#{slot}"))
    return tag.em("Waiting for fight #{parent_fight.number}", style: "color: #75716C;") if parent_fight.present?

    ""
  end

  private def slot_placeholder_label(fight, slot)
    pool_number = fight.public_send(:"fighter_#{slot}_pool_number")
    pool_rank = fight.public_send(:"fighter_#{slot}_pool_rank")
    return if pool_number.blank? || pool_rank.blank?

    "#{pool_number}.#{pool_rank}"
  end

  private def poster_name_for(kenshi)
    poster_names[kenshi.id] || kenshi.poster_name
  end

  private def poster_names
    @poster_names ||= Kenshi.poster_names_for(kenshis_in_tree)
  end

  private def fighter_pool_prefix(fight, slot)
    return unless fight.round == 1

    fighter = fight.public_send(:"resolved_fighter_#{slot}")
    return pool_prefix(fighter) if fighter.present?

    slot_placeholder_label(fight, slot)
  end

  private def pool_prefix(kenshi)
    participations_by_kenshi_id[kenshi&.id]&.pool_label
  end

  private def participations_by_kenshi_id
    @participations_by_kenshi_id ||= category.participations.index_by(&:kenshi_id)
  end

  private def kenshis_in_tree
    rounds.values.flatten.flat_map(&:participating_kenshis).uniq
  end

  private def fighter_winner?(fight, slot)
    return false if fight.winner.blank?

    fighter = fight.public_send(:"resolved_fighter_#{slot}")
    fighter.present? && fighter == fight.winner
  end

  private def visible_fighter_parent(fight)
    return if fight.blank?
    return fight if render_fight?(fight)

    visible_connector_parent(fight).first if hidden_pass_through_fight?(fight)
  end

  private def render_fight?(fight)
    rendered_fight_ids.fetch(fight.id) do
      rendered_fight_ids[fight.id] = fight_has_direct_fighter?(fight) ||
        fight_has_slot_identity?(fight) ||
        render_forecasted_fight?(fight)
    end
  end

  private def rendered_fight_ids
    @rendered_fight_ids ||= {}
  end

  private def fight_has_direct_fighter?(fight)
    fight.fighter_1.present? || fight.fighter_2.present?
  end

  private def fight_has_slot_identity?(fight)
    fight.round == 1 &&
      (fight.fighter_1_pool_number.present? || fight.fighter_2_pool_number.present?)
  end

  private def render_forecasted_fight?(fight)
    parent_fights(fight).any? &&
      parent_fights(fight).any? { |parent_fight| render_fight?(parent_fight) } &&
      !hidden_pass_through_fight?(fight)
  end

  private def hidden_pass_through_fight?(fight)
    pass_through_fight?(fight) && child_fights.fetch(fight.id, []).any?
  end

  private def pass_through_fight?(fight)
    parents = parent_fights(fight)
    return false unless parents.size > 1

    parents.one? { |parent_fight| render_fight?(parent_fight) } &&
      parents.any? { |parent_fight| !render_fight?(parent_fight) }
  end

  private def parent_fights(fight)
    [fight.parent_fight_1, fight.parent_fight_2].compact
  end

  private def child_fights
    @child_fights ||= rounds.values.flatten.each_with_object(Hash.new { |hash, key|
      hash[key] = []
    }) do |fight, children|
      parent_fights(fight).each do |parent_fight|
        children[parent_fight.id] << fight
      end
    end
  end

  private def points_for(fight, slot)
    fight.points_for(slot)
  end

  private def first_scoring_point_id(fight)
    @first_scoring_point_ids ||= {}
    @first_scoring_point_ids[fight.id] ||= fight.first_scoring_point&.id
  end

  private def first_scoring_point?(fight, point)
    point.id == first_scoring_point_id(fight)
  end

  private def point_kind_codes
    FightPoint::CODES
  end
end
