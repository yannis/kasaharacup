# frozen_string_literal: true

require "poster_size"
class IndividualCategoryPoolMatchesPdf < Prawn::Document
  include PosterSize

  def initialize(individual_category)
    super(page_layout: :portrait)

    individual_category.pools.sort_by(&:number).each_with_index do |pool, i|
      unless i == 0
        start_new_page layout: :portrait
      end

      bounding_box [bounds.left, bounds.top + 20], width: 400 do
        fill_color "000000"
        font_size 48
        text individual_category.name.upcase
        font_size 24
        text "Feuille de match"
        font_size 48
        move_down font.height
      end
      text "Pool #{pool.number}", align: :center

      cup_name_and_logo(category: individual_category)

      font_size 12
      kenshis = Kenshi.joins(:participations).merge(pool.participations)

      bounding_box [bounds.left, bounds.top - 200], width: 580, align: :center do
        fill_color "000000"
        data = []
        kenshis = pool.participations.map(&:kenshi)
        data << [nil, nil, nil, nil, nil, nil]
        kenshis.each_with_index do |kenshi, i|
          f = kenshi
          next if kenshis.size == 2 && kenshi == kenshis.last

          o = ((kenshi == kenshis.last) ? kenshis.first : kenshis[i + 1])

          data << if i.even?
            ["#{i + 1}.", f.poster_name(category: individual_category), nil, "x", nil,
              o.poster_name(category: individual_category)]
          else
            ["#{i + 1}.", o.poster_name(category: individual_category), nil, "x", nil,
              f.poster_name(category: individual_category)]
          end
        end
        table(data, cell_style: {inline_format: true, size: 12}) do
          cells.padding = 5
          cells.padding_top = 40
          cells.borders = []
          column(0).font_style = :bold
          column(0).width = 35
          column(1).width = 140
          column(2).width = 100
          column(3).width = 35
          column(4).width = 100
          column(5).width = 140

          column(2).borders = [:bottom]
          column(4).borders = [:bottom]
          column(2).border_width = 1
          column(4).border_width = 1

          column(1).align = :right
          column(3).align = :center

          row(0).padding = 3
          cells[0, 1].borders = [:top, :bottom, :left]
          cells[0, 2].borders = [:top, :bottom, :right]

          cells[0, 4].background_color = "ff0000"
          cells[0, 5].background_color = "ff0000"
          cells[0, 4].borders = []
          cells[0, 5].borders = []
        end
      end

      bounding_box [bounds.left + 150, bounds.top - 450], width: 200, align: :center do
        data = []
        kenshis.each_with_index do |kenshi, i|
          data << ["#{i + 1}.", nil]
        end
        table(data, cell_style: {inline_format: true, size: 12}) do
          cells.padding = 5
          cells.padding_top = 40
          cells.borders = []
          column(0).font_style = :bold

          column(0).width = 35
          column(1).width = 140

          column(1).borders = [:bottom]
        end
      end
    end
  end
end
