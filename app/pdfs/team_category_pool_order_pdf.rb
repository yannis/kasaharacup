# frozen_string_literal: true

# The running order of a pooled team category: one row per pool tie, in the
# order PoolEncounterOrder says they are fought. What the desk and the
# announcer read to call the next tie — the sheet a row is fought on is the one
# TeamCategoryPoolMatchesPdf prints with the same pool label and number.
class TeamCategoryPoolOrderPdf < Prawn::Document
  include PosterSize

  # The table starts below the header block above it — the title, its subtitle
  # and the cup logo, all drawn in bounding boxes that leave the cursor where
  # they found it.
  TABLE_TOP_OFFSET = 100

  def initialize(team_category)
    super(page_layout: :portrait)
    @team_category = team_category

    draw_header
    ties = PoolEncounterOrder.new(team_category).call
    if ties.empty?
      draw_empty_state
    else
      draw_order_table(ties)
    end
  end

  private attr_reader :team_category

  private def draw_header
    bounding_box [bounds.left, bounds.top + 20], width: 400 do
      font_size 48
      text team_category.name.upcase
      font_size 24
      text I18n.t("pool_fight_order.title")
    end

    cup_name_and_logo(category: team_category)

    # After the cup name, not before it: cup_name_and_logo leaves its own red
    # as the fill colour, and everything below here — the whole list — would
    # otherwise be printed in it. The match sheets re-assert black before each
    # of their tables for the same reason.
    fill_color "000000"
    font_size 12
  end

  private def draw_empty_state
    move_cursor_to bounds.top - TABLE_TOP_OFFSET
    text "#{team_category.name} — no pool encounters", size: 14
  end

  # One row per tie, in one table rather than one per pool: the order is read
  # straight down the page, and a pool boundary is not a break in it. The
  # columns add up to 522pt, just inside the 523pt the default margins leave.
  private def draw_order_table(ties)
    move_cursor_to bounds.top - TABLE_TOP_OFFSET

    data = [[I18n.t("pool_fight_order.number"), I18n.t("pool_fight_order.pool"),
      I18n.t("pool_fight_order.white"), nil, I18n.t("pool_fight_order.red")]]
    ties.each do |tie|
      data << [tie.order.to_s, tie.label,
        tie.encounter.team_1&.poster_name, "x", tie.encounter.team_2&.poster_name]
    end

    table(data, header: true, cell_style: {inline_format: true, size: 12}) do
      cells.padding = 6

      column(0).width = 30
      column(1).width = 110
      column(2).width = 180
      column(3).width = 22
      column(4).width = 180

      column(0).font_style = :bold
      column(0).align = :right
      column(2).align = :right
      column(3).align = :center

      row(0).font_style = :bold
      row(0).style(align: :center)
      # A side is identified by colour, as on the match sheet: the red column
      # is headed in red, so the two documents cannot be read against each
      # other the wrong way round.
      cells[0, 4].background_color = TeamMatchSheet::RED
      cells[0, 4].text_color = "FFFFFF"
    end
  end
end
