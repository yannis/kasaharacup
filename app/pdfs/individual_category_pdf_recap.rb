# frozen_string_literal: true

class IndividualCategoryPdfRecap < Prawn::Document
  include PosterSize

  def initialize(individual_category)
    super(page_layout: :portrait)
    repeat :all, dynamic: true do
      bounding_box [bounds.left, bounds.top + 20], width: 400 do
        fill_color "000000"
        font_size 48
        text individual_category.name.upcase
      end

      cup_name_and_logo(category: individual_category)
    end

    individual_category.pools.sort_by(&:number).each_with_index do |pool, i|
      font_size 12
      move_down(-3)
      if i % 7 == 0
        start_new_page unless i == 0
        move_down 40
      end
      move_down 15
      bounding_box [bounds.left, cursor - 10], width: 600 do
        top = cursor
        bounding_box [bounds.left, cursor], width: 70 do
          font_size 18
          text "Pool #{pool.number}", align: :right
        end
        bounding_box [bounds.left + 80, top + 20], width: 450 do
          data = []
          pool.participations.map(&:kenshi).each_with_index do |kenshi, i|
            data << [i + 1, "#{kenshi.poster_name(category: individual_category)} (#{kenshi.club})"]
          end
          table(data, cell_style: {inline_format: true, size: 12}, width: 450) do
            column(0).width = 30
          end
        end
      end
    end
  end
end
