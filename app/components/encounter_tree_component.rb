# frozen_string_literal: true

class EncounterTreeComponent < ViewComponent::Base
  include ActionView::RecordIdentifier
  include BracketLayout

  def initialize(team_category:, admin: false)
    @team_category = team_category
    @admin = admin
  end

  private attr_reader :team_category, :admin

  private def bracket_nodes
    encounters
  end

  private def node_parents(encounter)
    [encounter.parent_encounter_1, encounter.parent_encounter_2]
  end

  private def node_has_own_identity?(encounter)
    encounter.team_1.present? || encounter.team_2.present? ||
      (encounter.round == 1 &&
        (encounter.team_1_pool_number.present? || encounter.team_2_pool_number.present?))
  end

  private def encounters
    @encounters ||= begin
      list = team_category.bracket_encounters
        .includes(:team_1, :team_2, :winner, team_fights: :fight_points)
        .bracket_order.to_a
      Encounter.preload_parents(list)
      list
    end
  end

  private def display_numbers
    @display_numbers ||= BracketDisplayNumbering.for(encounters)
  end

  private def display_number(encounter)
    display_numbers[encounter.id]
  end

  private def team_name(encounter, slot)
    team = encounter.public_send(:"resolved_team_#{slot}")
    return team.name if team.present?

    parent = visible_team_parent(encounter.public_send(:"parent_encounter_#{slot}"))
    if parent.present?
      return tag.em("Waiting for encounter #{display_number(parent)}", style: "color: #75716C;")
    end

    # A seeded-but-unresolved round-1 slot shows its seed via the pool-position
    # prefix in the template; the name stays blank (mirrors CompetitionTreeComponent).
    ""
  end

  private def seed_label(encounter, slot)
    return unless encounter.round == 1

    pool_number = encounter.public_send(:"team_#{slot}_pool_number")
    pool_rank = encounter.public_send(:"team_#{slot}_pool_rank")
    return if pool_number.blank? || pool_rank.blank?

    "#{pool_number}.#{pool_rank}"
  end

  private def team_winner?(encounter, slot)
    return false if encounter.winner.blank?

    team = encounter.public_send(:"resolved_team_#{slot}")
    team.present? && team == encounter.winner
  end

  private def score_line(encounter)
    return if encounter.team_fights.empty?

    result = encounter.result
    "#{result.team_1_wins}–#{result.team_2_wins} (#{result.team_1_ippons}–#{result.team_2_ippons})"
  end

  private def visible_team_parent(encounter)
    return if encounter.blank?
    return encounter if render_node?(encounter)

    visible_connector_parent(encounter).first if hidden_pass_through_node?(encounter)
  end

  private def encounter_path(encounter)
    helpers.admin_team_category_encounter_path(team_category, encounter)
  end

  private def tree_dom_id
    helpers.dom_id(team_category, :encounter_tree)
  end

  private def panel_dom_id
    helpers.dom_id(team_category, :encounter_panel)
  end
end
