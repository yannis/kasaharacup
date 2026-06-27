# frozen_string_literal: true

# The team-category counterpart of CompetitionTreePdf: a printable single
# -elimination bracket. Each card is an Encounter (a team-vs-team tie) instead
# of an individual Fight, so the per-fighter point codes become each side's
# bout-win tally; everything else — pagination, connectors, the calling number
# badge — mirrors the individual tree so both PDFs read identically.
class TeamCategoryBracketPdf < Prawn::Document
  CARD_WIDTH_MIN = 80
  CARD_WIDTH_MAX = 180
  GAP_RATIO = 18.0 / 110
  FIGHTER_LINE_HEIGHT = 12
  CARD_HEIGHT = 30
  BYE_CARD_HEIGHT = 18
  MATCH_GAP = 5
  HEADER_HEIGHT = 28
  ROUND_LABEL_AREA = 24
  CARD_FIGHTER_GAP = 2
  CARD_TEXT_INDENT = 4
  NUMBER_BADGE_WIDTH = 22
  NUMBER_BADGE_SIZE = 16
  NUMBER_BADGE_COLOR = "C0392B"

  FONT_DIR = Rails.root.join("vendor/fonts/inter").freeze

  def initialize(team_category)
    super(page_size: "A4", page_layout: :landscape, margin: 24)
    register_inter_font
    @team_category = team_category
    @encounters = team_category.bracket_encounters
      .includes(:team_1, :team_2, :winner, team_fights: :fight_points)
      .bracket_order.to_a
    Encounter.preload_parents(@encounters)

    if @encounters.empty?
      render_empty_state
    else
      panels = paginate_panels
      panels.each_with_index do |panel, page_index|
        start_new_page layout: :landscape if page_index.positive?
        render_panel(panel, page_index, panels.size)
      end
    end
  end

  # Inter renders the on-screen hansoku glyph (△) and other Unicode that
  # Prawn's built-in Helvetica cannot, which is limited to Windows-1252.
  private def register_inter_font
    font_families.update(
      "Inter" => {
        normal: FONT_DIR.join("Inter-Regular.ttf").to_s,
        bold: FONT_DIR.join("Inter-Bold.ttf").to_s,
        italic: FONT_DIR.join("Inter-Italic.ttf").to_s
      }
    )
    font "Inter"
  end

  private attr_reader :team_category, :encounters

  private def card_width
    @card_width ||= begin
      return CARD_WIDTH_MAX.to_f if total_rounds <= 0

      total_units = total_rounds + (total_rounds - 1) * GAP_RATIO
      raw = bounds.width / total_units
      raw.clamp(CARD_WIDTH_MIN.to_f, CARD_WIDTH_MAX.to_f)
    end
  end

  private def round_gap
    return 0.0 if total_rounds <= 1

    remaining = bounds.width - total_rounds * card_width
    [remaining / (total_rounds - 1), card_width * GAP_RATIO].max
  end

  private def total_rounds
    @total_rounds ||= encounters.map(&:round).max.to_i
  end

  private def render_empty_state
    text "#{team_category.name} — no bracket generated", size: 14
  end

  private def render_panel(panel, page_index, total_pages)
    render_header(panel, page_index, total_pages)
    panel[:encounters_by_round].each do |round, round_encounters|
      render_round(panel, round, round_encounters, page_index)
    end
  end

  private def render_header(panel, page_index, total_pages)
    bounding_box [bounds.left, bounds.top], width: bounds.width, height: HEADER_HEIGHT do
      font_size 14 do
        text team_category.name, style: :bold
      end
      footnote = if total_pages > 1
        " — Panel #{page_index + 1} of #{total_pages} (R1 encounters #{panel[:label]})"
      else
        ""
      end
      font_size 9 do
        text "Bracket#{footnote}", color: "000000"
      end
    end
  end

  private def render_round(panel, round, round_encounters, page_index)
    round_index = round - 1
    x_origin = bounds.left + round_index * (card_width + round_gap)

    if page_index.zero?
      bounding_box [x_origin, bounds.top - HEADER_HEIGHT - 6], width: card_width do
        font_size 7 do
          text "ROUND #{round}", color: "000000", style: :bold
        end
      end
    end

    round_encounters.each do |encounter|
      next unless encounter_belongs_to_panel?(encounter, panel)
      next unless encounter_visible_on_panel?(encounter, panel)

      draw_card(encounter, x_origin, panel)
      draw_connectors(encounter, x_origin, panel)
    end
  end

  private def draw_card(encounter, x, panel)
    y_center = panel_card_center_y(encounter, panel)
    height = encounter.bye? ? BYE_CARD_HEIGHT : CARD_HEIGHT
    card_top = y_center + height / 2.0

    bounding_box [x, card_top], width: card_width, height: height do
      stroke_color "000000"
      line_width 0.75
      dash 3 if encounter.bye?
      stroke_bounds
      undash

      if encounter.bye?
        # No "Bye" label or number — the dashed border already marks a bye.
        move_down vertical_centering(height, rows: 1)
        draw_bye_line(encounter)
      else
        draw_number_badge(encounter, height)
        draw_match_teams(encounter, height)
      end
    end
  end

  # Top offset that vertically centers `rows` team lines within the card.
  private def vertical_centering(height, rows:)
    block = rows * FIGHTER_LINE_HEIGHT + (rows - 1) * CARD_FIGHTER_GAP
    [(height - block) / 2.0, 0].max
  end

  # The encounter's display number, rendered large and bold in a column down the
  # left edge so it stands out on a printed sheet for calling matches.
  private def draw_number_badge(encounter, height)
    number = display_number(encounter)
    return if number.nil?

    stroke_color "CCCCCC"
    line_width 0.5
    stroke do
      move_to NUMBER_BADGE_WIDTH, 0
      line_to NUMBER_BADGE_WIDTH, height
    end
    formatted_text_box(
      [{text: number.to_s, color: NUMBER_BADGE_COLOR, styles: [:bold], size: NUMBER_BADGE_SIZE}],
      at: [0, height],
      width: NUMBER_BADGE_WIDTH,
      height: height,
      align: :center,
      valign: :center,
      overflow: :shrink_to_fit
    )
  end

  # Top-aligned so the first team's highlight sits flush against the top of the
  # card; the spare space falls below the second name instead.
  private def draw_match_teams(encounter, height)
    content_width = card_width - NUMBER_BADGE_WIDTH
    draw_team_line(encounter, 1, left: NUMBER_BADGE_WIDTH, width: content_width)
    move_down CARD_FIGHTER_GAP
    draw_team_line(encounter, 2, left: NUMBER_BADGE_WIDTH, width: content_width)
  end

  private def draw_card_text(text, size:, left: 0, width: card_width, bold: false, color: "000000",
    italic: false, background: nil, suffix: nil)
    line_height = size + 2
    styles = []
    styles << :bold if bold
    styles << :italic if italic
    if background
      previous_fill = fill_color
      fill_color background
      fill_rectangle [left, cursor], width, line_height + 2
      fill_color previous_fill
    end
    font_size size do
      suffix_width = suffix.present? ? suffix_width_for(suffix, bold: bold) : 0
      reserved = suffix_width.positive? ? suffix_width + CARD_TEXT_INDENT : 0
      formatted_text_box(
        [{text: text, color: color, styles: styles}],
        at: [left + CARD_TEXT_INDENT, cursor],
        width: width - 2 * CARD_TEXT_INDENT - reserved,
        height: line_height,
        single_line: true,
        valign: :center,
        overflow: :shrink_to_fit
      )
      if suffix.present?
        formatted_text_box(
          [{text: suffix, color: color, styles: styles}],
          at: [left + width - CARD_TEXT_INDENT - suffix_width, cursor],
          width: suffix_width,
          height: line_height,
          single_line: true,
          valign: :center,
          overflow: :shrink_to_fit
        )
      end
    end
    move_down line_height
  end

  private def display_numbers
    @display_numbers ||= BracketDisplayNumbering.for(encounters)
  end

  private def display_number(encounter)
    display_numbers[encounter.id]
  end

  # width_of measures with the current (regular) font, but the suffix may be
  # rendered bold. Pad the measured width so the rendered glyphs fit.
  private def suffix_width_for(suffix, bold:)
    raw = width_of(suffix)
    raw *= 1.15 if bold
    raw.ceil + 2
  end

  private def draw_bye_line(encounter)
    slot = encounter.bye_slot
    team = encounter.bye_team
    label = team ? prefixed_name(encounter, slot, team) : fallback_label(encounter, slot)
    draw_card_text label, size: 10, bold: team.present?, italic: team.blank?
  end

  private def draw_team_line(encounter, slot, left: 0, width: card_width)
    team = encounter.public_send(:"resolved_team_#{slot}")
    label = (team && prefixed_name(encounter, slot, team)) || fallback_label(encounter, slot)
    bold = team.present? && encounter.winner == team
    italic = team.blank?
    background = (slot == 1) ? "FBA698" : nil
    draw_card_text label, size: 10, left: left, width: width, bold: bold, italic: italic,
      background: background, suffix: score_suffix(encounter, slot)
  end

  private def prefixed_name(encounter, slot, team)
    prefix = seed_label(encounter, slot)
    prefix ? "#{prefix} #{team.name}" : team.name
  end

  private def seed_label(encounter, slot)
    return unless encounter.round == 1

    pool_number = encounter.public_send(:"team_#{slot}_pool_number")
    pool_rank = encounter.public_send(:"team_#{slot}_pool_rank")
    return if pool_number.blank? || pool_rank.blank?

    "#{pool_number}.#{pool_rank}"
  end

  # Each side's bout-win tally, shown only once the tie has fights — mirrors the
  # on-screen score line, but split per row like the individual PDF's points.
  private def score_suffix(encounter, slot)
    return if encounter.team_fights.empty?

    result = result_for(encounter)
    (slot == 1) ? result.team_1_wins.to_s : result.team_2_wins.to_s
  end

  private def result_for(encounter)
    @results ||= {}
    @results[encounter.id] ||= encounter.result
  end

  private def fallback_label(encounter, slot)
    parent_encounter = encounter.public_send(:"parent_encounter_#{slot}")
    return "Waiting for encounter #{display_number(parent_encounter)}" if parent_encounter.present?

    seed_label(encounter, slot) || ""
  end

  private def draw_connectors(encounter, x, panel)
    [encounter.parent_encounter_1, encounter.parent_encounter_2].compact.each do |parent_encounter|
      draw_connector(parent_encounter, encounter, panel)
    end
    children_of(encounter).each do |child|
      next if same_panel?(encounter, child, panel)
      draw_connector(encounter, child, panel)
    end
  end

  private def children_of(encounter)
    children_by_parent_id[encounter.id] || []
  end

  private def children_by_parent_id
    @children_by_parent_id ||= encounters.each_with_object({}) do |e, hash|
      [e.parent_encounter_1_id, e.parent_encounter_2_id].compact.each do |parent_id|
        (hash[parent_id] ||= []) << e
      end
    end
  end

  private def draw_connector(parent_encounter, encounter, panel)
    parent_x = bounds.left + (parent_encounter.round - 1) * (card_width + round_gap) + card_width
    parent_y = panel_card_center_y(parent_encounter, panel)
    child_x = bounds.left + (encounter.round - 1) * (card_width + round_gap)
    child_y = panel_card_center_y(encounter, panel)
    elbow = parent_x + (child_x - parent_x) / 2.0

    stroke_color "000000"
    line_width 0.75
    stroke do
      move_to parent_x, parent_y
      line_to elbow, parent_y
      line_to elbow, child_y
      line_to child_x, child_y
    end
  end

  private def panel_card_center_y(encounter, panel)
    span = 2**(encounter.round - 1)
    first_slot_index = (encounter.position - 1) * span - panel[:slot_offset]
    slot_pitch = CARD_HEIGHT + MATCH_GAP
    middle_offset = (span - 1) / 2.0
    canvas_top - HEADER_HEIGHT - ROUND_LABEL_AREA - slot_pitch * (first_slot_index + middle_offset) - CARD_HEIGHT / 2.0
  end

  private def canvas_top
    bounds.top
  end

  private def encounter_belongs_to_panel?(encounter, panel)
    leaves_under(encounter).any? { |position| panel[:r1_positions].include?(position) }
  end

  private def encounter_visible_on_panel?(encounter, panel)
    span = 2**(encounter.round - 1)
    first_slot_index = (encounter.position - 1) * span - panel[:slot_offset]
    middle_offset = (span - 1) / 2.0
    combined = first_slot_index + middle_offset
    combined >= 0 && combined < max_rows_per_page
  end

  private def same_panel?(parent_encounter, encounter, panel)
    encounter_visible_on_panel?(parent_encounter, panel) && encounter_visible_on_panel?(encounter, panel)
  end

  private def leaves_under(encounter)
    span = 2**(encounter.round - 1)
    first = (encounter.position - 1) * span + 1
    (first...(first + span)).to_a
  end

  private def paginate_panels
    r1_count = encounters_by_round[1]&.size.to_i
    return [build_panel((1..r1_count).to_a)] if r1_count.zero?

    rows_per_page = max_rows_per_page
    return [build_panel((1..r1_count).to_a)] if r1_count <= rows_per_page

    panels = []
    (1..r1_count).each_slice(rows_per_page) do |slice|
      panels << build_panel(slice)
    end
    panels
  end

  private def build_panel(r1_positions)
    slot_offset = r1_positions.first - 1
    panel_encounters = encounters.select { |encounter|
      leaves_under(encounter).any? { |position| r1_positions.include?(position) }
    }
    label = (r1_positions.size == 1) ? r1_positions.first.to_s : "#{r1_positions.first}-#{r1_positions.last}"
    {
      r1_positions: r1_positions,
      slot_offset: slot_offset,
      label: label,
      encounters_by_round: panel_encounters.group_by(&:round).sort.to_h
    }
  end

  private def encounters_by_round
    @encounters_by_round ||= encounters.group_by(&:round)
  end

  private def max_rows_per_page
    available = bounds.height - HEADER_HEIGHT - ROUND_LABEL_AREA
    [(available / (CARD_HEIGHT + MATCH_GAP)).floor, 1].max
  end
end
