class TeamCategoryPdf < Prawn::Document
  include PosterSize
  def initialize(team_category)
    super(page_layout: :portrait)
    @team_category = team_category
    font_families.update(
      "Inconsolata" => {
          :normal => "#{Rails.root}/lib/assets/fonts/Inconsolata.ttf"
        }
    )
    font "Inconsolata"

    bounding_box [bounds.left+10, bounds.top-50], :width => 500 do
      font_size 72
      text @team_category.poster_name, align: :center
      bounding_box [bounds.left, bounds.top-500], :width => 500 do
        font_size 24
        for kenshi in @team_category.kenshis
          text "#{kenshi.full_name} (#{kenshi.club_name})", align: :left
        end
      end
    end


    for kenshi in @team_category.kenshis
      start_new_page :layout => :landscape

      bounding_box [bounds.left + 10, bounds.top-280], :width => 700 do
        font_size landscape_size(kenshi.poster_name)
        text kenshi.poster_name, align: :center
      end
      bounding_box [bounds.left + 10, bounds.top-500], :width => 700 do
        font_size 36
        text @team_category.poster_name, align: :right
      end
    end
  end
end



