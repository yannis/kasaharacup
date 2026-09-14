# frozen_string_literal: true

# One blank team match sheet for a category — a stack of spares for the desk.
# TeamCategoryPoolMatchesPdf prints the same sheet with the two teams already
# named, one per pool tie.
class TeamCategoryMatchSheetPdf < Prawn::Document
  include TeamMatchSheet

  def initialize(team_category)
    super(page_layout: :portrait)
    draw_team_match_sheet(team_category)
  end
end
