# frozen_string_literal: true

require "rails_helper"

RSpec.describe CompetitionTreeComponent, type: :component do
  let(:category) { create(:individual_category) }
  let(:fight) { create(:fight, individual_category: category) }
  let!(:final) do
    create(:fight,
      individual_category: category,
      round: 2,
      position: 1,
      number: 2,
      fighter_1: nil,
      fighter_2: nil,
      parent_fight_1: fight,
      fighter_type: "Kenshi")
  end

  before do
    fight.update!(winner: fight.fighter_1)
  end

  it "renders a bye fight in a simplified, non-editable card" do
    local_category, bye_kenshi = build_bye_bracket

    render_inline(described_class.new(category: local_category.reload, admin: true))

    bye_card = page.find(".competition-tree__match", text: "Fight 1")
    expect(bye_card[:class]).to include("competition-tree__match--bye")
    expect(bye_card).to have_text(bye_kenshi.poster_name)
    expect(bye_card).not_to have_text("Bye", exact: true) unless bye_card.has_css?(".competition-tree__bye-label")
    expect(bye_card).not_to have_css(".competition-tree__admin-details")
    expect(bye_card).not_to have_button("Save", visible: :all)
  end

  it "advances a bye fighter to the immediate next round but no further" do
    local_category, bye_kenshi = build_bye_bracket(extra_round: true)

    render_inline(described_class.new(category: local_category.reload))

    round_two = page.find(".competition-tree__match", text: "Fight 3")
    expect(round_two).to have_text(bye_kenshi.poster_name)

    round_three = page.find(".competition-tree__match", text: "Fight 5")
    expect(round_three).to have_text("Waiting for fight 3")
    expect(round_three).not_to have_text(bye_kenshi.poster_name)
  end

  it "renders waiting, active, winner, and bye states" do
    render_inline(described_class.new(category: category))

    expect(page).not_to have_css("turbo-cable-stream-source")
    expect(page).to have_css("turbo-frame#competition_tree_individual_category_#{category.id}")
    expect(page).to have_css(".competition-tree__round")
    expect(page).to have_css(".competition-tree__match")
    expect(page).to have_css(".competition-tree__svg")
    expect(page).to have_css(".competition-tree__line")
    expect(page).to have_css(".competition-tree__match[style*='left:']")
    expect(page).to have_css(".competition-tree__match[style*='top:']")
    expect(page).to have_css(".competition-tree__viewport[style*='height: 96px']")
    expect(page).to have_text("Round 1")
    expect(page).to have_text(fight.fighter_1.poster_name)
    expect(page).to have_css(".competition-tree__fighter--winner", text: fight.fighter_1.poster_name)
    expect(page).not_to have_text("Winner:")
    expect(page).not_to have_text("Waiting for fight 1")
    expect(page).to have_text("Fight 2")
    expect(final.parent_fight_1).to eq fight
  end

  it "renders an expandable admin editor for fights with at least one fighter" do
    pending_fight = create(:fight, individual_category: category, round: 3, position: 1, number: 3)

    render_inline(described_class.new(category: category.reload, admin: true))

    expect(page).to have_css(".competition-tree__admin-details > .competition-tree__match-header")
    expect(page).to have_css(".competition-tree__admin-summary", text: "Edit result")
    expect(pending_fight.winner).to be_nil
  end

  it "subscribes admin views to the live broadcast stream" do
    render_inline(described_class.new(category: category.reload, admin: true))

    expect(page).to have_css("turbo-cable-stream-source")
  end

  it "does not subscribe public views to the live broadcast stream" do
    render_inline(described_class.new(category: category.reload))

    expect(page).not_to have_css("turbo-cable-stream-source")
  end

  it "renders admin winner controls for completed fights" do
    render_inline(described_class.new(category: category.reload, admin: true))

    completed_match = page.find(".competition-tree__match", text: "Fight 1")
    expect(completed_match).to have_css(".competition-tree__admin-details > .competition-tree__match-header")
    expect(completed_match).to have_css(".competition-tree__admin-summary", text: "Edit result")
  end

  it "places the winner radio next to each fighter's name in the point-controls section" do
    render_inline(described_class.new(category: category.reload, admin: true))

    match = page.find(".competition-tree__match", text: "Fight 1")
    radio_name = "fight_#{fight.id}_winner"
    [[1, fight.fighter_1], [2, fight.fighter_2]].each do |slot, fighter|
      side_block = match.find(".competition-tree__point-controls[data-side='fighter_#{slot}']", visible: :all)
      expect(side_block).to have_field(radio_name, with: fighter.id.to_s, visible: :all, type: :radio)
      expect(side_block).to have_text(fighter.poster_name)
    end
    expect(match).to have_field(radio_name, with: fight.fighter_1.id.to_s,
      checked: true, visible: :all, type: :radio)
  end

  it "renders one point-entry button per kendo event for each fighter in admin mode" do
    render_inline(described_class.new(category: category.reload, admin: true))

    match = page.find(".competition-tree__match", text: "Fight 1")
    codes = %w[M K D T I △]
    [1, 2].each do |slot|
      side_block = match.find(".competition-tree__point-controls[data-side='fighter_#{slot}']", visible: :all)
      codes.each do |code|
        expect(side_block).to have_button(code, visible: :all)
      end
    end
  end

  it "lists each existing point with a remove button in admin mode" do
    point = create(:fight_point, fight: fight, fighter_side: "fighter_1", kind: "men")

    render_inline(described_class.new(category: category.reload, admin: true))

    match = page.find(".competition-tree__match", text: "Fight 1")
    chip = match.find(".competition-tree__point[data-point-id='#{point.id}']", visible: :all)
    expect(chip).to have_text("M")
    expect(chip).to have_button("×", visible: :all)
  end

  it "shows each fighter's points as code chips next to their name on the card" do
    create(:fight_point, fight: fight, fighter_side: "fighter_1", kind: "men")
    create(:fight_point, fight: fight, fighter_side: "fighter_1", kind: "kote")
    create(:fight_point, fight: fight, fighter_side: "fighter_2", kind: "hansoku")

    render_inline(described_class.new(category: category.reload))

    match = page.find(".competition-tree__match", text: "Fight 1")
    expect(match).to have_css(".competition-tree__point", text: "M")
    expect(match).to have_css(".competition-tree__point", text: "K")
    expect(match).to have_css(".competition-tree__point", text: "△")
  end

  it "does not render cards for fights without fighters" do
    empty_fight = create_empty_fight(category, number: 3, round: 1, position: 2)

    render_inline(described_class.new(category: category.reload))

    expect(page).not_to have_css(".competition-tree__match", text: "Fight #{empty_fight.number}")
  end

  it "renders an unresolved bye as a compact bye card with the slot label" do
    local_category = create(:individual_category)
    bye_fight = create(:fight,
      individual_category: local_category,
      number: 1, round: 1, position: 1,
      fighter_1: nil, fighter_2: nil,
      fighter_1_pool_number: 1, fighter_1_pool_rank: 1)

    render_inline(described_class.new(category: local_category.reload))

    card = page.find(".competition-tree__match", text: "Fight #{bye_fight.number}")
    expect(card[:class]).to include("competition-tree__match--bye")
    expect(card).to have_css(".competition-tree__bye-label", text: "Bye")
    expect(card).to have_css(".competition-tree__pool-position", text: "1.1")
  end

  it "renders round-1 fights whose pool slots are not yet resolved" do
    local_category = create(:individual_category)
    pending_fight = create(:fight,
      individual_category: local_category,
      number: 1, round: 1, position: 1,
      fighter_1: nil, fighter_2: nil,
      fighter_1_pool_number: 1, fighter_1_pool_rank: 1,
      fighter_2_pool_number: 2, fighter_2_pool_rank: 2)

    render_inline(described_class.new(category: local_category.reload))

    card = page.find(".competition-tree__match", text: "Fight #{pending_fight.number}")
    expect(card).not_to have_css(".competition-tree__match--bye")
    expect(card).to have_css(".competition-tree__pool-position", text: "1.1")
    expect(card).to have_css(".competition-tree__pool-position", text: "2.2")
  end

  it "does not render forecasted fights that only depend on hidden parents" do
    empty_fight = create_empty_fight(category, number: 3, round: 1, position: 2)
    orphan_fight = create_forecast_fight(category, number: 4, round: 2, position: 2, parent_fight_1: empty_fight)

    render_inline(described_class.new(category: category.reload))

    expect(page).not_to have_css(".competition-tree__match", text: "Fight #{orphan_fight.number}")
  end

  it "renders forecasted fights that only wait for unresolved parents" do
    local_category = create(:individual_category)
    parent_fight_1 = create(:fight, individual_category: local_category, number: 1)
    parent_fight_2 = create(:fight, individual_category: local_category, number: 2)
    waiting_fight = create_forecast_fight(local_category,
      number: 3,
      round: 2,
      position: 1,
      parent_fight_1: parent_fight_1,
      parent_fight_2: parent_fight_2)

    render_inline(described_class.new(category: local_category.reload))

    expect(page).to have_css(".competition-tree__match", text: "Fight #{parent_fight_1.number}")
    expect(page).to have_css(".competition-tree__match", text: "Fight #{parent_fight_2.number}")
    expect(page).to have_css(".competition-tree__match", text: "Fight #{waiting_fight.number}")
  end

  it "hides pass-through fights and keeps their source connected downstream" do
    bracket = create_pass_through_bracket(resolved: true)

    render_inline(described_class.new(category: bracket[:category].reload))

    expect(page).not_to have_css(".competition-tree__match", text: "Fight #{bracket[:pass_through_fight].number}")
    expect(page).to have_css(".competition-tree__match", text: "Fight #{bracket[:final_fight].number}")
    expect(page).to have_text(bracket[:visible_source].winner.poster_name)
  end

  it "hides unresolved pass-through forecasted fights and points downstream to their source" do
    bracket = create_pass_through_bracket(resolved: false)

    render_inline(described_class.new(category: bracket[:category].reload))

    expect(page).not_to have_css(".competition-tree__match", text: "Fight #{bracket[:pass_through_fight].number}")
    expect(page).to have_css(".competition-tree__match", text: "Fight #{bracket[:final_fight].number}")
    expect(page).to have_text("Waiting for fight #{bracket[:visible_source].number}")
    expect(page).not_to have_text("Waiting for fight #{bracket[:pass_through_fight].number}")
  end

  def create_pass_through_bracket(resolved:)
    local_category = create(:individual_category)
    direct_final_parent = create(:fight, individual_category: local_category, round: 3, position: 1, number: 13)
    visible_source = create(:fight, individual_category: local_category, round: 2, position: 2, number: 11)
    empty_source = create_empty_fight(local_category, round: 2, position: 3, number: 12)
    direct_final_parent.update!(winner: direct_final_parent.fighter_1)
    visible_source.update!(winner: visible_source.fighter_1) if resolved
    pass_through_fight = create_forecast_fight(local_category,
      number: 14,
      round: 3,
      position: 2,
      parent_fight_1: visible_source,
      parent_fight_2: empty_source,
      winner: (visible_source.winner if resolved))
    final_fight = create_forecast_fight(local_category,
      number: 15,
      round: 4,
      position: 1,
      parent_fight_1: direct_final_parent,
      parent_fight_2: pass_through_fight)

    {
      category: local_category,
      final_fight: final_fight,
      pass_through_fight: pass_through_fight,
      visible_source: visible_source
    }
  end

  def create_empty_fight(category, attributes)
    create(:fight, {
      individual_category: category,
      fighter_1: nil,
      fighter_2: nil
    }.merge(attributes))
  end

  def create_forecast_fight(category, attributes)
    create_empty_fight(category, attributes)
  end

  def build_bye_bracket(extra_round: false)
    local_category = create(:individual_category)
    bye_kenshi = create(:kenshi, cup: local_category.cup,
      participations: [build(:participation, category: local_category)])
    bye_parent = create(:fight, individual_category: local_category,
      fighter_1: bye_kenshi, fighter_2: nil, number: 1, round: 1, position: 1)
    other_parent = create(:fight, individual_category: local_category,
      number: 2, round: 1, position: 2)
    round_two = create_forecast_fight(local_category,
      number: 3, round: 2, position: 1,
      parent_fight_1: bye_parent, parent_fight_2: other_parent)
    if extra_round
      sibling_round_two = create_forecast_fight(local_category,
        number: 4, round: 2, position: 2)
      create_forecast_fight(local_category,
        number: 5, round: 3, position: 1,
        parent_fight_1: round_two, parent_fight_2: sibling_round_two)
    end
    [local_category, bye_kenshi]
  end
end
