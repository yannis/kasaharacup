# frozen_string_literal: true

class CompetitionTreePdf < Prawn::Document
  CARD_WIDTH_MIN = 80
  CARD_WIDTH_MAX = 180
  GAP_RATIO = 18.0 / 110
  CARD_HEIGHT = 43
  BYE_CARD_HEIGHT = 26
  MATCH_GAP = 5
  HEADER_HEIGHT = 28
  ROUND_LABEL_AREA = 24
  CARD_TOP_PADDING = 3
  CARD_TITLE_GAP = 3
  CARD_FIGHTER_GAP = 2
  CARD_TEXT_INDENT = 4

  FONT_DIR = Rails.root.join("vendor/fonts/inter").freeze

  def initialize(category)
    super(page_size: "A4", page_layout: :landscape, margin: 24)
    register_inter_font
    @category = category
    @fights = category.bracket_fights
      .includes(:fighter_1, :fighter_2, :winner, :fight_points)
      .bracket_order.to_a
    Fight.preload_parents(@fights)

    if @fights.empty?
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

  private attr_reader :category, :fights

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
    @total_rounds ||= fights.map(&:round).max.to_i
  end

  private def render_empty_state
    text "#{category.name} — no competition tree generated", size: 14
  end

  private def render_panel(panel, page_index, total_pages)
    render_header(panel, page_index, total_pages)
    panel[:fights_by_round].each do |round, round_fights|
      render_round(panel, round, round_fights, page_index)
    end
  end

  private def render_header(panel, page_index, total_pages)
    bounding_box [bounds.left, bounds.top], width: bounds.width, height: HEADER_HEIGHT do
      font_size 14 do
        text category.name, style: :bold
      end
      footnote = if total_pages > 1
        " — Panel #{page_index + 1} of #{total_pages} (R1 fights #{panel[:label]})"
      else
        ""
      end
      font_size 9 do
        text "Competition tree#{footnote}", color: "000000"
      end
    end
  end

  private def render_round(panel, round, round_fights, page_index)
    round_index = round - 1
    x_origin = bounds.left + round_index * (card_width + round_gap)

    if page_index.zero?
      bounding_box [x_origin, bounds.top - HEADER_HEIGHT - 6], width: card_width do
        font_size 7 do
          text "ROUND #{round}", color: "000000", style: :bold
        end
      end
    end

    round_fights.each do |fight|
      next unless fight_belongs_to_panel?(fight, panel)
      next unless fight_visible_on_panel?(fight, panel)

      draw_card(fight, x_origin, panel)
      draw_connectors(fight, x_origin, panel)
    end
  end

  private def draw_card(fight, x, panel)
    y_center = panel_card_center_y(fight, panel)
    height = fight.bye? ? BYE_CARD_HEIGHT : CARD_HEIGHT
    card_top = y_center + height / 2.0

    bounding_box [x, card_top], width: card_width, height: height do
      stroke_color "000000"
      line_width 0.75
      dash 3 if fight.bye?
      stroke_bounds
      undash

      move_down CARD_TOP_PADDING
      draw_card_text header_for(fight), size: 6, bold: false, color: "000000"
      move_down fight.bye? ? 0 : CARD_TITLE_GAP
      if fight.bye?
        draw_bye_line(fight)
      else
        draw_fighter_line(fight, 1)
        move_down CARD_FIGHTER_GAP
        draw_fighter_line(fight, 2)
      end
    end
  end

  private def draw_card_text(text, size:, bold: false, color: "000000", italic: false,
    background: nil, suffix: nil, suffix_fragments: nil)
    line_height = size + 2
    styles = []
    styles << :bold if bold
    styles << :italic if italic
    if background
      previous_fill = fill_color
      fill_color background
      fill_rectangle [0, cursor], card_width, line_height + 2
      fill_color previous_fill
    end
    font_size size do
      suffix_width = suffix.present? ? suffix_width_for(suffix, bold: bold) : 0
      reserved = suffix_width.positive? ? suffix_width + CARD_TEXT_INDENT : 0
      formatted_text_box(
        [{text: text, color: color, styles: styles}],
        at: [CARD_TEXT_INDENT, cursor],
        width: card_width - 2 * CARD_TEXT_INDENT - reserved,
        height: line_height,
        single_line: true,
        valign: :center,
        overflow: :shrink_to_fit
      )
      if suffix.present?
        fragments = suffix_fragments || [{text: suffix, color: color, styles: styles}]
        formatted_text_box(
          fragments,
          at: [card_width - CARD_TEXT_INDENT - suffix_width, cursor],
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

  private def header_for(fight)
    fight.bye? ? "Bye" : "Fight #{display_number(fight)}"
  end

  private def display_numbers
    @display_numbers ||= BracketDisplayNumbering.for(fights)
  end

  private def display_number(fight)
    display_numbers[fight.id]
  end

  # width_of measures with the current (regular) font, but the suffix may be
  # rendered bold. Pad the measured width so the rendered glyphs fit.
  private def suffix_width_for(suffix, bold:)
    raw = width_of(suffix)
    raw *= 1.15 if bold
    raw.ceil + 2
  end

  private def draw_bye_line(fight)
    slot = fight.bye_slot
    fighter = fight.bye_fighter
    label = fighter ? prefixed_name(fight, fighter) : fallback_label(fight, slot)
    draw_card_text label, size: 10, bold: fighter.present?, italic: fighter.blank?
  end

  private def draw_fighter_line(fight, slot)
    fighter = fight.public_send(:"resolved_fighter_#{slot}")
    label = (fighter && prefixed_name(fight, fighter)) || fallback_label(fight, slot)
    bold = fighter.present? && fight.winner == fighter
    italic = fighter.blank?
    points = points_for(fight, slot)
    base_styles = []
    base_styles << :bold if bold
    base_styles << :italic if italic
    suffix_fragments = build_suffix_fragments(points, base_styles: base_styles,
      underline_id: first_scoring_point(fight)&.id)
    suffix = points.any? ? points.map(&:code).join(" ") : nil
    background = (slot == 1) ? "FBA698" : nil
    draw_card_text label, size: 10, bold: bold, italic: italic, background: background,
      suffix: suffix, suffix_fragments: suffix_fragments
  end

  private def prefixed_name(fight, fighter)
    name = poster_name_for(fighter)
    prefix = pool_prefix_for(fight, fighter)
    prefix ? "#{prefix} #{name}" : name
  end

  private def pool_prefix_for(fight, fighter)
    return unless fight.round == 1
    return if fighter.blank?

    participations_by_kenshi_id[fighter.id]&.pool_label
  end

  private def participations_by_kenshi_id
    @participations_by_kenshi_id ||= category.participations.index_by(&:kenshi_id)
  end

  private def points_for(fight, slot)
    fight.points_for(slot)
  end

  private def first_scoring_point(fight)
    @first_scoring_points ||= {}
    @first_scoring_points[fight.id] ||= fight.first_scoring_point
  end

  private def build_suffix_fragments(points, base_styles:, underline_id:)
    return nil if points.empty?

    fragments = []
    points.each_with_index do |point, index|
      fragments << {text: " ", styles: base_styles} if index.positive?
      point_styles = base_styles.dup
      point_styles << :underline if underline_id && point.id == underline_id
      fragments << {text: point.code, styles: point_styles}
    end
    fragments
  end

  private def poster_name_for(kenshi)
    poster_names[kenshi.id] || kenshi.poster_name
  end

  private def poster_names
    @poster_names ||= Kenshi.poster_names_for(kenshis_in_tree)
  end

  private def kenshis_in_tree
    fights.flat_map(&:participating_kenshis).uniq
  end

  private def fallback_label(fight, slot)
    parent_fight = fight.public_send(:"parent_fight_#{slot}")
    return "Waiting for fight #{display_number(parent_fight)}" if parent_fight.present?

    pool_number = fight.public_send(:"fighter_#{slot}_pool_number")
    pool_rank = fight.public_send(:"fighter_#{slot}_pool_rank")
    return "#{pool_number}.#{pool_rank}" if pool_number.present? && pool_rank.present?

    ""
  end

  private def draw_connectors(fight, x, panel)
    [fight.parent_fight_1, fight.parent_fight_2].compact.each do |parent_fight|
      draw_connector(parent_fight, fight, panel)
    end
    children_of(fight).each do |child|
      next if same_panel?(fight, child, panel)
      draw_connector(fight, child, panel)
    end
  end

  private def children_of(fight)
    children_by_parent_id[fight.id] || []
  end

  private def children_by_parent_id
    @children_by_parent_id ||= fights.each_with_object({}) do |f, hash|
      [f.parent_fight_1_id, f.parent_fight_2_id].compact.each do |parent_id|
        (hash[parent_id] ||= []) << f
      end
    end
  end

  private def draw_connector(parent_fight, fight, panel)
    parent_x = bounds.left + (parent_fight.round - 1) * (card_width + round_gap) + card_width
    parent_y = panel_card_center_y(parent_fight, panel)
    child_x = bounds.left + (fight.round - 1) * (card_width + round_gap)
    child_y = panel_card_center_y(fight, panel)
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

  private def panel_card_center_y(fight, panel)
    span = 2**(fight.round - 1)
    first_slot_index = (fight.position - 1) * span - panel[:slot_offset]
    slot_pitch = CARD_HEIGHT + MATCH_GAP
    middle_offset = (span - 1) / 2.0
    canvas_top - HEADER_HEIGHT - ROUND_LABEL_AREA - slot_pitch * (first_slot_index + middle_offset) - CARD_HEIGHT / 2.0
  end

  private def canvas_top
    bounds.top
  end

  private def fight_belongs_to_panel?(fight, panel)
    leaves_under_fight(fight).any? { |position| panel[:r1_positions].include?(position) }
  end

  private def fight_visible_on_panel?(fight, panel)
    span = 2**(fight.round - 1)
    first_slot_index = (fight.position - 1) * span - panel[:slot_offset]
    middle_offset = (span - 1) / 2.0
    combined = first_slot_index + middle_offset
    combined >= 0 && combined < max_rows_per_page
  end

  private def same_panel?(parent_fight, fight, panel)
    fight_visible_on_panel?(parent_fight, panel) && fight_visible_on_panel?(fight, panel)
  end

  private def leaves_under_fight(fight)
    span = 2**(fight.round - 1)
    first = (fight.position - 1) * span + 1
    (first...(first + span)).to_a
  end

  private def paginate_panels
    r1_count = fights_by_round[1]&.size.to_i
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
    panel_fights = fights.select { |fight|
      leaves_under_fight(fight).any? { |position| r1_positions.include?(position) }
    }
    label = (r1_positions.size == 1) ? r1_positions.first.to_s : "#{r1_positions.first}-#{r1_positions.last}"
    {
      r1_positions: r1_positions,
      slot_offset: slot_offset,
      label: label,
      fights_by_round: panel_fights.group_by(&:round).sort.to_h
    }
  end

  private def fights_by_round
    @fights_by_round ||= fights.group_by(&:round)
  end

  private def max_rows_per_page
    available = bounds.height - HEADER_HEIGHT - ROUND_LABEL_AREA
    [(available / (CARD_HEIGHT + MATCH_GAP)).floor, 1].max
  end
end
