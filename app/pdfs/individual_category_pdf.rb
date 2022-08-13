# frozen_string_literal: true

class IndividualCategoryPdf < Prawn::Document
  include PosterSize

  def initialize(category)
    super(page_layout: :portrait)

    font_families.update(
      "Inconsolata" => {
        normal: Rails.root.join("app/assets/fonts/Inconsolata.ttf")
      }
    )
    font "Inconsolata"
    # start_new_page layout: :landscape

    category.pools.sort_by(&:number).each_with_index do |pool, i|
      bounding_box [bounds.left + 10, bounds.top - 50], width: 500 do
        unless i == 0
          start_new_page layout: :portrait
        end
        font_size 96
        text category.name.upcase, align: :center
        font_size 72
        text "Pool #{pool.number}", align: :center
        bounding_box [bounds.left, bounds.top - 500], width: 500 do
          font_size 24
          pool.participations.map(&:kenshi).each do |kenshi|
            text "#{kenshi.full_name} (#{kenshi.club.name})", align: :center
          end
        end
      end

      pool.participations.map(&:kenshi).each do |kenshi|
        2.times do
          start_new_page layout: :landscape

          bounding_box [bounds.left + 10, bounds.top - 280], width: 700 do
            font_size landscape_size(kenshi.poster_name(category: category))
            text kenshi.poster_name(category: category), align: :center
          end
          bounding_box [bounds.left + 10, bounds.top - 500], width: 700 do
            font_size 36
            text kenshi.club.name, align: :right
          end
        end
      end
    end
  end
end
