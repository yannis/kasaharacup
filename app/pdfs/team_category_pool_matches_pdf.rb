# frozen_string_literal: true

# One printable page per pool of a team category: the pool's ties with blank
# score boxes, and a standings table to fill in by hand. The sibling of
# IndividualCategoryPoolMatchesPdf, and laid out to match it, so a desk working
# both categories reads the same sheet twice.
#
# The ties come from the pool's Encounter records rather than from
# Pools::CyclicPairing. The generator draws them from that pairing, but an admin
# can afterwards swap a tie's teams or move a team between pools, so the records
# are what the pool actually is and the formula is only where it started.
class TeamCategoryPoolMatchesPdf < Prawn::Document
  include PosterSize

  # The screen writes the conceded-points column "Pts−" with a real minus sign,
  # which Prawn's built-in font cannot draw: it is limited to Windows-1252.
  STANDINGS_HEADERS = [nil, "Rank", "W", "L", "H", "iW", "iL", "iH", "Pts+", "Pts-"].freeze

  def initialize(team_category)
    super(page_layout: :portrait)
    @team_category = team_category

    pools = team_category.team_pools
    if pools.empty?
      render_empty_state
    else
      pools.each_with_index do |pool, index|
        start_new_page layout: :portrait unless index == 0
        render_pool(pool)
      end
    end
  end

  private attr_reader :team_category

  private def render_empty_state
    text "#{team_category.name} — no pools", size: 14
  end

  private def render_pool(pool)
    render_header(pool)
    render_ties(pool)
    render_standings(pool)
  end

  private def render_header(pool)
    bounding_box [bounds.left, bounds.top + 20], width: 580 do
      fill_color "000000"
      font_size 48
      text team_category.name.upcase
      font_size 24
      text "Feuille de match"
      font_size 48
      move_down font.height
    end
    text "Pool #{pool.number}", align: :center

    cup_name_and_logo(category: team_category)

    font_size 12
  end

  private def render_ties(pool)
    bounding_box [bounds.left, bounds.top - 200], width: 580, align: :center do
      fill_color "000000"
      ties = encounters_in(pool)
      if ties.empty?
        # Better than a mysteriously blank half-page: the pool has teams but
        # nobody has generated its encounters yet.
        text "No pool encounters generated.", align: :center
      else
        draw_tie_table(tie_rows(ties))
      end
    end
  end

  private def draw_tie_table(rows)
    table(rows, cell_style: {inline_format: true, size: 12}) do
      cells.padding = 5
      cells.padding_top = 40
      cells.borders = []
      column(0).font_style = :bold
      column(0).width = 35
      column(1).width = 140
      column(2).width = 100
      column(3).width = 35
      column(4).width = 100
      column(5).width = 140

      # The two blank columns either side of the "x" are where the desk writes
      # each side's score, so only their baseline is drawn.
      column(2).borders = [:bottom]
      column(4).borders = [:bottom]
      column(2).border_width = 1
      column(4).border_width = 1

      column(1).align = :right
      column(3).align = :center

      row(0).padding = 3
      cells[0, 1].borders = [:top, :bottom, :left]
      cells[0, 2].borders = [:top, :bottom, :right]

      cells[0, 4].background_color = "ff0000"
      cells[0, 5].background_color = "ff0000"
      cells[0, 4].borders = []
      cells[0, 5].borders = []
    end
  end

  # A leading blank row carries the red marker the individual sheet uses to tell
  # the two sides of the table apart, then one row per tie. Alternating sides
  # every other row spreads each team between the left and right columns, as the
  # individual sheet does, so no team sits on one side all afternoon.
  private def tie_rows(ties)
    rows = [[nil, nil, nil, nil, nil, nil]]
    ties.each_with_index do |encounter, index|
      left, right = poster_names_of(encounter)
      left, right = right, left if index.odd?
      rows << ["#{index + 1}.", left, nil, "x", nil, right]
    end
    rows
  end

  private def poster_names_of(encounter)
    [encounter.team_1, encounter.team_2].map { |team| team&.poster_name }
  end

  private def render_standings(pool)
    bounding_box [bounds.left, bounds.top - 500], width: 580, align: :center do
      data = [STANDINGS_HEADERS.dup]
      pool.teams.each { |team| data << [team.poster_name, *Array.new(9)] }

      table(data, cell_style: {inline_format: true}) do
        cells.padding = 5
        column(0..1).font_style = :bold
        column(0).width = 130
        column(0).borders = []
        column(0).style(align: :right)

        column(1..9).width = 50
        column(1..9).style(align: :center)

        row(0).borders = []
        row(0).style(valign: :bottom)
      end
    end
  end

  # Read through the category so every pool's ties, bouts and points are loaded
  # once for the whole document instead of once per page.
  private def encounters_in(pool)
    team_category.encounters_by_pool_number.fetch(pool.number, []).sort_by(&:id)
  end
end
