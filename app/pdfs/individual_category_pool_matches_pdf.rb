# frozen_string_literal: true

# One match sheet per pool: the pool's fights in the order they are fought,
# white on the left and red on the right, then a blank standings table.
#
# The fights are the pool's Fight records, not Pools::CyclicPairing's formula:
# the admin pool card lists the same records by number, so the sheet and the
# card agree on the order and on who is red — fighter_1 (Pools::FightOrder).
# A kettei-sen is added during the pool, so it is written on by hand.
class IndividualCategoryPoolMatchesPdf < Prawn::Document
  include PosterSize

  def initialize(individual_category)
    super(page_layout: :portrait)

    pools = individual_category.pools.sort_by(&:number)
    # Namesakes are told apart within the category, as everywhere else a category
    # is printed. The standings table below used to scope that to the whole cup,
    # so a fighter with a namesake in another category was initialled there and
    # not in the match grid — two spellings of one name on one sheet.
    poster_names = individual_category.pool_poster_names

    pools.each_with_index do |pool, i|
      unless i == 0
        start_new_page layout: :portrait
      end

      bounding_box [bounds.left, bounds.top + 20], width: 580 do
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

      bounding_box [bounds.left, bounds.top - 200], width: 580, align: :center do
        fill_color "000000"
        data = []
        data << [nil, nil, nil, nil, nil, nil]
        individual_category.pool_fights_by_number.fetch(pool.number, [])
          .reject(&:tiebreaker).sort_by(&:number).each do |fight|
          white, red = poster_names[fight.fighter_2_id], poster_names[fight.fighter_1_id]
          data << ["#{fight.number}.", white, nil, "x", nil, red]
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

      bounding_box [bounds.left, bounds.top - 500], width: 580, align: :center do
        data = [[nil, "Rank", "Wins", "Losses", "Hikiwake", "Pts scored", "Pts conceded"]]
        pool.participations.map(&:kenshi).each do |kenshi|
          data << [poster_names[kenshi.id], nil, nil, nil, nil, nil, nil]
        end
        table(data, cell_style: {inline_format: true}) do
          cells.padding = 5
          # cells.borders = [1, 1, 1, 1]
          column(0..1).font_style = :bold
          column(0).width = 140
          column(0).borders = []
          column(0).style(align: :right)

          column(1..6).width = 62
          column(1..6).style(align: :center)

          row(0).borders = []
          row(0).style(valign: :bottom)
        end
      end
    end
  end
end
