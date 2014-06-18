class KenshisPdf < Prawn::Document
  include PosterSize
  def initialize(kenshis)
    super(page_layout: :landscape)
    @kenshis = kenshis
    font_families.update(
    "Inconsolata" => {
        normal: "#{Rails.root}/lib/assets/fonts/Inconsolata.ttf"
      }
    )
    font "Inconsolata"

    @kenshis.each_with_index do |kenshi, i|

      unless i == 0
        start_new_page layout: :landscape
      end
      bounding_box [bounds.left, bounds.top-280], :width => 700 do
        font_size landscape_size(kenshi.poster_name)
        text kenshi.poster_name, align: :center
      end

      bounding_box [bounds.left+10, bounds.top-500], :width => 700 do
        font_size 36
        text kenshi.club_name, align: :right
      end
    end
  end
end
