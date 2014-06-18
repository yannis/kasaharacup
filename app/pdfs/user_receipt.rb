class UserReceipt < Prawn::Document
  include PosterSize
  def initialize(user)
    super(page_layout: :portrait)
    @user = user
    # inconsolata_font
    # start_new_page :layout => :landscape

    bounding_box [bounds.left + 0, bounds.top-40], :width => 700 do
      logo = "#{Rails.root}/app/assets/images/logo-128.jpg"
      image logo, :at => [0,50], :width => 100
    end

    bounding_box [bounds.left + 110, bounds.top], :width => 200 do
      font_size 24
      text "Coupe Kasahara 2013"
      font_size 14
      text "info@kendo-geneve.ch"
      text "kasaharacup.com"
    end

    bounding_box [bounds.left+400, bounds.top-150], :width => 700 do
      text "A l'intention de"
      text "#{@user.female? ? 'Mme' : 'M.'} #{@user.full_name}"
    end

    bounding_box [bounds.left+10, bounds.top-300], :width => 600 do
      text "Nous certifions avoir reçu la somme de #{@user.bill(:chf)} CHF / #{@user.bill(:eur)} EUR.".html_safe
      data = [
        [ "Nom",
          "Compétition",
          "Diner",
          "Dortoire",
          "Total"
        ]
      ]

      for enrollment in @user.enrollments
        data << [
          enrollment.last_name.titleize,
          "#{enrollment.competition_fee(:chf)} CHF / #{enrollment.competition_fee(:eur)} €",
           "#{enrollment.dinner_fee(:chf)} CHF / #{enrollment.dinner_fee(:eur)} €",
           "#{enrollment.dormitory_fee(:chf)} CHF / #{enrollment.dormitory_fee(:eur)} €",
           "<b>#{enrollment.bill(:chf)} CHF / #{enrollment.bill(:eur)} EUR</b>"
        ]
      end
      data << [nil, nil, nil, nil, "<b>#{@user.bill(:chf)} CHF / #{@user.bill(:eur)} EUR</b>"]

      table(data, :cell_style => { :inline_format => true, size: 12 }, width: 550) do
        cells.borders = []
        row(0).borders = [:bottom]
        row(0).border_width = 2
        row(0).font_style = :bold
        row(-1).borders = [:top]
        row(-1).border_width = 1
        row(-1).font_style = :bold
      end

      bounding_box [bounds.left, bounds.bottom-20], :width => 700 do
        text "Avec tous nos remerciements,"

        text "Le comité d'organisation de la coupe Kasahara"
      end
    end
  end
end
