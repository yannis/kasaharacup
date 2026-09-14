# frozen_string_literal: true

class TeamPdf < Prawn::Document
  include PosterSize

  def initialize(team)
    super(page_layout: :portrait)
    @team = team
    font_families.update(
      "Inconsolata" => {
        normal: Rails.root.join("app/assets/fonts/Inconsolata.ttf")
      }
    )
    font "Inconsolata"

    kenshis = team.kenshis.includes(:club).to_a
    poster_names = Kenshi.poster_names_for(kenshis, category: team.team_category)

    bounding_box [bounds.left + 10, bounds.top - 50], width: 500 do
      font_size 72
      text team.name, align: :center
    end
    bounding_box [bounds.left, bounds.top - 500], width: 500 do
      font_size 24
      kenshis.each do |kenshi|
        text "#{kenshi.full_name} (#{kenshi.club})", align: :left
      end
    end

    kenshis.each do |kenshi|
      start_new_page layout: :landscape

      bounding_box [bounds.left + 10, bounds.top - 280], width: 700 do
        font_size landscape_size(poster_names[kenshi.id])
        text poster_names[kenshi.id], align: :center
      end
      bounding_box [bounds.left + 10, bounds.top - 500], width: 700 do
        font_size 36
        text team.name, align: :right
      end
    end
  end
end
