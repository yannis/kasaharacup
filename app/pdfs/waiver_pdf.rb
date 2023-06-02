# frozen_string_literal: true

class WaiverPdf < Prawn::Document
  def initialize(cup)
    super(page_layout: :portrait)

    bounding_box [bounds.left, bounds.top + 20], width: 300 do
      logo = Rails.root.join("app/assets/images/logo-75.jpg")
      image logo, at: [0, 0], width: 60
    end

    bounding_box [bounds.left + 65, bounds.top + 20], width: 120 do
      font_size 18
      fill_color "C72208"
      text "Kasahara Cup #{cup.year}", align: :left
    end

    bounding_box [bounds.left, bounds.top - 100], width: 540 do
      fill_color "000000"
      font_size 18
      text I18n.t("waiver.title")
      move_down font.height
    end

    bounding_box [bounds.left, bounds.top - 180], width: 540 do
      font_size 14
      text(I18n.t("waiver.undersigned"), leading: 14, align: :justify)
      move_down font.height
    end

    bounding_box [bounds.left, bounds.top - 250], width: 540 do
      font_size 14
      text(I18n.t("waiver.junior"), leading: 14, align: :justify)
      move_down font.height
    end

    bounding_box [bounds.left, bounds.top - 320], width: 540 do
      font_size 14
      text(
        I18n.t(
          "waiver.body",
          start: I18n.l(cup.start_on, format: :day_only),
          end: I18n.l(cup.end_on, format: :day_month_year)
        ),
        leading: 10,
        align: :justify
      )
      move_down font.height
    end

    bounding_box [bounds.left, bounds.top - 580], width: 540 do
      font_size 14
      text(I18n.t("waiver.signature"), leading: 24, align: :justify)
      move_down font.height
    end
  end
end
