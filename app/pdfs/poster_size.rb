# frozen_string_literal: true

module PosterSize
  def landscape_size(string)
    val = 1380 / string.size
    # if val > 200
    #   val = 100
    # end
    # if val < 50
    #   val = 50
    # end
    # val
    # ssize = string.size
    # val = case
    # # when ssize > 30 then 70
    # # when ssize.between?(20, 30) then 90
    # # when ssize.between?(10, 20) then 110
    # when ssize < 10 then 140
    # # when ssize < 6 then 200
    # when ssize < 5 then 220
    # end
    val = 200 if val >= 200
    val
  end

  def inconsolata_font
    font_families.update(
      "Inconsolata" => {
        normal: Rails.root.join("/lib/assets/fonts/Inconsolata.ttf")
      }
    )
    font "Inconsolata"
  end

  def cup_name_and_logo(category: nil)
    bounding_box [bounds.right - 60, bounds.top + 20], width: 300 do
      logo = Rails.root.join("app/assets/images/logo-75.jpg")
      image logo, at: [0, 0], width: 60
    end

    bounding_box [bounds.right - 350, bounds.top + 20], width: 280 do
      font_size 18
      fill_color "C72208"
      text "Kasahara Cup #{category&.cup&.year}", align: :right
    end
  end
end
