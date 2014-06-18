class TeamCategoryMatchSheetPdf < Prawn::Document

  def initialize

    super(page_layout: :portrait)

    bounding_box [bounds.left, bounds.top+20], :width => 400 do
      fill_color "000000"
      font_size 48
      text "Team"
      font_size 24
      text "Feuille de match"
      font_size 48
      move_down font.height
    end
    text "Combat n°   ", align: :center

    bounding_box [bounds.right-75, bounds.top+20], :width => 300 do
      logo = "#{Rails.root}/app/assets/images/logo/logo-75.jpg"
      image logo, :at => [0,0], :width => 60
    end

    bounding_box [bounds.right-280, bounds.top+20], :width => 200 do
      font_size 24
      fill_color "3399CC"
      text "Coupe Kasahara 2013", align: :right
    end

    font_size 12

    bounding_box [bounds.left, bounds.top-200], width: 580, align: :center do
      fill_color "000000"
      data = []
      data << ["Noms des équipe    >>", nil, nil, nil]
      data << ["1. Sempo", nil, 'x', nil]
      data << ["2. Jiho", nil, 'x', nil]
      data << ["3. Chuken", nil, 'x', nil]
      data << ["4. Fukusho", nil, 'x', nil]
      data << ["5. Taisho", nil, 'x', nil]
      table(data, :cell_style => { :inline_format => true, size: 12 }) do
        cells.padding = 5
        cells.padding_top = 40
        cells.borders = []

        column(0).font_style = :bold
        column(2).align = :center

        column(0).width = 100
        column(1).width = 200
        column(2).width = 35
        column(3).width = 200

        column(1).borders = [:bottom]
        column(3).borders = [:bottom]
        column(1).border_width = 1
        column(3).border_width = 1



        row(0).padding = 3
        cells[0, 1].borders = [:top, :bottom, :left, :right]

        cells[0, 3].background_color = 'ff0000'
        cells[0, 3].borders = []
      end
    end

    bounding_box [bounds.left+150, bounds.top-550], width: 200, align: :center do
      data = []
      data << ["1.", nil]
      data << ["2.", nil]
      table(data, :cell_style => { :inline_format => true, size: 12 }) do
        cells.padding = 5
        cells.padding_top = 40
        cells.borders = []
        column(0).font_style = :bold

        column(0).width = 35
        column(1).width = 140

        column(1).borders = [:bottom]
      end
    end
  end
end
