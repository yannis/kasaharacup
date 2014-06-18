class KenshiPdf < Prawn::Document
  include PosterSize
  def initialize(kenshi)
    super(page_layout: :landscape)
    @kenshi = kenshi
    font_families.update(
    "Inconsolata" => {
        :normal => "#{Rails.root}/lib/assets/fonts/Inconsolata.ttf"
      }
    )
    font "Inconsolata"
    # start_new_page :layout => :landscape

    bounding_box [bounds.left+10, bounds.top-280], :width => 700 do
      font_size landscape_size(kenshi.poster_name)
      text kenshi.poster_name, align: :center
    end

    bounding_box [bounds.left+10, bounds.top-500], :width => 700 do
      font_size 36
      text kenshi.club.name, align: :right
    end
  end
end
