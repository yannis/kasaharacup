# frozen_string_literal: true

class CompetitionTreeComponent < ViewComponent::Base
  include BracketLayout

  def initialize(category:, admin: false)
    @category = category
    @admin = admin
  end

  private attr_reader :category, :admin

  # A frozen bracket takes every editing affordance off the tree (R3): the
  # "Edit result" disclosure, the winner radios and the point buttons. The
  # subscription in the template keeps the bare `admin` check, or a frozen
  # category would stop hearing its own unfreeze.
  private def bracket_editable? = admin && helpers.bracket_structure_editable?(category)

  private def fights
    @fights ||= begin
      list = category.bracket_fights
        .includes(:fighter_1, :fighter_2, :winner, :fight_points)
        .bracket_order.to_a
      Fight.preload_parents(list)
      list
    end
  end

  private def bracket_nodes
    fights
  end

  private def node_parents(fight)
    [fight.parent_fight_1, fight.parent_fight_2]
  end

  private def node_has_own_identity?(fight)
    fight.fighter_1.present? || fight.fighter_2.present? ||
      (fight.round == 1 && (fight.fighter_1_pool_number.present? || fight.fighter_2_pool_number.present?))
  end

  private def display_numbers
    @display_numbers ||= BracketDisplayNumbering.for(fights)
  end

  private def display_number(fight)
    display_numbers[fight.id]
  end

  private def tree_dom_id
    helpers.dom_id(category, :competition_tree)
  end

  private def fighter_name(fight, slot)
    fighter = fight.public_send(:"resolved_fighter_#{slot}")
    return poster_name_for(fighter) if fighter.present?

    parent_fight = visible_fighter_parent(fight.public_send(:"parent_fight_#{slot}"))
    if parent_fight.present?
      return tag.em("Waiting for fight #{display_number(parent_fight)}", style: "color: #75716C;")
    end

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

  # One definition of the badge: it appears at three points in the tree (a bye,
  # round 1, and every later round) and the three copies had already drifted in
  # their indentation before they could drift in their markup.
  private def seed_badge(fight, slot)
    seed = fighter_seed(fight, slot)
    return if seed.nil?

    tag.span("S#{seed}", class: "competition-tree__seed",
      aria: {label: "Seed #{seed}"}, title: "Seed #{seed}")
  end

  # A seeded kenshi carries their number wherever they appear in the tree, not
  # only in round 1 the way the pool prefix does: the point of the badge is to
  # see at a glance how far the seeds got.
  #
  # Admin only. The seeding is the organizers' reading of the field, not a
  # result: publishing it on the public tree would tell every competitor who
  # the draw was built to protect.
  private def fighter_seed(fight, slot)
    return unless admin

    fighter = fight.public_send(:"resolved_fighter_#{slot}")
    participations_by_kenshi_id[fighter&.id]&.seed
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
    return fight if render_node?(fight)

    visible_connector_parent(fight).first if hidden_pass_through_node?(fight)
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
