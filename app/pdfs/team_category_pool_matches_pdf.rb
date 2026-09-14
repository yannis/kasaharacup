# frozen_string_literal: true

# One team match sheet per pool tie, ready to hand to a court: the same sheet
# TeamCategoryMatchSheetPdf prints blank, with the two teams already named.
# Everything else stays empty — the fighters, the scores and the bout number are
# what the desk writes during the tie.
#
# The ties come from the pool's Encounter records rather than from
# Pools::CyclicPairing. The generator draws them from that pairing, but an admin
# can afterwards swap a tie's teams or move a team between pools, so the records
# are what the pool actually is and the formula is only where it started.
class TeamCategoryPoolMatchesPdf < Prawn::Document
  include TeamMatchSheet

  def initialize(team_category)
    super(page_layout: :portrait)
    @team_category = team_category

    ties = pool_ties
    if ties.empty?
      render_empty_state
    else
      ties.each_with_index do |tie, index|
        start_new_page layout: :portrait unless index == 0
        draw_team_match_sheet(team_category, white_team: tie.team_1, red_team: tie.team_2)
      end
    end
  end

  private attr_reader :team_category

  private def render_empty_state
    text "#{team_category.name} — no pool encounters", size: 14
  end

  # Pool by pool, and within a pool in the order the generator drew them. Read
  # through the category so every tie of every pool is loaded at once rather
  # than one query per pool.
  private def pool_ties
    by_pool = team_category.encounters_by_pool_number
    by_pool.keys.sort.flat_map { |number| by_pool.fetch(number).sort_by(&:id) }
  end
end
