class TeamsPdf < Prawn::Document
  include PosterSize
  def initialize(teams)
    super(page_layout: :portrait)
    @teams = teams
    font_families.update(
    "Inconsolata" => {
        :normal => "#{Rails.root}/lib/assets/fonts/Inconsolata.ttf"
      }
    )
    font "Inconsolata"
    # start_new_page :layout => :landscape

    @teams.each_with_index do |team, i|
      # bounding_box [bounds.left+10, bounds.top-50], :width => 500 do
      #   unless i == 0
      #     start_new_page :layout => :portrait
      #   end
      #   font_size 72
      #   text team.poster_name, align: :center
      # end

      bounding_box [bounds.left+10, bounds.top-50], :width => 500 do
        unless i == 0
          start_new_page :layout => :portrait
        end
        font_size 72
        text team.poster_name, align: :center
        bounding_box [bounds.left, bounds.top-500], :width => 500 do
          font_size 24
          for enrollment in team.enrollments
            text "#{enrollment.full_name} (#{enrollment.club})", align: :left
          end
        end
      end

      for enrollment in team.enrollments
        start_new_page :layout => :landscape

        bounding_box [bounds.left+10, bounds.top-280], :width => 700 do
          font_size landscape_size(enrollment.poster_name)
          text enrollment.poster_name, align: :center
        end
        bounding_box [bounds.left+10, bounds.top-500], :width => 700 do
          font_size 36
          text team.poster_name, align: :right
        end
      end
    end
  end
end
