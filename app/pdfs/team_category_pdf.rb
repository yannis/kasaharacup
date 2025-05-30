# frozen_string_literal: true

class TeamCategoryPdf < Prawn::Document
  include PosterSize
  def initialize(team_category)
    super(page_layout: :portrait)
    @team_category = team_category
    font_families.update(
      "Inconsolata" => {
        normal: Rails.root.join("app/assets/fonts/Inconsolata.ttf")
      }
    )
    font "Inconsolata"

    bounding_box [bounds.left + 10, bounds.top - 50], width: 500 do
      font_size 72
      text @team_category.name, align: :center
    end

    @team_category.teams.includes(kenshis: [:club, participations: :category]).order(:name).each do |team|
      start_new_page layout: :portrait

      bounding_box [bounds.left + 10, bounds.top - 50], width: 500 do
        font_size 72
        text team.name, align: :center
      end
      bounding_box [bounds.left, bounds.top - 500], width: 500 do
        font_size 24
        team.kenshis.each do |kenshi|
          text "#{kenshi.full_name} (#{kenshi.club_name})", align: :left
        end
      end

      team.kenshis.find_each do |kenshi|
        start_new_page layout: :landscape

        bounding_box [bounds.left + 10, bounds.top - 280], width: 700 do
          font_size landscape_size(kenshi.poster_name(category: team_category))
          text kenshi.poster_name(category: team_category), align: :center
        end
        bounding_box [bounds.left + 10, bounds.top - 500], width: 700 do
          font_size 36
          text team.name, align: :right
        end
      end
    end
  end
end
