# frozen_string_literal: true

# One team match sheet per pool tie, ready to hand to a court: the same sheet
# TeamCategoryMatchSheetPdf prints blank, with the two teams already named.
# Everything else stays empty — the fighters, the scores and the bout number
# are what the desk writes during the tie.
#
# The stack comes out in fighting order, the order PoolEncounterOrder gives
# and TeamCategoryPoolOrderPdf lists, and each sheet is labelled with its
# number in it: a sheet can be matched to a row of that list, and a dropped
# stack sorted back.
class TeamCategoryPoolMatchesPdf < Prawn::Document
  include TeamMatchSheet

  def initialize(team_category)
    super(page_layout: :portrait)
    @team_category = team_category

    ties = PoolEncounterOrder.new(team_category).call
    if ties.empty?
      render_empty_state
    else
      ties.each_with_index do |tie, index|
        start_new_page layout: :portrait unless index == 0
        draw_team_match_sheet(team_category,
          white_team: tie.encounter.team_1, red_team: tie.encounter.team_2,
          label: "#{tie.order} — #{tie.label}")
      end
    end
  end

  private attr_reader :team_category

  private def render_empty_state
    text "#{team_category.name} — no pool encounters", size: 14
  end
end
