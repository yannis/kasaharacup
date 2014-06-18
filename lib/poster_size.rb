module PosterSize
  def landscape_size(string)
    val = 1400/string.size
    Rails.logger.info "val: #{val}, string: #{string}"
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
        :normal => "#{Rails.root}/lib/assets/fonts/Inconsolata.ttf"
      }
    )
    font "Inconsolata"
  end
end
