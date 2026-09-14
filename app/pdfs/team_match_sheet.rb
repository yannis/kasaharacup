# frozen_string_literal: true

# The team "feuille de match": one tie's score sheet — a name box per side, a
# bout row per fighting position, and the result table underneath.
#
# Drawn blank for a whole category (TeamCategoryMatchSheetPdf, printed as a
# stack of spares), or with the two teams already named, one sheet per pool tie
# (TeamCategoryPoolMatchesPdf). Nothing else is ever filled in: the fighters and
# the scores are what the desk writes during the tie.
#
# A side is identified by colour, not by position: the left name box is white
# and the right one red, while the result table lists red first. Both keys off
# the colour, so the two tables stay consistent.
module TeamMatchSheet
  include PosterSize

  WHITE = "F5F3F1"
  RED = "ff0000"

  def draw_team_match_sheet(team_category, white_team: nil, red_team: nil, label: nil)
    draw_sheet_header(team_category, label)
    draw_bout_rows(team_category, white_team: white_team, red_team: red_team)
    draw_result_table(white_team: white_team, red_team: red_team)
  end

  # `label` says which sheet this is out of a printed stack — the pool it
  # belongs to and its place in that pool.
  private def draw_sheet_header(team_category, label)
    bounding_box [bounds.left, bounds.top + 20], width: 400 do
      fill_color "000000"
      font_size 48
      text "Team"
      font_size 24
      text "Feuille de match"
      font_size 48
      move_down font.height
    end
    draw_sheet_label(label) if label

    cup_name_and_logo(category: team_category)

    font_size 12
  end

  # Placed under the title rather than flowed into it: a line added to the
  # header pushes what follows down into the top border of the table below it,
  # and the sheet has no room to give.
  private def draw_sheet_label(label)
    resume_at = cursor
    bounding_box [bounds.left, bounds.top - 105], width: 400 do
      font_size(24) { text label }
    end
    move_cursor_to resume_at
  end

  private def draw_bout_rows(team_category, white_team:, red_team:)
    bounding_box [bounds.left, bounds.top - 200], width: 580, align: :center do
      fill_color "000000"
      data = [["Noms des équipe    >>", sheet_name(white_team), nil, sheet_name(red_team)]]
      (1..team_category.team_size).each do |position|
        data << [TeamPosition.label(position, team_category.team_size), nil, "x", nil]
      end
      table(data, cell_style: {inline_format: true, size: 12}) do
        cells.padding = 5
        cells.padding_top = 40
        cells.borders = []

        column(0).font_style = :bold
        column(2).align = :center

        column(0).width = 100
        column(1).width = 200
        column(2).width = 35
        column(3).width = 200

        column(1).borders = [:bottom]
        column(3).borders = [:bottom]
        column(1).border_width = 1
        column(3).border_width = 1

        row(0).padding = 3
        cells[0, 1].background_color = WHITE
        cells[0, 1].borders = [:top, :bottom, :left, :right]

        cells[0, 3].background_color = RED
        cells[0, 3].borders = []
      end
    end
  end

  # Far enough up the page for the table to fit under it whatever the sheet
  # holds: five bout rows rather than three, and team names long enough to wrap.
  RESULT_TABLE_TOP = 150

  private def draw_result_table(white_team:, red_team:)
    # Anchored, not flowed: a fixed gap under the bout rows left a five-fighter
    # sheet 89pt for a table that needs more once the names are printed in it,
    # so the last row broke onto a second page. Anchoring also lands the table
    # in the same place on a three-fighter sheet and a five-fighter one.
    move_cursor_to RESULT_TABLE_TOP

    data = [["Team", "Rank", "Wins", "Pts scored"]]
    data << [sheet_name(red_team), nil, nil, nil]
    data << [sheet_name(white_team), nil, nil, nil]

    table(data, cell_style: {inline_format: true}, position: :center) do
      cells.padding = 5
      # As wide as the name boxes above, since it holds the same two names: at
      # 140 a club name of any length wrapped onto a second line here while
      # fitting on one up there.
      column(0).width = 200
      column(0).borders = []

      column(1..3).width = 72

      column(1).font_style = :bold

      row(0).style(align: :center)
      row(0).borders = []
      row(0).style(valign: :bottom)

      row(1..2).padding = 10

      row(1).column(0).background_color = RED
      row(2).column(0).background_color = WHITE
    end
  end

  # Uppercase ASCII, as every other printed sheet spells a name: legible across
  # a desk, and safe for Prawn's built-in font, which speaks only Windows-1252.
  private def sheet_name(team)
    team&.poster_name
  end
end
