# frozen_string_literal: true

class TeamCategoryMatchSheetPdf < Prawn::Document
  include PosterSize

  def initialize(team_category)
    super(page_layout: :portrait)

    bounding_box [bounds.left, bounds.top + 20], width: 400 do
      fill_color "000000"
      font_size 48
      text "Team"
      font_size 24
      text "Feuille de match"
      font_size 48
      move_down font.height
    end
    text "Combat n°   ", align: :center

    cup_name_and_logo(category: team_category)

    font_size 12

    bounding_box [bounds.left, bounds.top - 200], width: 580, align: :center do
      fill_color "000000"
      data = []
      data << ["Noms des équipe    >>", nil, nil, nil]
      data << ["1. Sempo", nil, "x", nil]
      data << ["2. Jiho", nil, "x", nil]
      data << ["3. Chuken", nil, "x", nil]
      data << ["4. Fukusho", nil, "x", nil]
      data << ["5. Taisho", nil, "x", nil]
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
        cells[0, 1].background_color = "F5F3F1"
        cells[0, 1].borders = [:top, :bottom, :left, :right]

        cells[0, 3].background_color = "ff0000"
        cells[0, 3].borders = []
      end
    end

    move_down 100

    data = [["Team", "Rank", "Wins", "Pts scored"]]
    2.times do |i|
      data << [nil, nil, nil, nil]
    end
    table(data, cell_style: {inline_format: true}, position: :center) do
      cells.padding = 5
      column(0).width = 140
      column(0).borders = []

      column(1..3).width = 72

      column(1).font_style = :bold

      row(0).style(align: :center)
      row(0).borders = []
      row(0).style(valign: :bottom)

      row(1..2).padding = 10

      row(1).column(0).background_color = "ff0000"
      row(2).column(0).background_color = "F5F3F1"
    end
  end
end
