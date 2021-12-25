# frozen_string_literal: true

class IndividualCategoryMatchSheetPdf < Prawn::Document
  def initialize(individual_category)
    super(page_layout: :portrait)

    bounding_box [bounds.left, bounds.top + 20], width: 400 do
      fill_color "000000"
      font_size 48
      text individual_category.name
      font_size 24
      text "Feuille de match"
      font_size 48
      move_down font.height
    end

    # bounding_box [bounds.right-75, bounds.top+20], width: 300 do
    #   logo = "#{Rails.root}/app/assets/images/logo/logo-75.jpg"
    #   image logo, at: [0,0], width: 60
    # end

    bounding_box [bounds.right - 280, bounds.top + 20], width: 280 do
      font_size 24
      fill_color "3399CC"
      text "#{ENV["CUP_NAME"]} #{individual_category.cup.year}", align: :right
    end

    font_size 12

    bounding_box [bounds.left, bounds.top - 100], width: 580, align: :center do
      fill_color "000000"
      data = []
      data << ["Numéro de match", nil, nil, nil, nil]
      9.times do |i|
        data << [nil, nil, nil, "x", nil]
      end
      table(data, cell_style: {inline_format: true, size: 12}) do
        cells.padding = 5
        cells.padding_top = 40
        cells.borders = []

        column(3).align = :center

        column(0).borders = [:bottom]

        column(0).width = 50
        column(1).width = 10
        column(2).width = 210
        column(3).width = 35
        column(4).width = 210

        column(2).borders = [:bottom]
        column(4).borders = [:bottom]
        column(2).border_width = 1
        column(4).border_width = 1

        row(0).padding = 3
        cells[0, 0].borders = []
        cells[0, 2].borders = [:top, :bottom, :left, :right]

        cells[0, 4].background_color = "ff0000"
        cells[0, 4].borders = []
      end
    end
  end
end
